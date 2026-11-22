---
name: deck-drops-function-row-plan
description: "Plan to delete the esc/F1-F12 row from the Duo deck keyboard, shrink the keyboard box to 10/11 so keys keep their size and the trackpad takes the rest, and add an Esc button at the left of the deck's session row that sends VK_ESCAPE, disarms the modifiers and rebuilds the deck."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: deck-drops-function-row
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T02:21:17-08:00
---

# Plan: the deck keyboard drops its function row

Spec: `docs/dispatch-loop/deck-drops-function-row/spec.md`. Base `duo-mode` at `f03b7958d`.
Worktree `/Users/lucas/rustdesk-duo/.dispatch-workspaces/deck-drops-function-row` (branch
`unit/deck-drops-function-row`). One task, one implementer.

## Files touched

| File | Change | Notes |
|---|---|---|
| `flutter/lib/mobile/duo/duo_keyboard.dart` | 5 lines deleted, 0 added | the first entry of `_rows`; the `flex:` line in `build` |
| `flutter/lib/mobile/duo/duo_deck.dart` | 2 lines modified, about 14 added | keyboard box height; the row's `children`; one captured `Element`; one new method `_esc` |
| `flutter/test/duo_keyboard_test.dart` | edit | 3 tests updated to 5 rows, one no-esc/F assertion |
| `flutter/test/duo_deck_test.dart` | edit | 1 recording sink, 1 new test, 3 + 1 assertions added to two existing tests |

Nothing else: no `remote_page.dart`, `duo_split.dart`, `duo_resolution.dart`,
`duo_status_strip.dart`, `duo_trackpad.dart`, `input_model.dart`, Rust, bridge, lang file,
pubspec or `project.pbxproj` (R5, D4).

## Facts checked while planning (beyond the spec's)

- `_rows.first` is read in one place only, the `flex:` line of `_DuoKeyboardState.build`. With the
  F row gone, that line would give the number row flex 1; it has to go with the row.
- `VK_ESCAPE` and `VK_F1`..`VK_F12` appear in the Duo code only in the deleted `_rows` entry.
- `DuoDeck(` is constructed by `DuoDeck.forSession` and by `duo_deck_test.dart` only;
  `DuoDeckAction(` is constructed only in `remote_page.dart` `_duoDeckActions` (7 sites) and the
  deck test. Neither constructor changes.
- The app runs Material 2 (`useMaterial3: false`, `common.dart` 374 and 473). An M2 `IconButton`
  gives its `color` to icons through `IconTheme` only; a `Text` child takes the ambient
  `DefaultTextStyle` of the row's `Material`, which is the theme's body colour (dark on the light
  theme, so unreadable on the black deck). The Esc label therefore carries its own white style.
- The pinned Flutter's `LayoutBuilder` (`layout_builder.dart` 72, 184) has
  `updateShouldRebuild => true`: when the widget that owns a `LayoutBuilder` rebuilds, the builder
  runs again. `DuoKeyboard(key: ..., sink: keys)` in the deck is not `const`, so each run hands
  `_DuoKeyboardState` a new widget and its `build` runs, re-reading `sink.isArmed` for every
  keycap.
- Widest row: 6 passed actions plus Esc is 7 x 40 = 280 pt; the narrowest deck (cover, 466 pt)
  has 454 pt inside its padding. No overflow.
- The worktree has no `flutter/.dart_tool` and no gitignored `flutter/lib/generated_bridge.dart` /
  `generated_bridge.freezed.dart`; the main checkout has both files. See "Gate".

## Decisions

### 1. R1: the keyboard loses the row (`duo_keyboard.dart`)

Delete the first list of `_rows` (the 4 lines `[`, the `esc` spec, the `for` over `f$i`, `],`) and
the line `flex: identical(row, _rows.first) ? 1 : 2,` in `build`. `Expanded` then has its default
flex 1 for all 5 rows, so they share the height equally. Nothing is added to this file; `_tap`,
`_key`, `_KeyCap`, `dispose`, the `DuoKeySink` interface and every other row are untouched.

### 2. R2/R3: the keyboard box (`duo_deck.dart`)

One expression: `height: 5 * rowH + 16,` becomes `height: (5 * rowH + 16) * 10 / 11,`.

