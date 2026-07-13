# Clotch UI Rework — Design Spec

Date: 2026-07-13
Status: approved (chrome + motion + pulse directions chosen by user)

## Goal

Make the tray look and move like a polished, riced macOS notch accessory:
seamless notch fusion, springy fluid motion, refined notification glow.
Terminal interior, themes, config, hover, resize, and control server are out
of scope and unchanged.

## 1. Chrome — seamless notch-fusion

Replace the current `cornerRadius`/`maskedCorners` treatment in
`TrayContentView` with a custom shape:

- **Tray path** (new pure function in `ClotchCore`, e.g. `TrayShape.path(bounds:filletRadius:cornerRadius:)` returning path control points or a `CGPath` built from a platform-free description):
  - Top edge flush under the menu bar.
  - Top-left and top-right corners are **concave inverted fillets** (~12 pt):
    the outline curves up and outward so the tray visually grows out of the
    menu bar / notch, like boring.notch.
  - Bottom corners: **24 pt continuous (squircle-like) curves**, not circular
    arcs. Approximated with cubic Béziers matching Apple's continuous corner
    feel.
- **Material stack** inside `TrayContentView`:
  1. Existing `NSVisualEffectView` (`.hudWindow`, behind-window) masked by the
     tray path.
  2. Overlay `CAGradientLayer`: theme-black at ~1.0 alpha at the top (fusing
     with the notch cutout) easing to ~0.85 alpha at the bottom, masked by the
     same path.
- **Hairline border**: 1 px stroke along the tray path, white @ 8 % alpha,
  omitted along the straight top edge (no seam against the menu bar). Uses
  `strokeStart`/`strokeEnd` or an open path covering only sides + bottom +
  fillets.
- **Shadow**: deeper and softer than the default panel shadow (larger radius,
  lower opacity, slight y-offset). Panel `hasShadow` may be disabled in favor
  of a layer shadow if masking clips the default one.
- Notification tint layer keeps working but its path becomes the new tray
  path (inset 1 pt) so the glow follows the new silhouette.
- Resize grab zones, tracking, and callbacks unchanged.

## 2. Motion — springy unfold

`NSWindow.animator()` cannot spring, so window frame is set instantly and the
**content layer** animates:

- **Open**:
  1. Panel frame set to final expanded frame immediately, `orderFrontRegardless`.
  2. Content layer anchored at top-center; `CASpringAnimation` on
     `transform.scale.x` and `transform.scale.y` from notch-fraction
     (notch size / final size, clamped to sensible minimums) to 1.0, damping
     giving slight overshoot (`damping` ≈ 12–15, `initialVelocity` tuned by
     eye), duration = `settlingDuration`.
  3. Terminal subview: opacity 0 → 1 and scale 0.97 → 1 starting ~60 % into
     the chrome spring (`beginTime` offset), ease-out.
  4. Key window / first responder handoff after animation completes, as today.
- **Close**: fast damped shrink back toward the notch (scale toward
  notch-fraction, anchored top-center) plus fade to 0, ~0.18 s, no bounce;
  `orderOut` on completion.
- Resizing while open does not animate (direct frame set, as today).
- `HoverWatcher` interplay unchanged; `trackLeave` toggling keeps its current
  timing relative to animation completion.

## 3. Pulse — refined glow hug

`PulseController` keeps its geometry (notch outline path, no-notch fallback
bar) with visual upgrades:

- Stroke becomes a **gradient**: `CAGradientLayer` (accent → lighter accent,
  derived by brightening the accent ~25 %) masked by the existing shape layer.
- **Breathing** animates opacity (0.35 → 1.0) and `shadowRadius` (4 → 10)
  together, ease-in-ease-out, ~1.4 s per half-cycle, autoreversing.
- A second, wider soft shadow layer (same path, larger blur, low opacity)
  bleeds slightly onto the menu bar as ambient light, breathing in sync.
- `clear()` removes all animations and hides as today.

## Error handling

No new failure modes: all geometry falls back exactly as current code does
when no notch exists (fallback anchor / straight bar). Animations degrade to
their final states if layers are missing.

## Testing

- Tray path geometry (control points, fillet placement, symmetric widths) is
  pure and covered by new cases in `ClotchChecks` (`swift run ClotchChecks`).
- Spring parameters and visuals verified manually: `./scripts/make-app.sh`,
  open/close via hover and `clotch toggle`, `clotch notify` for pulse.

## Files touched

- `Sources/ClotchCore/` — new tray shape geometry (pure).
- `Sources/ClotchApp/NotchPanel.swift` — material stack, mask, border, shadow.
- `Sources/ClotchApp/AppDelegate.swift` — open/close animation choreography.
- `Sources/ClotchApp/PulseController.swift` — gradient stroke, breathing.
- `Checks/` — geometry checks.
