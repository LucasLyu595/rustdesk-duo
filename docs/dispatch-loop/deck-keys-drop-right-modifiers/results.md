---
name: deck-keys-drop-right-modifiers-results
description: "The deck keyboard drops right command and option, widens space to 6.5 units, and swaps caps lock with left control, with the keyboard tests updated to pin it."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: deck-keys-drop-right-modifiers
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: a956eb21f1d796686
  at: 2026-11-22T23:13:17-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-22T23:14:16-08:00
---

# Results: deck keyboard drops its right modifiers

Candidate commit: 5ddc20510 (unit/deck-keys-drop-right-modifiers, base 74f140b97; captain commit of the implementer's working tree; results doc committed after)

## Acceptance → tests

| Done-when | Proven by |
|---|---|
| D1 | `rows follow the MacBook table and line up`: caps row starts with `ctrl` at 1.75; bottom row `caps` 1.25, `option-l` 1.25, `cmd-l` 1.5, `space` 6.5, arrows at 1, last key flush right; `cmd-r` and `option-r` absent, key count 61, arrows pinned at offsets 10.5-13.5; `keycaps carry MacBook labels` (one option, one command) |
| D2 | Gate section: `flutter test` on all duo tests and `flutter analyze` on the two files |
| D3 | Inspection: `git diff --stat` lists only `_rows` in `duo_keyboard.dart` and the test file |
| D4 | MISSING: Lucas's look on the Duo (manual) |

## Gate

Run from `flutter/` in the worktree.

| Command | Exit status | Result |
|---|---|---|
| `flutter pub get` | exit 0 | tracked files restored; status shows only the two owned files |
| `flutter test test/duo_*_test.dart` | exit 0 | 68 passed, 0 failed |
| `flutter analyze lib/mobile/duo/duo_keyboard.dart test/duo_keyboard_test.dart` | exit 0 | No issues found |

Red-first: edited tests against the base `duo_keyboard.dart` failed 2 tests (`keycaps carry MacBook labels`, `rows follow the MacBook table and line up`); source then restored and the gate above is green.

## Deviations

None. The arrow-position assertions use literal offsets as planned.

Cleanup: none

## Regression surface

| Existing file / path | Behavior change | Why unavoidable |
|---|---|---|
| `duo_keyboard.dart` `_rows` caps row | First key is control at 1.75 | R1 |
| `duo_keyboard.dart` `_rows` bottom row | Caps lock first at 1.25; space 6.5; no right command or option | R2, R3 |
| `_key`, `_tap`, `_capsLetters`, `_KeyCap`, `DuoKeySink` | None | - |

Right-hand command and option arming is gone; the left keys still arm both modifiers.

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no code findings.

| Nit | Disposition |
|---|---|
| D2 row held D1 evidence | fixed: R3 evidence moved into D1; D2 points at the Gate section |

## Verify

Captain gate on 2ac51aa2b, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 79 passed; `flutter analyze` on the two files: exit 0, no issues.
