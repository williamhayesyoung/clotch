import Foundation

/// Parsed user configuration from `~/.config/clotchrc`.
/// Only keys present in the file override defaults; everything is optional.
public struct Config: Equatable {
    public var theme: String?
    public var fontSize: Double?
    public var sticky: Bool?
    public var panelWidth: Double?
    public var panelHeight: Double?
    public var dwellMs: Double?
    public var graceMs: Double?
    /// Notification colors keyed by source ("claude", "hermes", …) as hex strings.
    public var notifyColors: [String: String]

    public init() {
        notifyColors = [:]
    }
}

public enum ConfigParser {
    /// Default config path: `~/.config/clotchrc`.
    public static func defaultPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/.config/clotchrc"
    }

    /// Load and parse the config file if it exists; returns an empty Config otherwise.
    public static func load(path: String = defaultPath()) -> Config {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return Config()
        }
        return parse(text)
    }

    /// Parse `key = value` lines. `#` and `;` begin comments. Values may be quoted.
    /// Keys `notify_color_<source>` populate the notifyColors map.
    public static func parse(_ text: String) -> Config {
        var config = Config()
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            // Full-line comments only, so `#RRGGBB` values are never mistaken
            // for a comment.
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }

            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            guard !value.isEmpty else { continue }

            switch key {
            case "theme":
                config.theme = value
            case "font_size", "fontsize":
                config.fontSize = Double(value)
            case "sticky":
                config.sticky = parseBool(value)
            case "panel_width", "width":
                config.panelWidth = Double(value)
            case "panel_height", "height":
                config.panelHeight = Double(value)
            case "dwell_ms", "dwell":
                config.dwellMs = Double(value)
            case "grace_ms", "grace":
                config.graceMs = Double(value)
            default:
                if key.hasPrefix("notify_color_") {
                    let source = String(key.dropFirst("notify_color_".count))
                    if !source.isEmpty { config.notifyColors[source] = value }
                }
            }
        }
        return config
    }

    private static func parseBool(_ s: String) -> Bool? {
        switch s.lowercased() {
        case "true", "yes", "on", "1": return true
        case "false", "no", "off", "0": return false
        default: return nil
        }
    }
}
