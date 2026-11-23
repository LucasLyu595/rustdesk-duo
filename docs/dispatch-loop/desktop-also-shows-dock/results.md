---
name: desktop-also-shows-dock-results
description: "The Duo strip's Desktop button, for a Mac peer, now sends map-mode F11, a 200 ms pause, then map-mode Ctrl+F3; all duo tests and analyze are green."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: desktop-also-shows-dock
  modified: 2026-11-23
generated:
  by: claude/sonnet
  session: ab5cd9985f3060622
  at: 2026-11-23T00:44:16-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-23T00:45:59-08:00
---

# Results: Desktop also brings up the Dock

Candidate commit: 78476b9c3 (unit/desktop-also-shows-dock, base a20aad460; captain commit of the implementer's working tree; results doc committed after)

## Acceptance → tests

| Done-when | Proven by |
| --- | --- |
| D1. R1 pinned by the updated test (order and pause) | `Desktop on a Mac peer sends F11, then after the pause Ctrl+F3, as map keys and no legacy key` (two F11 keys, still two at delay minus 1 ms, six keys in order after the pause, no legacy). Red first: with the constants but no branch it failed on the six-key expectation; green after the branch. |
| D2. R2 pinned by the existing tests | `Desktop on another peer ...`, `Mission on a Mac peer ...`, `Mission on another peer ...`, `another button on a Mac peer ...`, `each tap button ...` (unchanged, passing) |
| D3. Focused gate | see Gate |
| D4. On the Duo: Desktop shows the desktop and the Dock | MISSING: Lucas's tap on the Duo (manual) |

## Gate

| Command | Exit status | Result |
| --- | --- | --- |
| `flutter pub get` (from flutter/) | exit 0 | no tracked file changed |
| `flutter test` on the 7 test/duo_*_test.dart files | exit 0 | 70 passed, 0 failed |
| `flutter analyze` lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart | exit 0 | No issues found |
| red run: `flutter test test/duo_status_strip_test.dart` before the branch | exit 1 | 1 failed (new test), 7 passed |

## Deviations

None.

Cleanup: none

## Known limitations

The send is fire-and-forget as before: a second Desktop tap inside the pause interleaves its F11 with the first tap's Ctrl+F3, and the Dock keys still go out if the strip is disposed during the pause. Every press still gets its release. Cancelling would need new state (timer handle or generation counter).

## Regression surface

| Path | Change |
| --- | --- |
| Desktop, Mac peer | F11 down/up, then 200 ms pause, then 59/99/99/59 (intended change) |
| Desktop, other peer; Mission; other buttons | unchanged (legacy early return and `_sendInOrder` path untouched) |

Existing files modified: `flutter/lib/mobile/duo/duo_shortcuts.dart` (additions only: two constants, `_sendDesktopThenDock`, one branch) and `flutter/test/duo_status_strip_test.dart` (one test replaced).

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no blocking findings.

| Nit | Disposition |
|---|---|
| Spec and plan name base 4398cdc27; the real base is a20aad460 | noted here: the one commit between them touches only `docs/DUO.md`; the unit was rebased onto a20aad460 before implementing |
| No test makes a Dock key fail | accepted: the Dock group reuses the unchanged per-key catch in `_sendInOrder` (unit mission-button-reaches-mac); the spec pins order and pause only |

## Verify

Captain gate on 898d9ecc5, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 81 passed; `flutter analyze` on the two files: exit 0, no issues.