`rowH`, `top`, `gap`, `showRow`, `strip`, the paddings and the 6 pt gap are not edited. At base a
non-F row was 2/11 of the box; now each of 5 rows is 1/5 of 10/11 of the same box, the same 2/11.
The trackpad is the `Expanded` that follows, so it takes the 1/11 without an edit. In the laptop
pose on the M6 (deck 455.5-951, strip 40): `rowH` 46, box 246 -> 223.64, trackpad 197.5 -> 219.86.
A shorter deck only makes the keyboard box smaller than at base, so every no-overflow case of the
base still holds.

### 3. R4: Esc in the row, and how the keyboard repaints

`DuoDeck` stays a `StatelessWidget`. The armed keycaps are not state the deck owns: the keyboard
reads `sink.isArmed` in its `build`, and the sink (`InputModel` flags) notifies nobody. So after
Esc disarms the modifiers, the keyboard only needs to be built again. The smallest way to do that
from a stateless deck is to mark the deck's own element dirty:

```dart
// DuoDeck.build, first line (added)
final deck = context as Element;

// the session row's children (1 line modified)
children: [
  DuoDeckAction(
      key: const Key('duo-deck-esc'),
      icon: const Text('esc',
          style: TextStyle(color: Colors.white, fontSize: 13)),
      onPressed: () => _esc(deck)),
  ...actions,
]),

// new method on DuoDeck
void _esc(Element deck) {
  keys.sendKey('VK_ESCAPE');
  for (final m in DuoModifier.values) {
    if (keys.isArmed(m)) keys.setArmed(m, false);
  }
  // The keyboard reads the armed flags when it builds; they notify nobody.
  deck.markNeedsBuild();
}
```

Chain: `deck.markNeedsBuild()` -> `DuoDeck.build` -> a new `LayoutBuilder` (its builder runs
again, see facts) -> a new `DuoKeyboard` widget for the same `Key('duo-keyboard')` element ->
`_DuoKeyboardState.build` -> every `_KeyCap` gets `armed: false`. The state object is kept, so
caps lock stays latched, as it did when the old Esc key was tapped. The trackpad's state is kept
the same way (it is rebuilt exactly as a page `setState` already rebuilds it).

`deck` is the outer `build` context, captured in a local because the `LayoutBuilder` builder's own
parameter is also named `context`. The deck's element is used, not the `LayoutBuilder`'s, so the
result does not depend on how a Flutter version treats `markNeedsBuild` on a `LayoutBuilder`
element. The element is mounted whenever the button can be tapped (the button is its descendant).

Order matches `_tap` at base: send first (the armed flags are still set, so Cmd+Esc etc. go out
with their modifiers), then disarm, then repaint. The three-line disarm loop repeats the one in
`_tap`; AGENTS.md prefers that to reshaping `_tap` so both share it.

The button is a plain `DuoDeckAction` (40x32, same hit area as its neighbours); the label has its
own white style because of the Material 2 fact above. It is in the row whenever the row is
(`showRow`), first in the list, so it is at the left end; with no row there is no Esc (R4).
`remote_page.dart` is not edited.

Rejected:

- **`DuoDeck` becomes a `StatefulWidget` with `setState`.** Same effect, but every field read in
  `build` gains `widget.`, the class splits in two, and about 15 existing lines change for one
  rebuild. Against "the ideal diff adds lines and modifies none".
- **A `StatefulBuilder` around the `Column`.** Re-indents the whole column (about 25 existing lines
  show as modified).
- **A `Listenable` (or controller) parameter on `DuoKeyboard`.** New public API on the keyboard
  plus listener lifecycle in its state (`initState`, `didUpdateWidget`, `dispose`), and the deck
  would have to own and dispose the notifier, which needs a `State` anyway.
- **A `GlobalKey` to the keyboard state and a public "repaint" method.** The existing
  `Key('duo-keyboard')` would change type, the key needs an owner with a lifetime, and the state
  class would become public.
- **Esc logic inside `duo_keyboard.dart`.** The button is not a descendant of the keyboard, so it
  still needs one of the mechanisms above to reach the state.

Fork for the captain (not a scope change): `(context as Element).markNeedsBuild()` is the
framework's own primitive behind `setState`, but it is unusual in app code. If the captain
prefers the conventional form, the first rejected option (stateful deck) is the fallback; the
tests below pin behaviour only and pass with either.

## Task (one implementer)

Owned files: the four in "Files touched".

1. `duo_keyboard.dart`: decision 1.
2. `duo_deck.dart`: decisions 2 and 3. No import changes (`DuoModifier` comes from the existing
   `duo_keyboard.dart` import). Put `_esc` between `build` and the class's closing brace.
3. Tests below.
4. Minimization pass, then the gate. Commit with explicit paths.

