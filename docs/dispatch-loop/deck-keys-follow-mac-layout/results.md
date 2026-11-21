---
name: deck-keys-follow-mac-layout-results
description: "The Duo deck keyboard now follows a US MacBook layout (six rows of 14.5 units, half-height esc/F1-F12 row, Mac labels, local caps lock) and the duo test suites pass."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: deck-keys-follow-mac-layout
  modified: 2026-11-21
resource: flutter/lib/mobile/duo/duo_keyboard.dart
generated:
  by: claude/sonnet
  session: a36dec644b2bd3cec
  at: 2026-11-21T05:30:34-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-21T05:35:03-08:00
---

# Results: the deck keyboard follows a MacBook layout

Files changed: `flutter/lib/mobile/duo/duo_keyboard.dart`, `flutter/test/duo_keyboard_test.dart`.

## Gate

Baseline before the edit: 42 tests passed; analyze clean.

- `~/development/flutter/bin/flutter test --reporter=expanded test/duo_keyboard_test.dart test/duo_deck_test.dart test/duo_split_test.dart test/duo_fold_test.dart test/duo_trackpad_test.dart` — 44 tests, OK, exit 0 (after review round 1; was 45 before the F-key test was folded into the named-keys map)
- `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_keyboard.dart test/duo_keyboard_test.dart` — No issues found, exit 0

Candidate commit: `54f2396c5` (rebased onto duo-mode 3302a3b1f; captain re-ran six Duo test files there: 51 tests, exit 0)

## Acceptance → tests

| Criterion | Proven by |
| --- | --- |
| 1. Rows, order, unit widths, 14.5 sums, no fn | `rows follow the MacBook table and line up` (order, per-key width, 76 keys, no `duo-key-fn`, half-height row pitch) |
| 2. Arrows: four keys in one line at the right of the bottom row | `rows follow the MacBook table and line up` (row 5 order, shared top, right edge); `keycaps carry MacBook labels` (arrow glyphs) |
| 3. esc and F1-F12 send VK names | `named keys send their VK names` (esc); `F1 to F12 send their VK names` |
| 4. Caps lock latches, lights, letters only, ignores control/command, not sent | `caps lock latches, capitalises letters only and is never sent` |
| 5. MacBook words and symbols | `keycaps carry MacBook labels` |
| 6. No overflow at deck heights, all duo tests pass, analyze clean | unchanged `duo_deck_test.dart` overflow cases (all pass in the five-suite gate); analyze gate |

## Deviations

none. (Test 1 measures the right edge against the keyboard's own rect rather than 669, because the harness centres the 669 pt box in a wider window.)

## Regression surface

Only `duo_keyboard.dart` changed among existing files. Changed runtime paths: `_rows` (new rows, widths, labels); `_key` (flex multiplier 10 to 120, `armed` also true for latched `caps`); `build` (row flex 1 for the first row, 2 for the rest); `_tap` (early return for `caps`); `_glyph` (not-shifted branch capitalises letters when caps lock is on and control/command are not armed, identical with caps off); `_KeyCapState.build` (`textAlign: center`). `DuoKeySink`, `DuoModifier`, `_shifted`, `_label`, `dispose`, `_KeySpec`, `DuoDeck` untouched.

## Known limits

- Caps lock is deck-local: resets when the keyboard is rebuilt, does not follow the Mac's caps state.
- Top-row and two-line modifier labels scale down at small deck heights (they do not overflow); readability is an on-device check.
- A capital goes out via `sendKey('A')` with no modifier, the same path as the soft keyboard; widget tests cannot show the Mac typing it, so type a caps-lock word once on device.

## Review round 1

Gate re-run, same two commands: five-suite `flutter test` 44 tests, OK, exit 0; `flutter analyze` on the two files no issues, exit 0.

| Item | Disposition |
| --- | --- |
| 1. Test diff over 2x code | Fixed. F1-F12 folded into the `named keys send their VK names` map (now `final ids`, with a `for` entry); the Esc/Cmd/Ctrl `findsNothing` loop dropped; the table test compacted to `id: units` maps; label list shortened. Versus base `8dafe81e7`: code 35 added / 15 removed (50 changed), test 97 added / 3 removed (100 changed), ratio 2.0. |
| 2. Arrow churn | Fixed. The four arrow `_KeySpec` lines and the test's arrow list use the `\u2190` `\u2191` `\u2193` `\u2192` escapes again; no arrow line appears in the diff against base. |
| 3. Second caps tap sends nothing | Fixed. The test captures `sink.sent.length` before the second `caps` tap and compares after. |

Cleanup: none
