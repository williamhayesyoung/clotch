import Foundation
import CoreGraphics
import ClotchCore

// Minimal check-runner: the CLT toolchain has no XCTest/swift-testing.
// Run with `swift run ClotchChecks`. Exits non-zero on first summary of failures.

var failures = 0

func check(_ condition: Bool, _ label: String, file: String = #file, line: Int = #line) {
    if condition {
        print("ok   \(label)")
    } else {
        failures += 1
        print("FAIL \(label)  (\((file as NSString).lastPathComponent):\(line))")
    }
}

func checkThrows(_ label: String, _ expected: CommandError, _ body: () throws -> Command) {
    do {
        _ = try body()
        failures += 1
        print("FAIL \(label): expected \(expected), nothing thrown")
    } catch let e as CommandError where e == expected {
        print("ok   \(label)")
    } catch {
        failures += 1
        print("FAIL \(label): expected \(expected), got \(error)")
    }
}

// MARK: Command protocol

func roundTrip(_ cmd: Command) -> Command? {
    var data = cmd.encoded()
    guard data.last == 0x0A else { return nil }
    data.removeLast()
    return try? Command.decode(data)
}

for cmd: Command in [.toggle, .show, .hide, .clear,
                     .notify(color: "#ff6600"), .notify(color: nil),
                     .sticky(true), .sticky(false)] {
    check(roundTrip(cmd) == cmd, "round-trip \(cmd)")
}

