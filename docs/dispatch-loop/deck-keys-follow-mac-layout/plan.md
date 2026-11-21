---
name: deck-keys-follow-mac-layout-plan
description: "Plan to re-table the Duo deck keyboard as a US MacBook layout (six rows of 14.5 units, half-height esc/F-key row, Mac labels, local caps lock) in duo_keyboard.dart and its test."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: deck-keys-follow-mac-layout
  modified: 2026-11-21
generated:
  by: claude/claude-fable-5-2
  session: c1457871-3d7f-4483-a59f-623ec1426450
  at: 2026-11-21T05:28:56-08:00
---

# Plan: the deck keyboard follows a MacBook layout

Spec: `docs/dispatch-loop/deck-keys-follow-mac-layout/spec.md` (stable). Base `duo-mode` at
`8dafe81e7`, branch `unit/deck-keys-follow-mac-layout`.

One implementation task owns both files:

- `flutter/lib/mobile/duo/duo_keyboard.dart`
- `flutter/test/duo_keyboard_test.dart`

Nothing else changes (`duo_deck.dart`, trackpad, `remote_page.dart`, pbxproj, pubspec, generated
files, Rust). `DuoKeySink`, `DuoModifier` and the `DuoKeyboard` constructor keep their shape.

## 1. The new `_rows` table

Replace the `_rows` literal with this (six rows, each 14.5 units). Ids of keys that remain are
unchanged; new ids are `caps` and `f1`…`f12`.

```dart
final _rows = <List<_KeySpec>>[
  [
    const _KeySpec('esc', 'esc', 1.5, name: 'VK_ESCAPE'),
    for (var i = 1; i <= 12; i++)
      _KeySpec('f$i', 'F$i', 13 / 12, name: 'VK_F$i'),
  ],
  [
    ..._chars('`1234567890-='),
    const _KeySpec('delete', 'delete', 1.5, name: 'VK_BACK'),
  ],
  [
    const _KeySpec('tab', 'tab', 1.5, name: 'VK_TAB'),
    ..._chars('qwertyuiop[]\\'),
  ],
  [
    const _KeySpec('caps', 'caps lock', 1.75),
    ..._chars('asdfghjkl;\''),
    const _KeySpec('return', 'return', 1.75, name: 'VK_RETURN'),
  ],
  [
    const _KeySpec('shift-l', '⇧\nshift', 2.25, modifier: DuoModifier.shift),
    ..._chars('zxcvbnm,./'),
    const _KeySpec('shift-r', '⇧\nshift', 2.25, modifier: DuoModifier.shift),
  ],
  [
    const _KeySpec('ctrl', '⌃\ncontrol', 1.25, modifier: DuoModifier.ctrl),
    const _KeySpec('option-l', '⌥\noption', 1.25, modifier: DuoModifier.alt),
    const _KeySpec('cmd-l', '⌘\ncommand', 1.5, modifier: DuoModifier.command),
    const _KeySpec('space', '', 3.75, name: 'VK_SPACE'),
    const _KeySpec('cmd-r', '⌘\ncommand', 1.5, modifier: DuoModifier.command),
    const _KeySpec('option-r', '⌥\noption', 1.25, modifier: DuoModifier.alt),
    const _KeySpec('left', '←', 1, name: 'VK_LEFT'),
    const _KeySpec('up', '↑', 1, name: 'VK_UP'),
    const _KeySpec('down', '↓', 1, name: 'VK_DOWN'),
    const _KeySpec('right', '→', 1, name: 'VK_RIGHT'),
  ],
];
```

| Row | Ids, left to right | Units | Sum |
| --- | --- | --- | --- |
| 0 | `esc`, `f1`…`f12` | 1.5, 12 x 13/12 | 14.5 |
| 1 | `` ` `` `1`…`0` `-` `=`, `delete` | 13 x 1, 1.5 | 14.5 |
| 2 | `tab`, `q`…`p` `[` `]` `\` | 1.5, 13 x 1 | 14.5 |
| 3 | `caps`, `a`…`l` `;` `'`, `return` | 1.75, 11 x 1, 1.75 | 14.5 |
| 4 | `shift-l`, `z`…`m` `,` `.` `/`, `shift-r` | 2.25, 10 x 1, 2.25 | 14.5 |
| 5 | `ctrl`, `option-l`, `cmd-l`, `space`, `cmd-r`, `option-r`, `left`, `up`, `down`, `right` | 1.25, 1.25, 1.5, 3.75, 1.5, 1.25, 4 x 1 | 14.5 |

