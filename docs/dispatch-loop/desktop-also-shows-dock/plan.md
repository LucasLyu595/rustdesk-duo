---
name: desktop-also-shows-dock-plan
description: "Plan to make the Duo strip's Desktop button, for a Mac peer, follow map-mode F11 with a 200 ms pause and map-mode Ctrl+F3 through one added branch and one new function."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: desktop-also-shows-dock
  modified: 2026-11-23
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-23T00:43:55-08:00
---

# Plan: Desktop also brings up the Dock

Spec: `docs/dispatch-loop/desktop-also-shows-dock/spec.md` (stable). Base `duo-mode` at `4398cdc27`.
All paths below are relative to `flutter/` in the unit worktree.

## Approach

1. New constants next to `kDuoMacDesktopKeys`:
   - `kDuoMacDockKeys = [(59, true), (99, true), (99, false), (59, false)]` (`List<DuoMapKey>`), with a
     one-line doc comment giving the reason: kVK_Control + kVK_F3, "Move focus to the Dock", which brings
     up an auto-hidden Dock.
   - `kDuoMacDockDelay = Duration(milliseconds: 200)`, the single named pause (R1 allows 150-250 ms),
     with a one-line reason: the Dock hotkey is ignored while Show Desktop is still starting.
2. New private function below `_sendInOrder`:
   `Future<void> _sendDesktopThenDock(DuoMapKeySender mapKey)`: `await _sendInOrder(kDuoMacDesktopKeys,
   mapKey)`, `await Future<void>.delayed(kDuoMacDockDelay)`, `await _sendInOrder(kDuoMacDockKeys, mapKey)`.
   Both groups go through `_sendInOrder`, so the per-key try/catch is reused unchanged: a failed call
   never stops the rest, and Control up is always sent (R1). `_sendInOrder` never throws, so the pause
   and the second group always run.
3. Hook in `duoPeerAwareSender`, inserted between the legacy early return and the existing
   `unawaited(_sendInOrder(keys, mapKey));` line (which stays untouched):
   `if (identical(keys, kDuoMacDesktopKeys)) { unawaited(_sendDesktopThenDock(mapKey)); return; }`

## Design notes and known limits (no fork needing a ruling)

- Known limit, left as is: the send is fire-and-forget as today, so a second Desktop tap inside the
  pause interleaves its F11 with the first tap's Ctrl+F3, and the Dock keys still go out if the strip
  is disposed during the pause. Every press still gets its release. Cancelling would need new state
  (a timer handle or generation counter), which AGENTS.md reserves for crashes or data loss.

## Test change (`test/duo_status_strip_test.dart`)

Replace only the test `Desktop on a Mac peer sends F11 down then up as map keys and no legacy key`;
`pumpPeer` and every other test stay as they are. `testWidgets` already runs in fake async, so the
tester clock drives `Future.delayed`; no `fake_async` import and no new helper.

New test, named for what it pins (e.g. `Desktop on a Mac peer sends F11, then after the pause Ctrl+F3,
as map keys and no legacy key`), with `pumpPeer(tester, mac: true, hold: true)`:

1. Tap `duo-shortcut-desktop`, `pump()`: `map == [(103, true)]` (first call still held).
2. `gates.single.complete()`, `pump()`: `map == [(103, true), (103, false)]`.
3. `pump(kDuoMacDockDelay - const Duration(milliseconds: 1))`: still the two F11 keys (pause pinned).
4. `pump(const Duration(milliseconds: 1))`, then `pump()`: `map` equals the six keys in order,
   `(103, true), (103, false), (59, true), (99, true), (99, false), (59, false)`; `legacy` is empty.
5. `pumpWidget(const SizedBox())` as the neighbours do. The timer has fired by then, so the binding's
   pending-timer check passes; if step 4 leaves a key unsent, add one more `pump()`, not a real wait.

## Regression surface

| Path | Before | After | Pinned by |
| --- | --- | --- | --- |
| Desktop, Mac peer | F11 down/up as map keys | same two keys, 200 ms pause, then 59/99/99/59 | updated test (order and pause) |
| Desktop, other peer | legacy `VK_F11` | unchanged (returns before the new branch) | `Desktop on another peer ...` |
| Mission, Mac peer | four map keys via `_sendInOrder` | unchanged (list is not `kDuoMacDesktopKeys`) | `Mission on a Mac peer ...` |
| Mission, other peer | legacy Ctrl+Up | unchanged | `Mission on another peer ...` |
| Other buttons, any peer | legacy combo | unchanged (`_macMapKeys` returns null) | `another button on a Mac peer ...`, `each tap button ...` |
| `_sendInOrder` error handling | per-key catch | unchanged, reused for both groups | existing code, not edited |

Existing files modified: `lib/mobile/duo/duo_shortcuts.dart` (additions only) and the one test.

## Implementer task (single)

1. Add the two constants, `_sendDesktopThenDock` and the one branch as described; touch no existing line.
2. Replace the Desktop-on-Mac test as described.
3. Run the gate, then do the AGENTS.md minimization pass over `git diff` (no formatting-only changes,
   no comment that restates code) and report the regression surface in results.md.
4. Commit only the two source files plus the unit's docs, with explicit paths.

## Gate (focused; from `flutter/`)

- `~/development/flutter/bin/flutter test --reporter=compact test/duo_deck_test.dart test/duo_fold_test.dart
  test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart
  test/duo_status_strip_test.dart test/duo_trackpad_test.dart`: all pass.
- `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_shortcuts.dart
  test/duo_status_strip_test.dart`: no new issues against the base.
- `git status --short`: only the two source files and `docs/dispatch-loop/desktop-also-shows-dock/`.
- Red check: the new test must fail on the base code (it sees two keys, not six); record that in results.md.

D4 (Desktop shows the desktop and the Dock on the Duo) is Lucas's device check after merge, outside the gate.
