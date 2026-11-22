---
name: deck-drops-function-row-results
description: "The Duo deck keyboard lost its esc/F1-F12 row; Esc is a button at the left of the deck's session row and the trackpad took the freed 1/11 of the keyboard height; focused gate green."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: deck-drops-function-row
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: ad0a9a7b3462313c6
  at: 2026-11-22T02:22:58-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-22T02:24:34-08:00
---

# Results: the deck keyboard drops its function row

Candidate commit: 0cb094c1a (unit/deck-drops-function-row, base f03b7958d; captain commit of the implementer's working tree; results doc committed after)

Implemented the approved plan with the captain's ruling on the fork: `(context as Element).markNeedsBuild()` in `DuoDeck._esc` (decision 3), deck stays a `StatelessWidget`.

## Acceptance → tests

| Done-when | Proven by |
|---|---|
| D1 5 rows, no esc/F keycaps, key behaviour green | `flutter/test/duo_keyboard_test.dart`: `rows follow the MacBook table and line up` (63 keys, 60 pt row pitch, 13 `findsNothing` for esc/f1..f12); `named keys send their VK names`; `keycaps carry MacBook labels` |
| D2 keyboard height 10/11 of base, trackpad takes the rest | `flutter/test/duo_deck_test.dart`: `laptop: the session row sits in the band, keyboard right below` (kb.height = 246 * 10 / 11, trackpad top = kb.bottom + 6, trackpad bottom = 945) |
| D3 Esc in the row, sends VK_ESCAPE, disarms, repaints | `flutter/test/duo_deck_test.dart`: `esc sits at the row's left, sends Escape with the armed modifier, then disarms it`; no row, no Esc: `no actions: no session row` |
| D4 diff touches only the four files and the unit's docs | inspection: `git status --short` shows only `duo_keyboard.dart`, `duo_deck.dart`, the two test files (plus this doc); no automated test |
| D5 focused gate green | see Gate |
| D6 on-device screenshot | MISSING: captain's on-device check (manual) |

Red-first (once, lib files reverted to base, edited tests): `duo_keyboard_test.dart` + `duo_deck_test.dart` ran `+21 -3` (the Esc test, the laptop kb-height test and the keyboard row-table test failed). With the change restored they pass.

## Gate

Prep: copied `generated_bridge.dart` and `generated_bridge.freezed.dart` from the main checkout; `flutter pub get` changed no tracked file.

| Command (from `flutter/`) | Exit status | Result |
|---|---|---|
| `~/development/flutter/bin/flutter test test/duo_keyboard_test.dart test/duo_deck_test.dart test/duo_split_test.dart test/duo_resolution_test.dart test/duo_status_strip_test.dart test/duo_fold_test.dart test/duo_trackpad_test.dart` | exit 0 | +60: All tests passed |
| `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_keyboard.dart lib/mobile/duo/duo_deck.dart` | exit 0 | No issues found; baseline in `/Users/lucas/rustdesk-duo/flutter` also No issues found |

## Deviations

None.

Cleanup: none; the copied untracked bridge files `flutter/lib/generated_bridge.dart` and `flutter/lib/generated_bridge.freezed.dart` are left in place (gitignored, never staged).

## Regression surface

Diff: `duo_keyboard.dart` 0 added / 6 deleted; `duo_deck.dart` 20 added / 2 modified lines; tests +91/-15 in total with the lib.

| Existing file / runtime path | What changed | Why unavoidable |
|---|---|---|
| `duo_keyboard.dart` `_rows` | esc/F1-F12 row deleted; deck can no longer send `VK_F1`..`VK_F12` | R1 |
| `_DuoKeyboardState.build` | the `flex:` line removed: 5 rows of equal flex, each keeps its base height in the 10/11 box | R1, R2 |
| `DuoDeck.build`, keyboard box | height `(5 * rowH + 16) * 10 / 11`; trackpad `Expanded` gains the difference | R2, R3 |
| `DuoDeck.build`, session row (only when `showRow`) | `children` is Esc then the passed actions; `final deck = context as Element;` added | R4 |
| `DuoDeck` rebuild on an Esc tap | `markNeedsBuild` on the deck element; no state added | armed flags notify nobody |
| `DuoDeckInput`, `InputModel.inputKey`, `remote_page.dart` | none | R5 |

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no blocking findings.

| Nit | Disposition |
|---|---|
| Test diff over 2x the fix | kept: the spec requires the Esc test and its recording sink; the `esc` label check proves R4's label |
| D6 on-device check open | captain discharges it after the reinstall; recorded in `docs/DUO.md` |

## Verify

Captain gate on d6cded259, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 71 passed; `flutter analyze` on the two lib files: exit 0, no issues.