76 keys in all; no `fn`. Sent names: `VK_ESCAPE`, `VK_F1`…`VK_F12` (present in the `KEY_MAP` of
`src/client.rs`, lines 5152–5163 and 5181), the rest as today. `caps` has no `modifier`, `name`
or `char`: it is the one key that sends nothing.

Labels: words are lowercase (`esc`, `delete`, `tab`, `caps lock`, `return`); the four modifiers
carry their symbol on a first line and the word on a second (`⇧`/`shift`, `⌃`/`control`,
`⌥`/`option`, `⌘`/`command`); F keys read `F1`…`F12`; letters stay capitals and arrows stay
glyphs through the unchanged `_KeySpec.char` and `_label`.

### Flex precision (required for the columns to line up)

`_key` computes `flex: (k.units * 10).round()`. With the new widths that rounds 1.75 to 18, 2.25
to 23, 1.25 to 13, 3.75 to 38 and 13/12 to 11, so the rows would total 147, 145, 145, 146, 146
and 147 and the columns would drift. Change the multiplier to 120:
`flex: (k.units * 120).round()`. Every width is then an exact integer (1 → 120, 13/12 → 130,
1.25 → 150, 1.5 → 180, 1.75 → 210, 2.25 → 270, 3.75 → 450) and each row totals 1740.

## 2. The half-height row

In `build`, give each row's `Expanded` a flex: 1 for the first row, 2 for the others. One added
line; the `Padding`/`Row` body stays as is.

```dart
for (final row in _rows)
  Expanded(
    flex: identical(row, _rows.first) ? 1 : 2,
    child: Padding(
```

The keyboard still fills exactly the height `DuoDeck` hands it (`5 * rowH + 16`, 16 to 246 pt);
that height is now split 1:2:2:2:2:2 (eleven parts) instead of five equal rows. Each row keeps
its 2 pt top and bottom gap, so a top-row cap is `H/11 - 4` tall and a full cap `2H/11 - 4`.
Everything is `Expanded` and labels sit in the existing `FittedBox(scaleDown)`, so no height
overflows; at the smallest heights the caps simply shrink (the deck tests at 72 and 80 pt with
actions already drive `rowH` to about 0 today).

Two-line labels need centring: add `textAlign: TextAlign.center` to the `Text` in `_KeyCapState`
(one added line; single-line labels render the same).

## 3. Caps lock

- State: `bool _capsLock = false;` in `_DuoKeyboardState`. Local only; never goes to the sink.
  Nothing to do in `dispose` (the sink does not know about it); it resets when the keyboard's
  State is discarded.
- Tap: at the top of `_tap`, before the modifier branch:
  `if (k.id == 'caps') { setState(() => _capsLock = !_capsLock); return; }`. It sends nothing
  and does not touch armed modifiers (it behaves like tapping a modifier, not like a key).
  Because the normal key branch never writes `_capsLock`, other keys do not clear it.
- Lit: in `_key`, `armed: m != null && widget.sink.isArmed(m) || k.id == 'caps' && _capsLock`,
  so the cap takes the existing armed colour (`0xFF3D6FE0`). No change to `_KeyCap`'s fields.