## Tests

### `flutter/test/duo_keyboard_test.dart` (3 tests updated)

| Test | Old | New |
|---|---|---|
| `named keys send their VK names` | map starts with `'esc': 'VK_ESCAPE'` and ends with `for (var i = 1; i <= 12; i++) 'f$i': 'VK_F$i'` | both entries removed; the other eight stay |
| `keycaps carry MacBook labels` | `'esc delete tab return F1 F12'.split(' ')` | `'delete tab return'.split(' ')` |
| `rows follow the MacBook table and line up` | `rows` begins with `{'esc': 1.5, for ... 'f$i': 13 / 12}` | that map removed (5 rows) |
| same | `expect(rect('1').top - rect('esc').top, closeTo(300 / 11, 0.01));` | removed |
| same | `expect(rect('q').top - rect('1').top, closeTo(600 / 11, 0.01));` | `closeTo(300 / 5, 0.01)` (the test pumps a fixed 300 pt keyboard, 5 equal rows) |
| same | `findsNWidgets(76)` | `findsNWidgets(63)` (76 less 13) |
| same, added beside the `duo-key-fn` line | none | `for (final id in ['esc', for (var i = 1; i <= 12; i++) 'f$i']) { expect(find.byKey(Key('duo-key-$id')), findsNothing); }` |

`_pump` keeps its 669x300 box. The other six tests are not edited.

### `flutter/test/duo_deck_test.dart`

Added fake (the existing `_Keys` stays for the other tests), same shape as the keyboard test's:

```dart
class _RecordingKeys implements DuoKeySink {
  final armed = <DuoModifier>{};
  final sent = <String>[];
  final armedAtSend = <Set<DuoModifier>>[];

  @override
  bool isArmed(DuoModifier m) => armed.contains(m);
  @override
  void setArmed(DuoModifier m, bool a) => a ? armed.add(m) : armed.remove(m);
  @override
  void sendKey(String name) {
    sent.add(name);
    armedAtSend.add({...armed});
  }
}
```

