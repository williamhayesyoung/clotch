import AppKit
import ClotchCore

/// Transparent click-through window that draws a breathing glow ring
/// hugging the notch outline (or a top-edge bar when there is no notch).
final class PulseController {
    private var window: NSWindow?
    private let shape = CAShapeLayer()
    private(set) var isActive = false

    func show(colorHex: String?, notchRect: CGRect?, screenFrame: CGRect) {
        let rgb = colorHex.flatMap(parseHexColor) ?? (r: 1.0, g: 0.42, b: 0.0)
        let color = NSColor(calibratedRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)

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
        shape.frame = w.contentView!.bounds
        shape.path = pulsePath(bounds: w.contentView!.bounds, hasNotch: notchRect != nil)
        shape.strokeColor = color.cgColor
        shape.fillColor = nil
        shape.lineWidth = 3
        shape.lineCap = .round
        shape.shadowColor = color.cgColor
        shape.shadowOpacity = 1
        shape.shadowRadius = 6
        shape.shadowOffset = .zero

        shape.removeAllAnimations()
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 0.25
        breathe.toValue = 1.0
        breathe.duration = 0.9
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shape.add(breathe, forKey: "breathe")

        w.orderFrontRegardless()
        isActive = true
    }

    func clear() {
        shape.removeAllAnimations()
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
        v.layer?.addSublayer(shape)
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
