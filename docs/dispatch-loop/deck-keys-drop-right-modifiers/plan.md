---
name: deck-keys-drop-right-modifiers-plan
description: "Plan for editing the Duo deck keyboard row table so right command and right option go, space widens to 6.5 units, and caps lock and left control trade slots, with the keyboard tests updated to pin it."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: deck-keys-drop-right-modifiers
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T23:12:10-08:00
---

# Plan: the deck keyboard drops its right modifiers; caps lock and control swap

Spec: `docs/dispatch-loop/deck-keys-drop-right-modifiers/spec.md` (stable). Base `duo-mode` at `74f140b97`.
A data-only edit of `_rows` plus the matching test edits. No design or safety fork; scope is the spec's.

## Approach

`_rows` (`flutter/lib/mobile/duo/duo_keyboard.dart` lines 51-82) is the only source of layout. Every key is
`Expanded(flex: (units * 120).round())`, so widths follow the table and nothing else has to change. Behavior
keys off the id and the modifier, not the position: the caps latch is `k.id == 'caps'` (lines 130, 158), arming
is `k.modifier`. Moving a `_KeySpec` between rows therefore moves the key with its label and behavior intact.
`6.5 * 120 = 780` is an integer flex, and the bottom row still sums to 14.5.

## Edits to `duo_keyboard.dart` (`_rows` only)

1. Caps row, first entry (line 61): replace the `caps` spec with
   `const _KeySpec('ctrl', '⌃\ncontrol', 1.75, modifier: DuoModifier.ctrl),`.
2. Bottom row, first entry (line 71): replace the `ctrl` spec with `const _KeySpec('caps', 'caps lock', 1.25),`.
3. Bottom row, `space` (line 74): width `3.75` -> `6.5`.
4. Bottom row: delete the `cmd-r` and `option-r` lines (75-76).

Nothing outside `_rows` changes: no new comment, no reformatting, `option-l`, `cmd-l` and the arrows untouched.

## Edits to `flutter/test/duo_keyboard_test.dart`

| Test (line) | Reference | Change |
|---|---|---|
| `Cmd, Ctrl and Option arm for one key then disarm` (66) | `'option-r'` (72) | `'option-l'` |
| `tapping an armed modifier again disarms it without a key` (109) | `'cmd-r'` (116) | Drop the entry; `'option-l'` and the other two stay. A map cannot hold `cmd-l` twice, and command arming is covered at line 70. |
| `keycaps carry MacBook labels` (127) | option and command labels `findsNWidgets(2)` (139-141) | Shift stays at 2; `'⌥\noption'` and `'⌘\ncommand'` become `findsOneWidget`. `caps lock` and control label lines stay. |
| `rows follow the MacBook table and line up` (144) | caps row `'caps': 1.75` (151) | `'ctrl': 1.75` |
| same | bottom row (160-168) | `'caps': 1.25, 'option-l': 1.25, 'cmd-l': 1.5, 'space': 6.5`, then the arrows at 1 |
| same | `findsNWidgets(63)` (192) | `61` |
| same | new assertions | see below |
| `caps lock latches ...` (195), `ctrl` taps at 218 | ids only | No edit: ids are unchanged and found by key. |

New assertions inside the row-table test (no new test, no new helper):

- `cmd-r` and `option-r` absent: `find.byKey(Key('duo-key-$id'))` `findsNothing` for both, beside the existing
  `fn`/`esc` checks.
- Arrows unchanged from base. At base the arrows start 10.5 units in (1.25 + 1.25 + 1.5 + 3.75 + 1.5 + 1.25),
  and a key's left edge is `board.left + offset * 669 / 14.5 + 2`. Assert with literals, not values derived
  from the new table: for `left, up, down, right` at offsets `10.5, 11.5, 12.5, 13.5`,
  `rect(id).left` is `closeTo(board.left + offset * 669 / 14.5 + 2, 0.01)` and `rect(id).width + 4` is
  `closeTo(669 / 14.5, 0.01)`. This passes at base too, which is the point: it pins "unchanged".

The row loop's existing checks (same top, increasing left, width per units, last key flush right) cover R1 and
R2 widths once the table is updated. Expected test diff is about the size of the source diff.

## Regression surface

| Existing file / path | Behavior change | Why unavoidable |
|---|---|---|
| `duo_keyboard.dart` `_rows` caps row | First key is control at 1.75 | R1 |
| `duo_keyboard.dart` `_rows` bottom row | Caps lock first at 1.25; space 6.5; no right command or option | R2, R3 |
| `_key`, `_tap`, `_capsLetters`, `_KeyCap`, `DuoKeySink` | None (not edited) | - |
| Other rows, labels, shifted glyphs, deck, `docs/DUO.md` | None (not edited) | R3, R4 |

Known consequence, in scope by intent: right-hand command and option arming is gone; the left keys still arm
both modifiers, so no key combination is lost.

## Implementer task (one)

Apply the four `_rows` edits and the test edits above in the worktree, run the focused gate, and commit both
files in one commit on `unit/deck-keys-drop-right-modifiers`. Then write `results.md` with the regression
surface as observed, the gate commands and exit statuses, and any deviation. Do not touch `docs/DUO.md`,
the gitignored bridge files, or any other file.

## Focused gate (from `flutter/` in the worktree)

1. `~/development/flutter/bin/flutter test test/duo_*_test.dart` - all pass.
2. `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_keyboard.dart test/duo_keyboard_test.dart` -
   no new issue against base.
3. `git status --short` and `git diff --stat 74f140b97` list only the two files and the unit's docs dir (D3).

No `scripts/tests/` file is touched, so no repo lint applies beyond the above. D4 (on-device look) is Lucas's.
