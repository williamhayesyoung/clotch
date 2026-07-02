import Foundation

/// An RGB color, components 0...1. Pure value type (no AppKit dependency).
public struct RGB: Equatable {
    public let r: CGFloat
    public let g: CGFloat
    public let b: CGFloat
    public init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
        self.r = r; self.g = g; self.b = b
    }
    public init?(hex: String) {
        guard let c = parseHexColor(hex) else { return nil }
        self.init(c.r, c.g, c.b)
    }
    public var hexString: String {
        String(format: "#%02x%02x%02x",
               Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

/// A terminal color theme: foreground, cursor, notification accents, and the
/// 16 ANSI colors (normal 0-7, bright 8-15).
public struct Theme: Equatable {
    public let name: String
    public let foreground: RGB
    public let cursor: RGB
    /// Default pulse color for claude prompts.
    public let claudeAccent: RGB
    /// Default pulse color for hermes prompts.
    public let hermesAccent: RGB
    /// 16 ANSI colors.
    public let ansi: [RGB]

    public init(name: String, foreground: RGB, cursor: RGB, claudeAccent: RGB, hermesAccent: RGB, ansi: [RGB]) {
        self.name = name
        self.foreground = foreground
        self.cursor = cursor
        self.claudeAccent = claudeAccent
        self.hermesAccent = hermesAccent
        precondition(ansi.count == 16, "ANSI palette must have 16 colors")
        self.ansi = ansi
    }
}

extension Theme {
    private static func h(_ s: String) -> RGB { RGB(hex: s)! }

    /// The user's current WezTerm palette: deep indigo-black with lavender/pink accents.
    public static let indigo = Theme(
        name: "indigo",
        foreground: h("#f0ecff"),
        cursor: h("#cba6f7"),
        claudeAccent: h("#cba6f7"), // lavender
        hermesAccent: h("#f38ba8"), // dusty rose
        ansi: [
            h("#1a1830"), h("#fc5d7c"), h("#9ed072"), h("#e7c664"),
            h("#89b4fa"), h("#cba6f7"), h("#89dceb"), h("#7e7a9e"),
            h("#2a2850"), h("#fc5d7c"), h("#9ed072"), h("#e7c664"),
            h("#89b4fa"), h("#f38ba8"), h("#a4dcf0"), h("#f0ecff"),
        ]
    )

    /// Rosé Pine (main variant).
    public static let rosePine = Theme(
        name: "rose-pine",
        foreground: h("#e0def4"),
        cursor: h("#e0def4"),
        claudeAccent: h("#c4a7e7"), // iris
        hermesAccent: h("#ebbcba"), // rose
        ansi: [
            h("#26233a"), h("#eb6f92"), h("#31748f"), h("#f6c177"),
            h("#9ccfd8"), h("#c4a7e7"), h("#ebbcba"), h("#e0def4"),
            h("#6e6a86"), h("#eb6f92"), h("#31748f"), h("#f6c177"),
            h("#9ccfd8"), h("#c4a7e7"), h("#ebbcba"), h("#e0def4"),
        ]
    )

    /// Catppuccin Mocha.
    public static let catppuccin = Theme(
        name: "catppuccin",
        foreground: h("#cdd6f4"),
        cursor: h("#f5e0dc"),
        claudeAccent: h("#cba6f7"), // mauve
        hermesAccent: h("#f5c2e7"), // pink
        ansi: [
            h("#45475a"), h("#f38ba8"), h("#a6e3a1"), h("#f9e2af"),
            h("#89b4fa"), h("#cba6f7"), h("#94e2d5"), h("#bac2de"),
            h("#585b70"), h("#f38ba8"), h("#a6e3a1"), h("#f9e2af"),
            h("#89b4fa"), h("#cba6f7"), h("#94e2d5"), h("#a6adc8"),
        ]
    )

    public static let all: [Theme] = [indigo, rosePine, catppuccin]

    /// Look up a built-in theme by name (case-insensitive, hyphen/underscore
    /// insensitive). Accepts common aliases.
    public static func named(_ raw: String) -> Theme? {
        let key = raw.lowercased().replacingOccurrences(of: "_", with: "-")
        switch key {
        case "indigo", "current", "wezterm": return .indigo
        case "rose-pine", "rosepine", "rose", "rosé-pine": return .rosePine
        case "catppuccin", "catppuccin-mocha", "mocha", "catpuccin": return .catppuccin
        default:
            return all.first { $0.name == key }
        }
    }
}
