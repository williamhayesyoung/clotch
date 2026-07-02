import AppKit

/// Watches global mouse movement. Reports dwell on the notch (to open the tray)
/// and mouse departure from the panel (to auto-hide).
final class HoverWatcher {
    var notchRect: CGRect = .zero
    var onDwell: (() -> Void)?
    /// Called when the mouse has been outside the panel for the grace period.
    var onLeftPanel: (() -> Void)?
    /// Provider for the current panel frame (nil / .zero when folded).
    var panelFrame: (() -> CGRect)?
    var trackLeave = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var dwellTimer: Timer?
    private var leaveTimer: Timer?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.mouseMoved()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.mouseMoved()
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
        dwellTimer?.invalidate()
        leaveTimer?.invalidate()
    }

    func cancelLeaveTimer() {
        leaveTimer?.invalidate()
        leaveTimer = nil
    }

    private func mouseMoved() {
        let loc = NSEvent.mouseLocation

        // Dwell-to-open: mouse resting on the notch area.
        if notchRect.contains(loc) {
            if dwellTimer == nil {
                dwellTimer = Timer.scheduledTimer(withTimeInterval: Preferences.shared.dwell, repeats: false) { [weak self] _ in
                    self?.dwellTimer = nil
                    if let self, self.notchRect.contains(NSEvent.mouseLocation) {
                        self.onDwell?()
                    }
                }
            }
        } else {
            dwellTimer?.invalidate()
            dwellTimer = nil
        }

        // Auto-hide: mouse left the open panel.
        guard trackLeave, let frame = panelFrame?(), frame.height > 0 else {
            cancelLeaveTimer()
            return
        }
        let hoverZone = frame.insetBy(dx: -20, dy: -20)
        if hoverZone.contains(loc) || notchRect.contains(loc) {
            cancelLeaveTimer()
        } else if leaveTimer == nil {
            leaveTimer = Timer.scheduledTimer(withTimeInterval: Preferences.shared.grace, repeats: false) { [weak self] _ in
                self?.leaveTimer = nil
                self?.onLeftPanel?()
            }
        }
    }
}
