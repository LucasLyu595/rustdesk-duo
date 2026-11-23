---
name: deck-keys-drop-right-modifiers-spec
description: "The Duo deck keyboard loses right command and right option (the space bar takes their width, the arrows stay put) and swaps the positions of caps lock and left control."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: deck-keys-drop-right-modifiers
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T23:11:26-08:00
---

# Spec: the deck keyboard drops its right modifiers; caps lock and control swap

Base: `duo-mode` at `74f140b97`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/deck-keys-drop-right-modifiers` (branch
`unit/deck-keys-drop-right-modifiers`; gitignored Dart bridge files copied in). Work type: `code`.
Runs beside unit `duo-layout-follows-rotation`, which does not touch the keyboard files.

## Intent (Lucas, 2026-11-22)

1. Remove the RIGHT command and RIGHT option keys from the bottom row; the space bar takes the freed
   width. The arrow keys stay exactly where they are and keep their size. Left control, option and
   command keep their widths.
2. Swap the positions of caps lock and left control: control goes to the caps row's left end, caps
   lock to the bottom row's left end. Each key keeps its function, label and what it sends (or does
   not send: caps lock latches locally and is never sent); each takes the width of the slot it moves
   into.

## Facts (captain, at base)

`flutter/lib/mobile/duo/duo_keyboard.dart` `_rows`, widths in units, every row 14.5 units, each
key `Expanded(flex: units * 120)`:
- caps row: `caps` ('caps lock', 1.75), `a`..`'`, `return` (1.75).
- bottom row: `ctrl` ('⌃\ncontrol', 1.25, `DuoModifier.ctrl`), `option-l` (1.25), `cmd-l` (1.5),
  `space` (3.75), `cmd-r` (1.5), `option-r` (1.25), `left` `up` `down` `right` (1 each).
- Keycap keys are `Key('duo-key-<id>')`; caps lock behavior keys off `k.id == 'caps'`.

## Required behavior

R1. Caps row: `ctrl` (label and modifier unchanged) at 1.75, then `a`..`'`, `return` 1.75.
R2. Bottom row: `caps` (label and latch unchanged) at 1.25, `option-l` 1.25, `cmd-l` 1.5, `space`
6.5 (3.75 + 1.5 + 1.25), then the four arrows at 1 each. Still 14.5 units, so each arrow keeps its
x position and size.
R3. No `cmd-r` or `option-r` keycap. Everything else (other rows, labels, shifted glyphs, arming,
caps lock latch, deck) unchanged.
R4. Scope: `duo_keyboard.dart` and `flutter/test/duo_keyboard_test.dart` only (plus the unit's
docs). `docs/DUO.md` is the captain's.

## Tests

Update the row-table test to the new rows and key count (61 keycaps); assert the arrows' rects equal
base (x and width) and that `cmd-r`/`option-r` are absent; keep the arming, caps lock and other
existing tests green (adjust only ids that moved). No new infrastructure.

## Done when

D1. R1-R3 pinned by the updated keyboard tests.
D2. Focused gate: `flutter test` on all `flutter/test/duo_*_test.dart`; `flutter analyze` on the
changed files; no new issue.
D3. The diff touches only the two files and the unit's docs.
D4. On the Duo (Lucas): the bottom row reads caps lock, option, command, wide space, arrows; the caps
row starts with control.
