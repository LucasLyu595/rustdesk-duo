---
name: desktop-and-window-shot-reach-mac-results
description: "The Duo strip's Desktop button sends map-mode F11 to a Mac peer, and Shot became Window (Cmd+Shift+5); focused Duo tests and analyze are green."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: desktop-and-window-shot-reach-mac
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: ab9c97242fea65eba
  at: 2026-11-22T20:11:40-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-22T20:13:08-08:00
---

# Results: Desktop and Window reach the Mac

Candidate commit: 37d1d67bb (unit/desktop-and-window-shot-reach-mac, base 90529daea; captain commit of the implementer's working tree; results doc committed after)

Red first: the new and changed tests were run against the base Dart file before the source edit: 2 failed (Desktop map keys, combo table), 5 passed.

## Acceptance → tests

| Done-when | Proven by |
|---|---|
| D1 | `flutter/test/duo_status_strip_test.dart`: "Desktop on a Mac peer sends F11 down then up as map keys and no legacy key"; "Desktop on another peer sends today's legacy F11" |
| D2 | `flutter/test/duo_status_strip_test.dart`: "each tap button sends its one combo and no other modifiers" (`window` = `5`, Cmd+Shift; label `Window`; fifth button) |
| D3 | `flutter/test/duo_status_strip_test.dart`: the unedited Mission (Mac, other peer) and "another button on a Mac peer keeps its legacy combo" tests, green; diff touches two files plus this docs dir |
| D4 | the Gate section below |
| D5 | MISSING: Lucas's taps on the Duo (manual) |

## Gate

Run from `flutter/` in the worktree.

| Command | Exit status | Result |
|---|---|---|
| `flutter test test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart test/duo_status_strip_test.dart test/duo_trackpad_test.dart` | exit 0 | All tests passed, 68 tests |
| `flutter analyze lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart` | exit 0 | No issues found |

`flutter pub get` changed no tracked file; `git status --short` showed only the two owned files.

## Deviations

none

Cleanup: none

## Regression surface

| Existing path | Behaviour change | Why unavoidable |
|---|---|---|
| `kDuoShortcuts` fifth row | id `screenshot`→`window`, label `Shot`→`Window`, icon, key `4`→`5` | R2 itself |
| `duoPeerAwareSender` closure | Desktop (bare `VK_F11`) on iOS + guards + macOS peer now goes to `mapKey`; Mission and every other combo take the same branch as before | R1; the match is where Mission already diverges |
| Desktop on a non-Mac peer, or guards failing | none (legacy `VK_F11`) | pinned by the new legacy test |
| Layout, Quit guard, strip, Rust, bridge | none | not touched |

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE, no findings.

## Verify

Captain gate on 97cb24cc8, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 79 passed; `flutter analyze` on `duo_shortcuts.dart` and the strip test: exit 0, no issues. No Rust change, so no iOS library rebuild.
