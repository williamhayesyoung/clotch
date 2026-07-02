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
    private let tintLayer = CAShapeLayer()
    private let cornerRadius: CGFloat = 18
    var onResize: ((CGSize) -> Void)?
    var onResizeEnded: (() -> Void)?

    private enum DragEdge { case bottom, left, right, bottomLeft, bottomRight }
    private var dragEdge: DragEdge?
    private var dragStartSize: CGSize = .zero
    private var dragStartMouse: CGPoint = .zero
    private let grabZone: CGFloat = 8

    init(terminal: NSView, topInset: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true

        // Frosted material: dark, translucent, blurs whatever is behind the tray.
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        blur.layer?.masksToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        terminal.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(terminal)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            // Keep terminal text clear of the notch cutout (and menu bar strip).
            terminal.topAnchor.constraint(equalTo: blur.topAnchor, constant: topInset + 8),
            terminal.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 12),
            terminal.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -12),
            terminal.bottomAnchor.constraint(equalTo: blur.bottomAnchor, constant: -12),
        ])

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
        let path = CGPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            cornerWidth: cornerRadius - 1, cornerHeight: cornerRadius - 1, transform: nil
        )
        tintLayer.path = path
        tintLayer.frame = bounds
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

    // MARK: Edge resize

    private func edge(at p: CGPoint) -> DragEdge? {
        let nearBottom = p.y < grabZone
        let nearLeft = p.x < grabZone
        let nearRight = p.x > bounds.width - grabZone
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
