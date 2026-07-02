# Clotch — Notch Terminal Tray for macOS

**Date:** 2026-07-01
**Status:** Approved

## Overview

Clotch is a macOS menu-bar application that docks a terminal in a tray panel that
unfolds from beneath the MacBook Pro notch. It opens by hovering the mouse on the
notch or via an skhd-bound CLI toggle, supports drag-resizing and a sticky mode,
and can pulse a colored glow around the notch when an external tool (Claude Code,
Hermes) needs user input.

## Goals

- Terminal tray anchored to the notch: slides down from the menu-bar area,
  rounded bottom corners, hugging the notch like Dynamic-Island-style apps.
- Open triggers: (a) mouse dwell on the notch ~150 ms, (b) `clotch toggle` from
  skhd or any shell.
- Auto-hide: in non-sticky mode, fold when the terminal loses focus or the mouse
  leaves the panel for ~1 s. Sticky mode disables auto-hide.
- Resizable: drag bottom/side edges; width/height persisted.
- Notification pulse: `clotch notify --color '#ff6600'` makes a soft glow ring
  trace the notch outline, breathing until the tray is opened or
  `clotch notify --clear` is called. While the tray is open, notify shows a
  border tint on the panel instead.

## Non-Goals (v1)

- Multiple tabs / split panes.
- tmux integration.
- Watching terminal output for prompt patterns (CLI trigger only).
- Support for multiple displays simultaneously (panel lives on the built-in
  display; fallback handled, see Error Handling).

## Architecture

Swift 5.10+, AppKit (+ SwiftUI for the settings window), minimum macOS 14.
Menu bar extra, no Dock icon (`.accessory` activation policy). Built with
SwiftPM; a small script wraps the executable into `Clotch.app`.

### Components

- **NotchPanel** — borderless, non-activating `NSPanel`, window level
  `.statusBar + 1`, positioned flush under the notch using
  `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea`+`auxiliaryTopRightArea` to
  compute the notch rect. Rounded bottom corners. Spring slide animation for
  fold/unfold. Hosts the terminal view and resize handles.
- **TerminalView** — SwiftTerm `LocalProcessTerminalView` running one persistent
  zsh login shell, spawned at app launch and reused across fold/unfold. Session
  ends only when the app quits (or the shell exits; see Error Handling).
- **HoverWatcher** — global `NSEvent` mouse-moved monitor. Hit-test against the
  notch rect; 150 ms dwell → unfold and focus the terminal. When unfolded and
  non-sticky: mouse leaves the panel AND panel loses key status → 1 s grace →
  fold.
- **PulseLayer** — a separate tiny transparent window (ignores mouse, always on,
  level above menu bar) holding a `CAShapeLayer` that strokes the notch outline
  with a glow; opacity breathing animation. Color set per notify call; latest
  call wins. Cleared by unfold or `--clear`.
- **ControlServer** — unix domain socket at `~/.clotch/clotch.sock`. Newline-
  delimited JSON commands:
  - `{"cmd":"toggle"}` / `{"cmd":"show"}` / `{"cmd":"hide"}`
  - `{"cmd":"notify","color":"#ff6600"}`
  - `{"cmd":"clear"}`
  - `{"cmd":"sticky","value":true|false}` (optional convenience)
- **clotch CLI** — second SwiftPM executable target. Parses args, connects to
  the socket, writes one JSON line, exits. Subcommands: `toggle`, `show`,
  `hide`, `notify [--color HEX] [--clear]`, `sticky on|off`.
  - skhd example: `cmd + shift - t : clotch toggle`
  - Claude Code hook example (Notification hook): `clotch notify --color '#ff6600'`
  - Hermes: same CLI, e.g. `clotch notify --color '#9b59b6'`.
- **ClotchCore** — library target with pure logic: command protocol
  encode/decode, notch/panel geometry math, resize clamping. Unit-testable
  without AppKit.

### State & Configuration

`UserDefaults`: sticky (bool), panel width/height, font name/size, per-source
default colors. Menu bar icon menu: Sticky toggle (checkmark), Settings…, Quit.
Settings window (SwiftUI): font, size, colors, dwell/grace timing.

## Pulse Semantics

- Notify while folded → glow ring pulses indefinitely until tray unfolds or a
  clear command arrives.
- Notify while unfolded → panel border tint in the given color, cleared on
  focus/keypress in the terminal or explicit clear.
- Multiple pending notifies: latest color wins (no queue in v1).

## Error Handling

- **No notch** (external display / non-notch Mac): anchor panel top-center of
  the main screen; pulse becomes a short glow bar at the top edge.
- **Stale socket**: on launch, unlink existing socket file and rebind.
- **Shell exit**: terminal shows "session ended — press ⏎ to restart"; next
  keypress respawns the shell.
- **CLI cannot connect**: print clear error ("clotch app not running?") and
  exit non-zero.

## Testing

- Unit tests (ClotchCore): JSON command round-trip, malformed input, notch rect
  math from screen/insets fixtures, resize clamping.
- Manual smoke checklist (README): hover open, skhd toggle, notify pulse +
  clear, sticky behavior, resize persistence, shell-death recovery, no-notch
  fallback.
