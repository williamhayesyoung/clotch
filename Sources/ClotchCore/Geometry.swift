import Foundation
import CoreGraphics

/// Pure geometry for positioning the tray and pulse around the notch.
/// All rects are in AppKit screen coordinates (origin bottom-left, points).
public enum NotchGeometry {

    /// Compute the notch rect from screen metrics.
    /// - Parameters:
    ///   - screenFrame: full screen frame.
    ///   - auxTopLeft: `NSScreen.auxiliaryTopLeftArea` (region left of the notch), nil if no notch.
    ///   - auxTopRight: `NSScreen.auxiliaryTopRightArea`, nil if no notch.
    /// - Returns: the notch rect, or nil when the screen has no notch.
    public static func notchRect(screenFrame: CGRect, auxTopLeft: CGRect?, auxTopRight: CGRect?) -> CGRect? {
        guard let left = auxTopLeft, let right = auxTopRight else { return nil }
        let x = left.maxX
        let width = right.minX - left.maxX
        guard width > 0 else { return nil }
        let height = left.height
        return CGRect(x: x, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// Fallback anchor when there is no notch: a zero-height strip centered at the top.
    public static func fallbackAnchor(screenFrame: CGRect, width: CGFloat = 200) -> CGRect {
        CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY, width: width, height: 0)
    }

    /// Panel frame for a given anchor (notch rect or fallback) and panel size.
    /// Panel is horizontally centered on the anchor, top edge flush with screen top,
    /// extending downward.
    public static func panelFrame(anchor: CGRect, screenFrame: CGRect, size: CGSize) -> CGRect {
        var x = anchor.midX - size.width / 2
        x = max(screenFrame.minX, min(x, screenFrame.maxX - size.width))
        return CGRect(x: x, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }
}

public enum PanelSizing {
    public static let minSize = CGSize(width: 320, height: 160)

    /// Clamp a proposed panel size to [minSize, screen bounds].
    public static func clamp(_ proposed: CGSize, screenFrame: CGRect) -> CGSize {
        let w = max(minSize.width, min(proposed.width, screenFrame.size.width))
        let h = max(minSize.height, min(proposed.height, screenFrame.size.height * 0.9))
        return CGSize(width: w, height: h)
    }
}

/// Parse a hex color string like "#ff6600" or "ff6600" into RGB components (0...1).
public func parseHexColor(_ hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return (
        r: CGFloat((v >> 16) & 0xFF) / 255.0,
        g: CGFloat((v >> 8) & 0xFF) / 255.0,
        b: CGFloat(v & 0xFF) / 255.0
    )
}