| # | Test | Asserts |
|---|---|---|
| E1 | new: `esc sits at the row's left, sends Escape with the armed modifier, then disarms it` (widget) | Deck 466x373 in the `Align`/`SizedBox` used by `session actions: ...`, `keys: _RecordingKeys()`, one action `DuoDeckAction(icon: Icon(Icons.clear), ...)`. (a) `find.descendant(of: find.byKey(Key('duo-session-row')), matching: find.byKey(Key('duo-deck-esc')))` finds one, and `find.descendant(of: esc, matching: find.text('esc'))` finds one. (b) `tester.getRect(esc).right <= tester.getRect(find.byIcon(Icons.clear)).left`. (c) tap `Key('duo-key-cmd-l')`, pump: the keycap's `Container` colour (same finder as the keyboard test's `capColor`) is `Color(0xFF3D6FE0)`. (d) tap Esc, pump: `keys.sent == ['VK_ESCAPE']`, `keys.armedAtSend.single == {DuoModifier.command}`, `keys.armed` is empty, and the `cmd-l` colour is not `0xFF3D6FE0` |
| E2 | `laptop: the session row sits in the band, keyboard right below`, 3 lines added | `expect(kb.height, closeTo(246 * 10 / 11, 0.01));` `expect(tp.top, closeTo(kb.bottom + 6, 0.01));` `expect(tp.bottom, closeTo(945, 0.01));` (`rowH` is 46 there, so the base box is `5 * 46 + 16 = 246`; the trackpad runs to the deck's bottom padding) |
| E3 | `no actions: no session row`, 1 line added | `expect(find.byKey(const Key('duo-deck-esc')), findsNothing);` |

No existing expectation in this file changes value: the other tests pin the row position, the
keyboard's top and "no exception", none of which move. The last colour check in E1(d) is the one
that fails if the deck stops rebuilding the keyboard.

Red-first for the results doc: with the tests edited and the sources at base, E1 fails (no
`duo-deck-esc`), E2 fails on `kb.height` (246), and the keyboard test fails on the key count and
the no-esc assertion. Record once; do not keep a failing commit.

Test diff against fix diff: the fix is about 20 changed lines, the tests about 45 added, most of
it the fake and E1. That is over AGENTS.md's 2x guide; E1 is the test the spec names, and the fake
is the least needed to see "armed at send time". Nothing else is added.

## Acceptance -> tests

| Done-when | Evidence |
|---|---|
| D1 5 rows, no esc/F keycaps, key behaviour green | the updated row-table test (63 keys, 60 pt row pitch, 13 `findsNothing`); the six unedited keyboard tests |
| D2 keyboard height 10/11 of base, trackpad takes the rest | E2 |
| D3 Esc in the row | E1; no row, no Esc: E3 |
| D4 only the four files and the unit's docs | `git status --short` / `git diff --stat f03b7958d` before the commit |
| D5 focused gate | commands under "Gate" |
| D6 on the Duo | captain, after merge and reinstall; not part of this gate |

## Gate

Preparation, once, in the worktree (none of it is committed):

1. `cp /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.dart /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.freezed.dart flutter/lib/`
   The files are gitignored and absent from the worktree; the tests cannot compile without them.
   This is a copy, not a codegen run. If the main checkout lacks them, stop and report; do not run
   `flutter_rust_bridge_codegen`.
2. From `flutter/`: `~/development/flutter/bin/flutter pub get`. If it changes a tracked file (for
   example `pubspec.lock`), restore it with `git checkout -- <file>` and say so in the results doc.

Focused and closing gate, from `flutter/` (the same commands both times):

```
~/development/flutter/bin/flutter test test/duo_keyboard_test.dart test/duo_deck_test.dart test/duo_split_test.dart test/duo_resolution_test.dart test/duo_status_strip_test.dart test/duo_fold_test.dart test/duo_trackpad_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_keyboard.dart lib/mobile/duo/duo_deck.dart
```

Pass: every test passes; `analyze` reports no issue that the base does not have in the same two
files. For the baseline, run the same `analyze` line once in the main checkout
`/Users/lucas/rustdesk-duo/flutter` (read-only, `duo-mode` at the base commit) and compare the
issue lists.

This unit touches nothing under `scripts/tests/`, and this repository has no scratch-git or
selftest-coverage lint, so none joins the gate. `git status --short` before the commit must show
only the four files above plus this unit's docs; `flutter/ios/Runner.xcodeproj/project.pbxproj`
and the copied bridge files are never staged. Stage explicit paths.

## Regression surface

| Existing file / runtime path | What changes | Why unavoidable |
|---|---|---|
| `duo_keyboard.dart` `_rows` | the esc/F1-F12 row is gone; the deck can no longer send `VK_F1`..`VK_F12` | R1 (Lucas's ruling) |
| `_DuoKeyboardState.build` | 5 rows of equal flex instead of 1 + 5 x 2; in a box of 10/11 the base height each remaining row has its base height; key widths are per row and unchanged | R1, R2 |
| `DuoDeck.build`, keyboard box | height `(5 * rowH + 16) * 10 / 11`; the trackpad `Expanded` gains the difference. `rowH`, `top`, `gap`, strip and paddings unedited | R2, R3 |
| `DuoDeck.build`, session row (only when `showRow`) | `children` is Esc followed by the passed actions; with `spaceEvenly` the passed buttons sit closer together and further right than at base | R4 |
| `DuoDeck.build`, no row (no actions, or deck under 60 pt) | none besides the keyboard box height | R4 |
| `DuoDeck` rebuild on an Esc tap | the deck subtree is built once more, as any parent rebuild already does; no state is added or reset | R4: the armed flags notify nobody |
| `DuoDeckInput`, `InputModel.inputKey`, `remote_page.dart` `_duoDeckActions` | none; Esc goes through the same `sendKey('VK_ESCAPE')` as the old key, including the `keyboardInputAllowed` check | R4, R5 |

The cover screen shows the same deck, so it gets the same keyboard and the Esc button without an
edit to its path. Desktop, web, Android and non-Duo iOS never build the deck: no path changes.

## Spec readings and known limits

1. **Esc label style.** The spec says "a `DuoDeckAction`-style button with the text `esc`"; the
   plan uses `DuoDeckAction` itself with a white 13 pt `Text` as its `icon`. The size is a visual
   choice the captain can adjust at D6 without touching the tests.
2. **`rowH` formula kept.** The spec fixes the box at 10/11 of the base box, so `rowH` is still
   computed as if 60% of the deck went to a 5.5-row keyboard. The keyboard now takes about 55% of
   the deck. Retuning the split is not in scope.
3. **Function keys.** After this unit the deck has no way to send F1-F12; the iOS soft keyboard's
   key row (opened from the deck's keyboard button) still has them. As ruled.
4. **Caps lock is not a modifier of the sink**; Esc leaves it latched, as the old Esc key did.
