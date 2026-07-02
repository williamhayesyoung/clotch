import AppKit
import ClotchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = NotchPanel()
    private var trayView: TrayContentView!
    private let terminal = TerminalController()
    private let hover = HoverWatcher()
    private let pulse = PulseController()
    private var server: ControlServer!
    private var statusItem: NSStatusItem!
    private var stickyMenuItem: NSMenuItem!

    private var isOpen = false
    private var pendingTintColor: String?

    // MARK: Screen / notch geometry

    private var screen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var notchRect: CGRect? {
        let s = screen
        return NotchGeometry.notchRect(
            screenFrame: s.frame,
            auxTopLeft: s.auxiliaryTopLeftArea,
            auxTopRight: s.auxiliaryTopRightArea
        )
    }

    private var anchor: CGRect {
        notchRect ?? NotchGeometry.fallbackAnchor(screenFrame: screen.frame)
    }

    private func expandedFrame(size: CGSize? = nil) -> CGRect {
        let s = size ?? PanelSizing.clamp(Preferences.shared.panelSize, screenFrame: screen.frame)
        return NotchGeometry.panelFrame(anchor: anchor, screenFrame: screen.frame, size: s)
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        trayView = TrayContentView(terminal: terminal.view, topInset: notchRect?.height ?? 0)
        trayView.onResize = { [weak self] proposed in
            guard let self else { return }
            let clamped = PanelSizing.clamp(proposed, screenFrame: self.screen.frame)
            self.panel.setFrame(self.expandedFrame(size: clamped), display: true)
        }
        trayView.onResizeEnded = { [weak self] in
            guard let self else { return }
            Preferences.shared.panelSize = self.panel.frame.size
        }
        panel.contentView = trayView
        panel.setFrame(anchor, display: false)

        hover.notchRect = anchor.height > 0 ? anchor : CGRect(
            x: anchor.midX - 100, y: screen.frame.maxY - 4, width: 200, height: 4)
        hover.panelFrame = { [weak self] in (self?.isOpen ?? false) ? self!.panel.frame : .zero }
        hover.onDwell = { [weak self] in self?.open() }
        hover.onLeftPanel = { [weak self] in
            guard let self, !Preferences.shared.sticky else { return }
            if !self.panel.isKeyWindow { self.close() }
        }
        hover.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelResignedKey),
            name: NSWindow.didResignKeyNotification, object: panel)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        setupStatusItem()

        server = ControlServer { [weak self] cmd in self?.handle(cmd) }
        do {
            try server.start()
        } catch {
            NSLog("clotch: control server failed to start: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server.stop()
        hover.stop()
    }

    // MARK: Commands

    private func handle(_ cmd: Command) {
        switch cmd {
        case .toggle: isOpen ? close() : open()
        case .show: open()
        case .hide: close()
        case .notify(let color):
            if isOpen {
                showOpenTint(colorHex: color)
            } else {
                let hex = color ?? Preferences.shared.defaultNotifyColor.hexString
                pulse.show(colorHex: hex, notchRect: notchRect, screenFrame: screen.frame)
            }
        case .clear:
            pulse.clear()
            trayView.clearTint()
            pendingTintColor = nil
        case .sticky(let value):
            Preferences.shared.sticky = value
            stickyMenuItem.state = value ? .on : .off
        }
    }

    private func showOpenTint(colorHex: String?) {
        let rgb = colorHex.flatMap(RGB.init(hex:)) ?? Preferences.shared.defaultNotifyColor
        trayView.showTint(color: rgb.nsColor)
        pendingTintColor = colorHex
    }

    // MARK: Open / close

    private func open() {
        guard !isOpen else { return }
        isOpen = true
        pulse.clear()
        trayView.clearTint()
        pendingTintColor = nil

        // Expand outward from the notch: start at the notch rect itself,
        // grow width sideways and height downward.
        let target = expandedFrame()
        panel.setFrame(anchor, display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            panel.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.makeKeyAndOrderFront(nil)
            self.panel.makeFirstResponder(self.terminal.view)
            self.hover.trackLeave = true
        }
    }

    private func close() {
        guard isOpen else { return }
        isOpen = false
        hover.trackLeave = false
        hover.cancelLeaveTimer()
        trayView.clearTint()
        // Fold back into the notch: shrink to the notch rect, then hide.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0.0, 0.8, 0.4)
            panel.animator().setFrame(anchor, display: true)
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    @objc private func panelResignedKey() {
        guard isOpen, !Preferences.shared.sticky else { return }
        // Hide when focus moves elsewhere unless the mouse is still on the panel.
        let loc = NSEvent.mouseLocation
        if !panel.frame.insetBy(dx: -20, dy: -20).contains(loc) {
            close()
        }
    }

    @objc private func screensChanged() {
        hover.notchRect = anchor.height > 0 ? anchor : CGRect(
            x: anchor.midX - 100, y: screen.frame.maxY - 4, width: 200, height: 4)
        if isOpen {
            panel.setFrame(expandedFrame(), display: true)
        }
        if pulse.isActive {
            pulse.show(colorHex: pendingTintColor, notchRect: notchRect, screenFrame: screen.frame)
        }
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "terminal.fill", accessibilityDescription: "Clotch")

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Toggle Tray", action: #selector(menuToggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        stickyMenuItem = NSMenuItem(title: "Sticky", action: #selector(menuSticky), keyEquivalent: "")
        stickyMenuItem.target = self
        stickyMenuItem.state = Preferences.shared.sticky ? .on : .off
        menu.addItem(stickyMenuItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Clotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func menuToggle() { handle(.toggle) }

    @objc private func menuSticky() {
        handle(.sticky(!Preferences.shared.sticky))
    }
}
