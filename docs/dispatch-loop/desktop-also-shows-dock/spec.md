---
name: desktop-also-shows-dock-spec
description: "For a Mac peer the Duo strip's Desktop button sends map-mode F11 and then, after a short pause, map-mode Ctrl+F3 so the auto-hidden Dock comes up."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: desktop-also-shows-dock
  modified: 2026-11-23
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-23T00:42:48-08:00
---

# Spec: Desktop also brings up the Dock

Base: `duo-mode` at `4398cdc27`. Worktree: `/Users/lucas/rustdesk-duo/.dispatch-workspaces/desktop-also-shows-dock`
(branch `unit/desktop-also-shows-dock`). Work type: `code`.

## Intent (Lucas, 2026-11-23)

Desktop works; the tap should also show the Dock.

## Facts

- M6 (parent session): `com.apple.dock autohide = 1`, orientation bottom. Symbolic hotkey 8, "Move
  focus to the Dock", is the default Ctrl+F3 (not overridden); it brings up the hidden Dock.
  Option+Cmd+D must NOT be used (it toggles the Dock's auto-hide setting permanently).
- `flutter/lib/mobile/duo/duo_shortcuts.dart`: `_macMapKeys` maps a bare `VK_F11` to
  `kDuoMacDesktopKeys = [(103, true), (103, false)]`; `_sendInOrder` awaits each `mapKey` call and
  catches per key so the releases still go out (unit `mission-button-reaches-mac` fix). Map mode on
  the M6 posts raw macOS keycodes: kVK_Control 59, kVK_F3 99, kVK_F11 103.

## Required behavior

R1. Mac peer (same condition as today: isIOS, send guards, macOS peer): Desktop sends F11 down,
F11 up (103), then waits about 200 ms (one named constant, 150-250 ms), then Control down (59),
F3 down (99), F3 up (99), Control up (59), all as map-mode keys through the existing path, in
order. A failed call does not stop the rest (Control up is still sent).
R2. Any other peer: Desktop sends the legacy `VK_F11` exactly as today. Mission and every other
button unchanged. Label stays `Desktop`.
R3. Scope: `duo_shortcuts.dart` and `flutter/test/duo_status_strip_test.dart` (plus the unit's docs).

## Tests

Update the Desktop-on-Mac test to the six keys in order and assert the pause (the Ctrl+F3 group is
not sent before the pause elapses; use fake time); keep the non-Mac Desktop and the Mission tests.

## Done when

D1. R1 pinned by the updated test (order and pause). D2. R2 pinned by the existing tests. D3. Focused
gate: `flutter test` on all duo tests, `flutter analyze` on the two files. D4. On the Duo (Lucas):
Desktop shows the desktop and the Dock.
