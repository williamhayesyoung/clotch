import AppKit
import ClotchCore

/// Transparent click-through window that draws a breathing glow ring
/// hugging the notch outline (or a top-edge bar when there is no notch).
/// The stroke is a horizontal accent gradient; a wider ambient layer bleeds
/// soft light onto the menu bar.
final class PulseController {
    private var window: NSWindow?
    private let shape = CAShapeLayer()       // gradient mask (white stroke)
    private let gradient = CAGradientLayer()
    private let ambient = CAShapeLayer()     // soft under-glow
    private(set) var isActive = false

    func show(colorHex: String?, notchRect: CGRect?, screenFrame: CGRect) {
        let rgb = colorHex.flatMap(parseHexColor) ?? (r: 1.0, g: 0.42, b: 0.0)
        let color = NSColor(calibratedRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        // Brighten toward white by 25% for the gradient's light end.
        let bright = NSColor(
            calibratedRed: rgb.r + (1 - rgb.r) * 0.25,
            green: rgb.g + (1 - rgb.g) * 0.25,
            blue: rgb.b + (1 - rgb.b) * 0.25, alpha: 1)

        let margin: CGFloat = 12
        let frame: CGRect
        if let notch = notchRect {
            frame = CGRect(
                x: notch.minX - margin,
                y: notch.minY - margin,
                width: notch.width + margin * 2,
                height: notch.height + margin
            )
        } else {
            frame = CGRect(
                x: screenFrame.midX - 150,
                y: screenFrame.maxY - 6,
                width: 300,
                height: 6
            )
        }

        let w = ensureWindow(frame: frame)
        let bounds = w.contentView!.bounds
        let path = pulsePath(bounds: bounds, hasNotch: notchRect != nil)

        // Ambient under-glow: wider, blurred, bleeds onto the menu bar.
        ambient.frame = bounds
        ambient.path = path
        ambient.fillColor = nil
        ambient.strokeColor = color.withAlphaComponent(0.5).cgColor
        ambient.lineWidth = 5
        ambient.lineCap = .round
        ambient.shadowColor = color.cgColor
        ambient.shadowOpacity = 1
        ambient.shadowOffset = .zero

        // Crisp gradient stroke on top.
        shape.frame = bounds
        shape.path = path
        shape.fillColor = nil
        shape.strokeColor = NSColor.white.cgColor
        shape.lineWidth = 3
        shape.lineCap = .round
        gradient.frame = bounds
        gradient.colors = [color.cgColor, bright.cgColor, color.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.mask = shape

        for layer in [ambient, gradient] as [CALayer] {
            layer.removeAllAnimations()
            let breathe = CABasicAnimation(keyPath: "opacity")
            breathe.fromValue = 0.35
            breathe.toValue = 1.0
            breathe.duration = 1.4
            breathe.autoreverses = true
            breathe.repeatCount = .infinity
            breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(breathe, forKey: "breathe")
        }
        let radius = CABasicAnimation(keyPath: "shadowRadius")
        radius.fromValue = 4.0
        radius.toValue = 10.0
        radius.duration = 1.4
        radius.autoreverses = true
        radius.repeatCount = .infinity
        radius.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ambient.add(radius, forKey: "radius")

        w.orderFrontRegardless()
        isActive = true
    }

    func clear() {
        ambient.removeAllAnimations()
        gradient.removeAllAnimations()
        window?.orderOut(nil)
        isActive = false
    }

    private func ensureWindow(frame: CGRect) -> NSWindow {
        if let w = window {
            w.setFrame(frame, display: true)
            return w
        }
        let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let v = NSView(frame: CGRect(origin: .zero, size: frame.size))
        v.wantsLayer = true
        v.layer?.addSublayer(ambient)
        v.layer?.addSublayer(gradient)
        w.contentView = v
        window = w
        return w
    }

    /// Path outlining the notch cutout: down the left side, across the bottom
    /// (rounded corners), up the right side. For no-notch fallback: a straight bar.
    private func pulsePath(bounds: CGRect, hasNotch: Bool) -> CGPath {
        let p = CGMutablePath()
        guard hasNotch else {
            p.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            p.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            return p
        }
        let margin: CGFloat = 12
        let r: CGFloat = 10
        let left = bounds.minX + margin - 4
        let right = bounds.maxX - margin + 4
        let bottom = bounds.minY + margin - 4
        let top = bounds.maxY

        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom + r))
        p.addQuadCurve(to: CGPoint(x: left + r, y: bottom), control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom + r), control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        return p
    }
}
