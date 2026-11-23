---
name: desktop-and-window-shot-reach-mac-spec
description: "The Duo strip's Desktop button sends F11 to a Mac peer as map-mode keys so Show Desktop fires, and the Shot button becomes Window, sending Cmd+Shift+5 (Shottr's pick-a-window capture on the M6)."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: desktop-and-window-shot-reach-mac
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T20:07:47-08:00
---

# Spec: Desktop and Window reach the Mac

Base: `duo-mode` at `90529daea` (unit `mission-button-reaches-mac` merged as `b9706196c`).
Worktree: `/Users/lucas/rustdesk-duo/.dispatch-workspaces/desktop-and-window-shot-reach-mac`
(branch `unit/desktop-and-window-shot-reach-mac`). Work type: `code`.

## Intent

Lucas, 2026-11-22: Mission and Spotlight now work; Desktop still does nothing on the M6. He wants
the screenshot button to capture one window he picks.

## Facts (captain and parent session, read at base)

- Desktop sends legacy `VK_F11` with no modifier (`flutter/lib/mobile/duo/duo_shortcuts.dart` 43).
  On the M6, Show Desktop is the default F11 (symbolic hotkey 36 not overridden); `fnState` is the
  default (the F-keys are media keys). The legacy F11 path does not trigger it.
- Map mode posts a raw key: the server's `sim_rdev_rawkey_position` → rdev
  `RawKey::MacVirtualKeycode`. In the pinned rdev (`0904f23`, the same pin as the stock 1.5.3 tag's
  `Cargo.lock`), `convert_native_with_source` builds the press with `CGEventCreateKeyboardEvent`
  and on purpose skips `workaround_fn` ("Don't use `workaround_fn()` for `KeyPress`, or `F11`
  will not work", `src/macos/simulate.rs` ~155), so the press keeps the system's function-key
  flags; only the release has SecondaryFn cleared. `kVK_F11` = 103.
- The unit-3 path already exists: `duoPeerAwareSender` sends Mission as `kDuoMacMissionKeys`
  through `bind.sessionHandleFlutterRawKeyEvent(name: 'duo_map_key', ...)` when `isIOS`, the send
  guards pass and the peer is macOS; the iOS Rust side turns each call into one map-mode
  `KeyEvent`. No Rust change is needed for another keycode.
- Screenshots on the M6: the macOS shortcuts ⇧⌘3/4/5 are disabled; Shottr owns them: ⇧⌘4 = area
  (what Shot sends now), ⇧⌘5 = pick a window ("anyWindow").

## Required behavior

R1. **Desktop on a Mac peer**: under the same condition as Mission (isIOS, send guards, macOS peer),
the Desktop button sends F11 down (103), F11 up (103) as map-mode keys through the existing
`duo_map_key` path, awaited in order, with the same per-key error handling. On any other peer it
sends today's legacy `VK_F11`.

R2. **Shot becomes Window**: the button sends Cmd+Shift+5 (the `5` key, legacy path, as `4` is
today), label `Window`, id `window` or kept as `screenshot` (planner's call; keep tests honest),
an icon that reads as a window capture. Order and the five-button fall-back stay (it stays the
fifth button).

R3. **Unchanged**: every other button, Mission's map-mode sequence, the Quit guard, the layout, the
Rust code. No local state change.

R4. **Scope**: `flutter/lib/mobile/duo/duo_shortcuts.dart` and `flutter/test/duo_status_strip_test.dart`
only (plus the unit's docs). `docs/DUO.md` is the captain's, after the install.

## Tests

- Update the combo table test for Window (Cmd+Shift+5).
- Desktop on a macOS peer (fake `useMapKeys` true) emits `(103, down)`, `(103, up)` in order and no
  legacy call; with `useMapKeys` false it emits the legacy `VK_F11`.
- Existing Mission tests stay green.

## Done when

D1. R1: the Desktop map-key test passes; legacy Desktop on a non-Mac peer is pinned.
D2. R2: the combo test shows Window = `5` with Cmd+Shift and the label `Window`.
D3. R3/R4: the other tests are green; the diff touches only the two files and the unit's docs.
D4. Focused gate: `flutter test` on all `flutter/test/duo_*_test.dart`; `flutter analyze` on the
changed files; no new issue.
D5. On the Duo (Lucas taps): Desktop shows the M6's desktop; Window starts Shottr's window pick.
