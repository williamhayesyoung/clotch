import Foundation
import CoreGraphics

/// Pure path builder for the tray silhouette (view coordinates, origin
/// bottom-left, NOT flipped — maxY is the top edge under the menu bar).
///
/// Shape: full-width top edge that flares out of the menu bar via concave
/// fillets at the top corners (like the notch itself), body sides inset by
/// the fillet radius, and large smooth bottom corners.
public enum TrayShape {
    /// Radius of the concave top fillets; body sides are inset by this much.
    public static let filletRadius: CGFloat = 12
    /// Bottom corner radius (smooth, continuous-feel curve).
    public static let cornerRadius: CGFloat = 24
    /// Cubic control-point factor for bottom corners. Smaller = squarer,
    /// smoother onset (squircle-like); 0.55 ≈ circular. Tuned by eye.
    static let cornerControl: CGFloat = 0.3

    /// Tray outline. `closed: true` yields the full silhouette (masks/fills);
    /// `closed: false` yields the same outline without the straight top edge
    /// (for stroking the hairline border with no seam against the menu bar).
    public static func outline(bounds: CGRect,
                               fillet f: CGFloat = TrayShape.filletRadius,
                               corner r: CGFloat = TrayShape.cornerRadius,
                               closed: Bool = true) -> CGPath {
        let p = CGMutablePath()
        let minX = bounds.minX, maxX = bounds.maxX
        let minY = bounds.minY, maxY = bounds.maxY
        let left = minX + f
        let right = maxX - f
        let k = cornerControl * r

        p.move(to: CGPoint(x: minX, y: maxY))
        // Concave top-left fillet: flare from full width into the inset side.
        p.addQuadCurve(to: CGPoint(x: left, y: maxY - f),
                       control: CGPoint(x: left, y: maxY))
        p.addLine(to: CGPoint(x: left, y: minY + r))
        // Bottom-left corner.
        p.addCurve(to: CGPoint(x: left + r, y: minY),
                   control1: CGPoint(x: left, y: minY + k),
                   control2: CGPoint(x: left + k, y: minY))
        p.addLine(to: CGPoint(x: right - r, y: minY))
        // Bottom-right corner.
        p.addCurve(to: CGPoint(x: right, y: minY + r),
                   control1: CGPoint(x: right - k, y: minY),
                   control2: CGPoint(x: right, y: minY + k))
        p.addLine(to: CGPoint(x: right, y: maxY - f))
        // Concave top-right fillet.
        p.addQuadCurve(to: CGPoint(x: maxX, y: maxY),
                       control: CGPoint(x: right, y: maxY))
        if closed { p.closeSubpath() }
        return p
    }
}