- `_glyph`: only the not-shifted branch changes.

  ```dart
  bool get _capsLetters =>
      _capsLock &&
      !widget.sink.isArmed(DuoModifier.ctrl) &&
      !widget.sink.isArmed(DuoModifier.command);

  String _glyph(String c) {
    if (!_useShifted) {
      return _capsLetters && RegExp(r'[a-z]').hasMatch(c) ? c.toUpperCase() : c;
    }
    return _shifted[c] ?? c.toUpperCase();
  }
  ```

  Results: caps on → letters send capitals, digits and punctuation send themselves; caps on with
  control or command armed → lowercase letter (command + C still sends `c` with command armed);
  caps on with Shift armed → the existing Shift branch (capital letter, shifted symbol), as a
  Mac does; caps on with only option armed → capital with option armed, the same as Shift +
  option today.
- `_label`: unchanged. Letter caps already read as capitals in both states, as the spec keeps
  them; the lit `caps lock` cap is the only visible indicator.
- Transport: a capital goes out through `sendKey('A')` with no modifier armed. That is the path
  the mobile soft keyboard already uses for a typed capital (`InputModel.inputKey` →
  `Session::input_key`, one character → `Key::_Raw` chr), so no sink or Rust change is needed.

## 4. Tests (`flutter/test/duo_keyboard_test.dart`)

Existing tests: all seven keep passing unedited in behaviour, because every id they tap
(`esc`, `delete`, `return`, `tab`, `space`, arrows, `ctrl`, `option-l/r`, `cmd-l/r`,
`shift-l/r`, character keys) survives and modifier behaviour is unchanged. One is edited:

- `letters are labelled in capitals and arrows use arrow glyphs`: extend it (and rename to
  `keycaps carry MacBook labels`) because the label set changed. Keep the `C` / no `c` / arrow
  assertions; add `findsOneWidget` for `esc`, `delete`, `tab`, `caps lock`, `return`, `F1`,
  `F12`, `'⌃\ncontrol'`, and `findsNWidgets(2)` for `'⇧\nshift'`,
  `'⌥\noption'`, `'⌘\ncommand'`; `findsNothing` for the old `Esc`, `Cmd`, `Ctrl`.

New tests (three):

1. `rows follow the MacBook table and line up`. Using the existing 669 x 300 `_pump`, hold the
   spec table in the test as six lists of `(id, units)`. For every key read
   `tester.getRect(find.byKey(Key('duo-key-$id')))` and assert:
   - within a row all keys share one `top` and their `left` values strictly increase in table
     order (key order; arrows last and in one line: `left`, `up`, `down`, `right`, with
     `right`'s right edge at the row's right end, within the 2 pt gap);
   - `rect.width + 4` is `units * 669 / 14.5` (`closeTo(…, 0.01)`): pins every unit width, and
     since a row always fills the width, also pins that each row sums to 14.5;
   - row pitch: `top('1') - top('esc')` is `300 / 11` and `top('q') - top('1')` is `600 / 11`
     (the top row is half height);
   - `find.byKey(const Key('duo-key-fn'))` finds nothing, and exactly 76 widgets carry a
     `duo-key-` `ValueKey<String>` (`find.byWidgetPredicate`).
2. `F1 to F12 send their VK names`: tap `f1`…`f12`; `sink.sent` equals `VK_F1`…`VK_F12`.
   (`esc` → `VK_ESCAPE` stays covered by the existing named-keys test.)
3. `caps lock latches, capitalises letters only and is never sent`: tap `caps` → `sink.sent`
   empty, `sink.armed` empty, and the cap is lit (the `Container` under `duo-key-caps` has a
   `BoxDecoration` of colour `0xFF3D6FE0`, found with `find.descendant`); tap `a`, `1`, `;`,
   `a` → sent `['A', '1', ';', 'A']` with empty `armedAtSend` (latched, non-letters untouched);
   tap `cmd-l` then `c` → `c` with `{command}`; tap `ctrl` then `c` → `c` with `{ctrl}`; tap
   `caps` again → unlit, then `a` → `a`; `sink.sent` never contains a caps name.

Test diff stays below twice the code diff; no new helpers beyond the existing `_pump`/`_tap`.

## 5. Gate

Flutter is not on PATH; use `~/development/flutter/bin/flutter`, run from
`<worktree>/flutter`. Run both commands before the edit (baseline) and after; record both.

