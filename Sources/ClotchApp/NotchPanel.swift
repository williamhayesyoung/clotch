import AppKit
import ClotchCore

/// Borderless non-activating panel that slides down from under the notch.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }
}

/// Content view: dark rounded container (bottom corners only), terminal inside,
/// edge drag zones for resizing, optional colored tint border for notifications.
final class TrayContentView: NSView {
    private let blur = NSVisualEffectView()
    private let overlay = CAGradientLayer()
    private let maskShape = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let tintLayer = CAShapeLayer()
    private let terminalView: NSView
    var onResize: ((CGSize) -> Void)?
    var onResizeEnded: (() -> Void)?

    private enum DragEdge { case bottom, left, right, bottomLeft, bottomRight }
    private var dragEdge: DragEdge?
    private var dragStartSize: CGSize = .zero
    private var dragStartMouse: CGPoint = .zero
    private let grabZone: CGFloat = 8

    init(terminal: NSView, topInset: CGFloat) {
        self.terminalView = terminal
        super.init(frame: .zero)
        wantsLayer = true

        // Frosted material, silhouette-masked twice: maskImage clips the
        // material itself, the container layer mask clips everything else.
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        layer?.mask = maskShape

        // Fusion overlay: pure theme-black at the top (blends into the notch
        // cutout) easing to translucent toward the bottom. Sits above the blur
        // material, below the terminal (inserted at sublayer index 0).
        overlay.colors = [
            NSColor.black.withAlphaComponent(0.85).cgColor,
            NSColor.black.withAlphaComponent(1.0).cgColor,
        ]
        overlay.startPoint = CGPoint(x: 0.5, y: 0)   // layer coords: y0 = bottom
        overlay.endPoint = CGPoint(x: 0.5, y: 1)     // y1 = top
        blur.layer?.insertSublayer(overlay, at: 0)
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        terminal.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(terminal)
        terminal.wantsLayer = true

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            // Keep terminal text clear of the notch cutout (and menu bar strip).
            terminal.topAnchor.constraint(equalTo: blur.topAnchor, constant: topInset + 8),
            terminal.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: TrayShape.filletRadius + 12),
            terminal.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -(TrayShape.filletRadius + 12)),
            terminal.bottomAnchor.constraint(equalTo: blur.bottomAnchor, constant: -16),
        ])

        // Hairline border along sides + bottom + fillets; no top seam.
        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.white.withAlphaComponent(0.08).cgColor
        borderLayer.lineWidth = 1
        layer?.addSublayer(borderLayer)

        // Notification tint: glow only (no visible outline at rest).
        tintLayer.fillColor = nil
        tintLayer.strokeColor = NSColor.clear.cgColor
        tintLayer.lineWidth = 1.5
        tintLayer.opacity = 0
        layer?.addSublayer(tintLayer)

        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let silhouette = TrayShape.outline(bounds: bounds)
        maskShape.path = silhouette
        maskShape.frame = bounds
        overlay.frame = blur.bounds
        borderLayer.path = TrayShape.outline(bounds: bounds.insetBy(dx: 0.5, dy: 0.5), closed: false)
        borderLayer.frame = bounds
        tintLayer.path = TrayShape.outline(bounds: bounds.insetBy(dx: 1, dy: 1))
        tintLayer.frame = bounds
        blur.maskImage = TrayContentView.maskImage(for: bounds.size)
    }

    /// Alpha mask image of the tray silhouette (clips the blur material).
    private static func maskImage(for size: CGSize) -> NSImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(cgPath: TrayShape.outline(bounds: rect)).fill()
            return true
        }
        image.capInsets = .init()
        return image
    }

    // MARK: Notification tint (shown while tray is open)

    func showTint(color: NSColor) {
        tintLayer.strokeColor = color.withAlphaComponent(0.6).cgColor
        tintLayer.opacity = 1
        tintLayer.shadowColor = color.cgColor
        tintLayer.shadowOpacity = 0.9
        tintLayer.shadowRadius = 12
    }

    func clearTint() {
        tintLayer.opacity = 0
        tintLayer.shadowOpacity = 0
    }

    // MARK: Open/close animation
    // NSWindow.animator() cannot spring, so the window frame is set to its
    // final rect instantly and the content layer scales from a notch-sized
    // fraction, anchored at top-center.

    private func prepareAnchor() {
        guard let layer else { return }
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        layer.position = CGPoint(x: bounds.midX, y: bounds.maxY)
    }

    func animateUnfold(from fraction: CGSize, completion: @escaping () -> Void) {
        guard let layer else { completion(); return }
        prepareAnchor()

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)

        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue = CATransform3DMakeScale(fraction.width, fraction.height, 1)
        spring.toValue = CATransform3DIdentity
        spring.mass = 1
        spring.stiffness = 220
        spring.damping = 14          // slight overshoot
        spring.initialVelocity = 4
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "unfold")

        if let termLayer = terminalView.layer {
            let start = CACurrentMediaTime() + 0.16
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.0
            fade.toValue = 1.0
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.97
            grow.toValue = 1.0
            for anim in [fade, grow] {
                anim.beginTime = start
                anim.duration = 0.25
                anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                anim.fillMode = .backwards
            }
            termLayer.add(fade, forKey: "fadeIn")
            termLayer.add(grow, forKey: "growIn")
        }
        CATransaction.commit()
    }

    func animateFold(to fraction: CGSize, completion: @escaping () -> Void) {
        guard let layer else { completion(); return }
        prepareAnchor()

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            // Reset so the next unfold starts clean.
            self?.layer?.removeAllAnimations()
            self?.layer?.transform = CATransform3DIdentity
            self?.layer?.opacity = 1
            completion()
        }
        let shrink = CABasicAnimation(keyPath: "transform")
        shrink.fromValue = CATransform3DIdentity
        shrink.toValue = CATransform3DMakeScale(fraction.width, fraction.height, 1)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        for anim in [shrink, fade] {
            anim.duration = 0.18
            anim.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0.0, 0.8, 0.4)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
        }
        layer.add(shrink, forKey: "fold")
        layer.add(fade, forKey: "foldFade")
        CATransaction.commit()
    }

    // MARK: Edge resize

    private func edge(at p: CGPoint) -> DragEdge? {
        let nearBottom = p.y < grabZone
        let nearLeft = p.x < grabZone + TrayShape.filletRadius
        let nearRight = p.x > bounds.width - grabZone - TrayShape.filletRadius
        if nearBottom && nearLeft { return .bottomLeft }
        if nearBottom && nearRight { return .bottomRight }
        if nearBottom { return .bottom }
        if nearLeft { return .left }
        if nearRight { return .right }
        return nil
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch edge(at: p) {
        case .bottom: NSCursor.resizeUpDown.set()
        case .left, .right: NSCursor.resizeLeftRight.set()
        case .bottomLeft, .bottomRight: NSCursor.crosshair.set()
        case nil: NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let e = edge(at: p) else {
            super.mouseDown(with: event)
            return
        }
        dragEdge = e
        dragStartSize = bounds.size
        dragStartMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let e = dragEdge else {
            super.mouseDragged(with: event)
            return
        }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStartMouse.x
        let dy = dragStartMouse.y - now.y // dragging down increases height
        var size = dragStartSize
        switch e {
        case .bottom:
            size.height += dy
        case .left:
            size.width -= dx * 2 // keep centered on notch: symmetric growth
        case .right:
            size.width += dx * 2
        case .bottomLeft:
            size.height += dy
            size.width -= dx * 2
        case .bottomRight:
            size.height += dy
            size.width += dx * 2
        }
        onResize?(size)
    }

    override func mouseUp(with event: NSEvent) {
        if dragEdge != nil {
            dragEdge = nil
            onResizeEnded?()
            return
        }
        super.mouseUp(with: event)
    }
}
