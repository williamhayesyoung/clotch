import AppKit
import SwiftTerm
import ClotchCore

extension RGB {
    var nsColor: NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
    }

    /// SwiftTerm's Color uses 16-bit components (0...65535).
    var swiftTermColor: SwiftTerm.Color {
        SwiftTerm.Color(
            red: UInt16(r * 65535),
            green: UInt16(g * 65535),
            blue: UInt16(b * 65535)
        )
    }
}
