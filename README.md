# clotch

A terminal tray that unfolds from beneath the MacBook Pro notch.

- **Hover to open** — rest the mouse on the notch (~150 ms) and the tray slides down.
- **skhd toggle** — `clotch toggle` folds/unfolds from anywhere.
- **Resizable** — drag the bottom or side edges; size is remembered.
- **Sticky mode** — toggle auto-hide off from the menu bar icon or `clotch sticky on`.
- **Notch pulse** — `clotch notify --color '#ff6600'` breathes a colored glow
  around the notch until you open the tray. Wire it into Claude Code or Hermes
  so you notice approval prompts.
- **Themes** — `indigo` (deep indigo-black with lavender/rose accents), `rose-pine`, `catppuccin`.
- **Font size** — ⌘+ / ⌘− adjust, ⌘0 resets; persisted.

## Configuration

Clotch reads `~/.config/clotchrc` on launch (full-line `#`/`;` comments only):

```ini
theme = indigo            # indigo | rose-pine | catppuccin
font_size = 13
sticky = off
panel_width = 720
panel_height = 360
dwell_ms = 150            # hover dwell before unfolding
grace_ms = 1000          # delay before auto-hiding
notify_color_claude = #cba6f7
notify_color_hermes = #f38ba8
```

A no-color `clotch notify` uses the theme's accent. `sticky`, panel size, and
font size are seeded from the config, then remembered across runs once changed
at runtime.

## Build & install

```sh
./scripts/make-app.sh
cp .build/release/clotch /usr/local/bin/
open build/Clotch.app
```

Requires macOS 14+ and Xcode command line tools. Run the check suite with
`swift run ClotchChecks` (plain executable — the CLT toolchain ships no XCTest). To launch at login, add
`build/Clotch.app` to System Settings → General → Login Items.

## skhd

```
# ~/.config/skhd/skhdrc
cmd + shift - t : /usr/local/bin/clotch toggle
```

## Claude Code notification hook

`~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "/usr/local/bin/clotch notify --color '#ff6600'" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "/usr/local/bin/clotch notify --clear" }
        ]
      }
    ]
  }
}
```

Hermes (or anything else): call `clotch notify --color '#9b59b6'` when input is
needed and `clotch notify --clear` when handled.

## CLI

```
clotch toggle | show | hide
clotch notify [--color '#RRGGBB']   # pulse (default orange)
clotch notify --clear
clotch sticky on|off
```

The CLI talks to the app over a unix socket at `~/.clotch/clotch.sock`
(owner-only permissions).

## Behavior notes

- One persistent login shell lives in the tray; it survives fold/unfold and
  dies only when the app quits. If the shell exits, press ⏎ to respawn.
- Non-sticky mode folds the tray when the mouse leaves it (~1 s grace) or when
  it loses focus with the mouse elsewhere.
- Opening the tray clears any pending notification pulse. While the tray is
  open, notifications show as a colored border tint instead.
- No notch (external display / older Mac): the tray anchors top-center and the
  pulse becomes a glow bar at the top edge.

## Manual smoke checklist

1. Hover the notch → tray unfolds, terminal focused; move mouse away → folds after ~1 s.
2. `clotch toggle` twice → unfold, fold.
3. `clotch notify --color '#ff6600'` while folded → glow ring pulses; open tray → clears.
4. `clotch notify` while open → border tint; `clotch notify --clear` → gone.
5. Menu bar → Sticky on → tray stays despite focus loss; Sticky off → auto-hide resumes.
6. Drag bottom edge and side edges → resize; quit + relaunch → size preserved.
7. `exit` in the shell → message shown; ⏎ → new shell.