```sh
cd /Users/lucas/rustdesk-duo/.dispatch-workspaces/deck-keys-follow-mac-layout/flutter
~/development/flutter/bin/flutter test --reporter=expanded \
  test/duo_keyboard_test.dart test/duo_deck_test.dart test/duo_split_test.dart \
  test/duo_fold_test.dart test/duo_trackpad_test.dart 2>&1 | tail -3
~/development/flutter/bin/flutter analyze \
  lib/mobile/duo/duo_keyboard.dart test/duo_keyboard_test.dart 2>&1 | tail -5
```

Pass: `All tests passed!` with the count up by exactly three over the baseline, and the analyze
issue count for the two files no higher than the baseline (no new issues). The repo has no
`scripts/tests/` lints that apply to these files. Closing check: `git status --short` shows only
the two owned files (plus this unit's docs).

## 6. Done-when → test

| Done when | Covered by |
| --- | --- |
| 1. Rows, order, unit widths, 14.5 sums, no `fn` | new test 1 (order, width per unit, 76 keys, no `duo-key-fn`) |
| 2. Arrows: four keys in one line at the right of the bottom row | new test 1 (row 5 order, shared `top`, right edge); existing arrow-glyph and arrow VK assertions |
| 3. esc and F1–F12 send `VK_ESCAPE`, `VK_F1`…`VK_F12` | existing `named keys send their VK names` (esc); new test 2 |
| 4. Caps lock latches, lights, letters only, ignores control/command, not sent | new test 3 |
| 5. MacBook words and symbols | edited label test |
| 6. No overflow at deck heights 250–455 pt, 466 and 669 pt wide; all `duo_*_test.dart` pass; analyze clean | unchanged `duo_deck_test.dart` overflow cases (669 wide at 250/300/373/380/455; 466 wide with actions at 72/80/373/455); the five-suite gate; the analyze gate |

## 7. Regression surface

Existing file changed: `duo_keyboard.dart` only. Existing runtime paths whose behaviour changes,
each required by the spec:

- `_rows`: new rows, widths and labels (the feature).
- `_key`: flex multiplier 10 → 120 (needed for quarter and twelfth units to align), and `armed`
  also true for a latched `caps`.
- `build`: per-row flex 1/2 (half-height top row); character rows go from 1/5 to 2/11 of the
  keyboard height, about 9% shorter at the same deck height.
- `_tap`: an early return for `caps`; the modifier and key branches are untouched.
- `_glyph`: the not-shifted branch may now return a capital letter when caps lock is on; with
  caps lock off it returns `c` exactly as before.
- `_KeyCapState.build`: `textAlign: TextAlign.center` on the label.

Unchanged: `DuoKeySink`, `DuoModifier`, `_shifted`, `_useShifted`, `_label`, `dispose`,
`_KeySpec`, `_KeyCap`'s fields, `DuoDeck` and the heights it computes, the trackpad, and
everything the sink does with a key.

## 8. Decisions and known limits

Decided inside the approved scope (no fork needs a ruling):

- Shift carries `⇧` above its word, as the spec lists `⇧` among the symbols shown with their
  word, although a US MacBook prints only the word.
- Tapping `caps lock` leaves armed one-shot modifiers armed.
- Shift with caps lock on still gives a capital (macOS behaviour), not a lowercase letter.

Known limits, left as they are:

- Caps lock is deck-local: it resets when the deck is removed and rebuilt, and it does not
  follow or change the Mac's own caps lock state.
- Label size at small decks: with the height split eleven ways, a top-row cap is about 9 pt
  tall at a 250 pt deck and two-line modifier labels scale to roughly 9–10 pt at 466 pt wide.
  They scale down rather than overflow. If they read too small on the device, that is a
  `duo_deck.dart` height question outside this unit.
- A capital sent with no modifier relies on the same one-character path as the mobile soft
  keyboard; widget tests cannot show the Mac typing it, so the on-device check after merge
  should type a caps-lock word once.
