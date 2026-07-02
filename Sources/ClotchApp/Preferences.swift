import Foundation
import ClotchCore

/// Settings resolved from `~/.config/clotchrc` (base) with UserDefaults holding
/// values mutated at runtime (sticky toggle, drag-resize).
final class Preferences {
    static let shared = Preferences()
    private let d = UserDefaults.standard
    private(set) var config: Config
    let theme: Theme

    private enum Key {
        static let sticky = "sticky"
        static let panelWidth = "panelWidth"
        static let panelHeight = "panelHeight"
        static let fontSize = "fontSize"
    }

    private init() {
        config = ConfigParser.load()
        theme = config.theme.flatMap(Theme.named) ?? .indigo

        // Seed runtime-mutable values from config on first launch only.
        if d.object(forKey: Key.sticky) == nil, let s = config.sticky {
            d.set(s, forKey: Key.sticky)
        }
        if d.object(forKey: Key.panelWidth) == nil, let w = config.panelWidth {
            d.set(w, forKey: Key.panelWidth)
        }
        if d.object(forKey: Key.panelHeight) == nil, let h = config.panelHeight {
            d.set(h, forKey: Key.panelHeight)
        }
        if d.object(forKey: Key.fontSize) == nil, let fs = config.fontSize {
            d.set(fs, forKey: Key.fontSize)
        }
    }

    // MARK: Runtime-mutable (persisted in UserDefaults)

    var sticky: Bool {
        get { d.bool(forKey: Key.sticky) }
        set { d.set(newValue, forKey: Key.sticky) }
    }

    var panelSize: CGSize {
        get {
            let w = d.double(forKey: Key.panelWidth)
            let h = d.double(forKey: Key.panelHeight)
            return CGSize(width: w > 0 ? w : 720, height: h > 0 ? h : 360)
        }
        set {
            d.set(Double(newValue.width), forKey: Key.panelWidth)
            d.set(Double(newValue.height), forKey: Key.panelHeight)
        }
    }

    /// Terminal font size; adjustable at runtime via ⌘+/⌘−, persisted.
    var fontSize: CGFloat {
        get {
            let v = d.double(forKey: Key.fontSize)
            return v > 0 ? CGFloat(v) : CGFloat(config.fontSize ?? 13)
        }
        set { d.set(Double(newValue), forKey: Key.fontSize) }
    }

    static let minFontSize: CGFloat = 8
    static let maxFontSize: CGFloat = 32

    // MARK: Config-derived (read-only at runtime)

    /// Hover dwell before unfolding, in seconds.
    var dwell: TimeInterval { (config.dwellMs ?? 150) / 1000 }

    /// Grace period after mouse leaves before auto-hiding, in seconds.
    var grace: TimeInterval { (config.graceMs ?? 1000) / 1000 }

    /// Default notification color for a source, falling back to the theme accent.
    func notifyColor(source: String) -> RGB {
        if let hex = config.notifyColors[source.lowercased()], let rgb = RGB(hex: hex) {
            return rgb
        }
        return source.lowercased() == "hermes" ? theme.hermesAccent : theme.claudeAccent
    }

    /// Default pulse color when a notify command carries no explicit color.
    var defaultNotifyColor: RGB { theme.claudeAccent }
}