check((try? Command.decode(Data(##"{"cmd":"notify","color":"#00ff00"}"##.utf8))) == .notify(color: "#00ff00"),
      "decode raw notify JSON")
checkThrows("malformed JSON", .invalidJSON) { try Command.decode(Data("not json".utf8)) }
checkThrows("unknown command", .unknownCommand("dance")) { try Command.decode(Data(#"{"cmd":"dance"}"#.utf8)) }
checkThrows("sticky missing value", .missingValue) { try Command.decode(Data(#"{"cmd":"sticky"}"#.utf8)) }

// MARK: Geometry (16" MBP-like metrics, points)

let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
let auxLeft = CGRect(x: 0, y: 1085, width: 764, height: 32)
let auxRight = CGRect(x: 964, y: 1085, width: 764, height: 32)

check(NotchGeometry.notchRect(screenFrame: screen, auxTopLeft: auxLeft, auxTopRight: auxRight)
        == CGRect(x: 764, y: 1085, width: 200, height: 32),
      "notch rect from aux areas")
check(NotchGeometry.notchRect(screenFrame: screen, auxTopLeft: nil, auxTopRight: nil) == nil,
      "no notch -> nil")
check(NotchGeometry.notchRect(screenFrame: screen, auxTopLeft: auxLeft,
                              auxTopRight: CGRect(x: 700, y: 1085, width: 100, height: 32)) == nil,
      "overlapping aux areas -> nil")

let notch = CGRect(x: 764, y: 1085, width: 200, height: 32)
let frame = NotchGeometry.panelFrame(anchor: notch, screenFrame: screen, size: CGSize(width: 700, height: 400))
check(abs(frame.midX - notch.midX) < 0.5, "panel centered on notch")
check(frame.maxY == screen.maxY, "panel flush with screen top")
check(frame.size == CGSize(width: 700, height: 400), "panel size preserved")

let edgeFrame = NotchGeometry.panelFrame(anchor: CGRect(x: 0, y: 1085, width: 200, height: 32),
                                         screenFrame: screen, size: CGSize(width: 700, height: 400))
check(edgeFrame.minX >= screen.minX, "panel clamped to screen edge")

check(PanelSizing.clamp(CGSize(width: 10, height: 10), screenFrame: screen) == PanelSizing.minSize,
      "size clamp min")
let huge = PanelSizing.clamp(CGSize(width: 9999, height: 9999), screenFrame: screen)
check(huge.width == screen.size.width && huge.height == screen.size.height * 0.9,
      "size clamp max")

// MARK: Hex colors

let c = parseHexColor("#ff6600")
check(c?.r == 1.0 && c?.b == 0.0 && abs((c?.g ?? 0) - CGFloat(0x66) / 255) < 0.001, "parse #ff6600")
check(parseHexColor("9b59b6") != nil, "parse without #")
check(parseHexColor("#ff660") == nil, "reject 5-digit")
check(parseHexColor("red") == nil, "reject named color")
check(parseHexColor("#gggggg") == nil, "reject non-hex")

// MARK: Themes

check(Theme.named("rose-pine")?.name == "rose-pine", "resolve rose-pine")
check(Theme.named("rosepine")?.name == "rose-pine", "resolve rosepine alias")
check(Theme.named("catpuccin")?.name == "catppuccin", "resolve catppuccin typo alias")
check(Theme.named("current")?.name == "indigo", "resolve current -> indigo")
check(Theme.named("nope") == nil, "unknown theme -> nil")
check(Theme.indigo.ansi.count == 16, "indigo has 16 ansi")
check(Theme.rosePine.ansi.count == 16, "rose-pine has 16 ansi")
check(Theme.catppuccin.ansi.count == 16, "catppuccin has 16 ansi")
check(RGB(hex: "#f0ecff")?.hexString == "#f0ecff", "RGB hex round-trip")

// MARK: Config parsing

let cfgText = """
# clotchrc
theme = rose-pine
font_size = 14
sticky = on
panel_width = 800
dwell_ms = 200
notify_color_claude = "#c4a7e7"
notify_color_hermes = #ebbcba
; comment line
bogus line without equals
"""
let cfg = ConfigParser.parse(cfgText)
check(cfg.theme == "rose-pine", "config theme")
check(cfg.fontSize == 14, "config font_size")
check(cfg.sticky == true, "config sticky on")
check(cfg.panelWidth == 800, "config panel_width")
check(cfg.dwellMs == 200, "config dwell_ms")
check(cfg.notifyColors["claude"] == "#c4a7e7", "config notify_color_claude (quoted)")
check(cfg.notifyColors["hermes"] == "#ebbcba", "config notify_color_hermes (unquoted)")
check(cfg.graceMs == nil, "absent key stays nil")
check(ConfigParser.parse("").theme == nil, "empty config")

// MARK: Tray shape

let trayBounds = CGRect(x: 0, y: 0, width: 700, height: 400)
let tray = TrayShape.outline(bounds: trayBounds)
let tbb = tray.boundingBoxOfPath
check(abs(tbb.minX - trayBounds.minX) < 0.5 && abs(tbb.maxX - trayBounds.maxX) < 0.5
        && abs(tbb.minY - trayBounds.minY) < 0.5 && abs(tbb.maxY - trayBounds.maxY) < 0.5,
      "tray path fills bounds")
check(tray.contains(CGPoint(x: 350, y: 200)), "tray contains center")
check(tray.contains(CGPoint(x: 6, y: 399.5)), "flare sliver inside near top edge")
check(!tray.contains(CGPoint(x: 2, y: 396)), "top-left fillet concave (scooped)")
check(!tray.contains(CGPoint(x: 698, y: 396)), "top-right fillet concave (scooped)")
check(!tray.contains(CGPoint(x: 2, y: 200)), "tray side inset by fillet")
check(tray.contains(CGPoint(x: 14, y: 200)), "tray body starts after fillet inset")
check(!tray.contains(CGPoint(x: 13, y: 1)), "bottom-left corner rounded off")
check(!tray.contains(CGPoint(x: 687, y: 1)), "bottom-right corner rounded off")
check(tray.contains(CGPoint(x: 350, y: 1)), "bottom edge center inside")
check(tray.contains(CGPoint(x: 20, y: 200)) == tray.contains(CGPoint(x: 680, y: 200)),
      "tray path symmetric")
let openTray = TrayShape.outline(bounds: trayBounds, closed: false)
check(!openTray.isEmpty, "open border path exists")

// MARK: Summary

if failures > 0 {
    print("\n\(failures) check(s) FAILED")
    exit(1)
}
print("\nall checks passed")
