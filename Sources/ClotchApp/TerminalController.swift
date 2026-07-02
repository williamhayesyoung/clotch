import AppKit
import SwiftTerm

/// Hosts one persistent shell session in a SwiftTerm view.
/// If the shell exits, shows a message and respawns on the next ⏎ keypress.
final class TerminalController: NSObject, LocalProcessTerminalViewDelegate {
    let view: LocalProcessTerminalView
    private var sessionEnded = false
    private var keyMonitor: Any?

    override init() {
        view = LocalProcessTerminalView(frame: .zero)
        super.init()
        view.processDelegate = self
        configureAppearance()

        // SwiftTerm's keyDown is not open, so intercept keys via a local monitor:
        // ⌘+/⌘−/⌘0 resize the font; ⏎ respawns a dead session.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, event.window === self.view.window else { return event }

            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "+", "=": self.adjustFontSize(by: +1); return nil
                case "-", "_": self.adjustFontSize(by: -1); return nil
                case "0": self.setFontSize(13); return nil
                default: break
                }
            }

            if self.sessionEnded, event.keyCode == 36 { // return
                self.start()
                return nil
            }
            return event
        }
        start()
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }

    private func configureAppearance() {
        let prefs = Preferences.shared
        let theme = prefs.theme
        view.font = NSFont.monospacedSystemFont(ofSize: prefs.fontSize, weight: .regular)
        // Fully transparent so the frosted blur material shows through.
        view.nativeBackgroundColor = .clear
        view.nativeForegroundColor = theme.foreground.nsColor
        view.installColors(theme.ansi.map(\.swiftTermColor))
        view.caretColor = theme.cursor.nsColor
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
    }

    // MARK: Font sizing

    private func adjustFontSize(by delta: CGFloat) {
        setFontSize(Preferences.shared.fontSize + delta)
    }

    private func setFontSize(_ size: CGFloat) {
        let clamped = min(max(size, Preferences.minFontSize), Preferences.maxFontSize)
        Preferences.shared.fontSize = clamped
        view.font = NSFont.monospacedSystemFont(ofSize: clamped, weight: .regular)
    }

    private func start() {
        sessionEnded = false
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = "-" + (shell as NSString).lastPathComponent
        view.startProcess(executable: shell, args: ["-l"], environment: nil, execName: shellName)
    }

    // MARK: LocalProcessTerminalViewDelegate

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        sessionEnded = true
        source.feed(text: "\r\n\u{1b}[33m[session ended — press ⏎ to restart]\u{1b}[0m\r\n")
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
