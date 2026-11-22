---
name: top-strip-sends-mac-shortcuts-plan
description: "Plan for one centred row of eight Mac shortcut buttons in the Duo's top status strip, sent through a new explicit-modifier sender that never touches the deck's armed flags."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: top-strip-sends-mac-shortcuts
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T02:57:49-08:00
---

# Plan: the top strip sends Mac shortcuts

Spec: `docs/dispatch-loop/top-strip-sends-mac-shortcuts/spec.md` (stable). Base `5ae9f7593`, branch
`unit/top-strip-sends-mac-shortcuts`. Captain rulings applied: Show Desktop = F11; Quit = long press, label
"Hold Quit".

## 1. Approach

- One new file, `flutter/lib/mobile/duo/duo_shortcuts.dart`, holds everything new: the combo table, the sender
  type, the session sender, and the button-row widget.
- `flutter/lib/mobile/duo/duo_status_strip.dart` gets an optional `send` field. With `send == null`, or in a strip
  lower than the threshold, `build` returns the base widget tree unchanged. Otherwise it lays the status line over
  the button row.
- `DuoStatusStrip.forSession` passes the session sender, so `remote_page.dart` is not edited (its
  `above: DuoStatusStrip.forSession(gFFI, widget.id)` line already gets the row).
- No edit to `input_model.dart`, `duo_split.dart`, `duo_deck.dart`, the keyboard, trackpad or resolution files,
  and no Rust change. R6 holds without an exception.

## 2. Key path findings (read at base, not run)

Path of one button press, client to Mac:

| Step | Where | What happens |
|---|---|---|
| Dart call | `flutter/lib/models/input_model.dart:1342-1354` | `inputKey` passes the model's own `alt/ctrl/shift/command`. The strip cannot use it (R2) and calls `bind.sessionInputKey` itself |
| FFI | `src/flutter_ffi.rs:690-704` | `session_input_key` forwards name and the four flags to `session.input_key`; not gated per OS |
| Name to key | `src/ui_session_interface.rs:893-912` | a one-character name becomes `Key::_Raw(char)`; any other name is looked up in `KEY_MAP` and dropped silently when absent |
| Event | `src/ui_session_interface.rs:1127-1166` | `_Raw` sets `chr` (1152-1154), never `unicode` or `seq`; `press` true; mode `Legacy`; modifiers from `legacy_modifiers` (`src/keyboard.rs:425-456`), which adds exactly the flags passed |
| Valid names | `src/client.rs:5162, 5167, 5183, 5189` | `VK_F11`, `VK_TAB`, `VK_SPACE`, `VK_UP` are all `KEY_MAP` entries (`ControlKey::F11/Tab/Space/UpArrow`) |
| Mac receives | `src/server/connection.rs:3411-3431`, `1310-1320` | on macOS `press` becomes one down then one up through `handle_key` |
| Legacy mode | `src/server/input_service.rs:2208-2236` | `sync_modifiers` (1824-1833) sets the CGEvent flags from the event's modifier list (`add_flags_to_enigo`, 1751-1760) and releases modifiers that are down but not listed |
| Character | `src/server/input_service.rs:1850-1903` | `process_chr` types the character with `key_sequence` only when `has_hotkey_modifiers` is false (1878-1886). With Cmd or Ctrl in the list (1771-1789) it posts `Key::Layout(char)` as a keycode instead |
| Keycode | `libs/enigo/src/macos/macos_impl.rs:683-716`, `718-750` | digits always map through the ANSI table (`'4' => kVK_ANSI_4`, 750); letters map through the Mac's current layout, then the ANSI table (`c` 722, `q` 736, `v` 741) |

Conclusions the plan relies on:

- The names are `4`, `c`, `v`, `q`, lowercase. An uppercase letter is in neither keycode map, so `key_down` fails
  and the server falls back to typing the character (`input_service.rs:1890-1898`).
- Cmd+Shift+`4` reaches the Mac as keycode `kVK_ANSI_4` with the Command and Shift flags. It cannot turn into `$`:
  the client sends `chr` 0x34, and the server's typing branch is skipped because Command is in the modifier list.
  Shift alone would not count as a hotkey modifier; every character combo here carries Cmd.
- F11 with no modifier is posted with the event's own flags left alone (`macos_impl.rs:146-153`), which that
  comment says F11 needs.
- Not verified here: whether macOS acts on each injected combo. The spec's D6 checks Mission Control and Spotlight
  on the M6; F11 and Cmd+Tab are worth one tap each in the same check.
- Known limit, same as the deck: with the session's `allow_swap_key` toggle on, `swap_modifier_key`
  (`ui_session_interface.rs:699-727`) swaps Ctrl and Cmd in every key event, these included.

## 3. Sender interface (`duo_shortcuts.dart`)

```dart
/// Sends one press of [name] with exactly these modifiers.
typedef DuoShortcutSender = void Function(String name,
    {required bool alt,
    required bool ctrl,
    required bool shift,
    required bool command});

@immutable
class DuoShortcut {
  const DuoShortcut(this.id, this.label, this.icon, this.name,
      {this.ctrl = false,
      this.shift = false,
      this.command = false,
      this.hold = false});
  final String id;
  final String label;
  final IconData icon;
  final String name;
  final bool ctrl;
  final bool shift;
  final bool command;

  /// Sent on a long press only.
  final bool hold;
}

const List<DuoShortcut> kDuoShortcuts = [
  DuoShortcut('mission', 'Mission', Icons.grid_view, 'VK_UP', ctrl: true),
  DuoShortcut('spotlight', 'Spotlight', Icons.search, 'VK_SPACE', command: true),
  DuoShortcut('desktop', 'Desktop', Icons.desktop_windows_outlined, 'VK_F11'),
  DuoShortcut('switcher', 'Switch', Icons.swap_horiz, 'VK_TAB', command: true),
  DuoShortcut('screenshot', 'Shot', Icons.crop_free, '4', command: true, shift: true),
  DuoShortcut('copy', 'Copy', Icons.copy, 'c', command: true),
  DuoShortcut('paste', 'Paste', Icons.content_paste, 'v', command: true),
  DuoShortcut('quit', 'Hold Quit', Icons.power_settings_new, 'q', command: true, hold: true),
];

/// How many of [kDuoShortcuts] a narrow row keeps.
const int kDuoShortcutCore = 5;

DuoShortcutSender duoShortcutSender(FFI ffi) => (name,
    {required alt, required ctrl, required shift, required command}) {
  final input = ffi.inputModel;
  if (!input.keyboardInputAllowed || !input.keyboardPerm || input.isViewCamera) {
    return;
  }
  bind.sessionInputKey(
      sessionId: ffi.sessionId,
      name: name,
      down: false,
      press: true,
      alt: alt,
      ctrl: ctrl,
      shift: shift,
      command: command);
};
```

- Guards: `keyboardInputAllowed` (what `DuoDeckInput.sendKey` checks, `duo_deck.dart:165`) plus `keyboardPerm`
  and `isViewCamera` (what `inputKey` checks, `input_model.dart:1343-1344`). These three are read-only.
- It never reads or writes `InputModel.shift/ctrl/alt/command`. `down: false, press: true` matches what `inputKey`
  sends for a deck key.
- Imports: `package:flutter/material.dart`, `../../models/model.dart` show `FFI`,
  `../../models/platform_model.dart` (for `bind`).

Button row, same file:

```dart
class DuoShortcutRow extends StatelessWidget {
  const DuoShortcutRow({super.key, required this.send, required this.height});
  final DuoShortcutSender send;
  final double height;
  // build: LayoutBuilder -> count and slot width (section 4) -> Material(type: transparency,
  //   child: Row(mainAxisSize: min, children: [for the kept shortcuts: _button(s, slot)]))
}
```

Each button is
`SizedBox(key: Key('duo-shortcut-${s.id}'), width: slot, height: height, child: InkWell(...))` with
`borderRadius: BorderRadius.circular(8)`, `onTap: s.hold ? null : () => _fire(s)`,
`onLongPress: s.hold ? () => _fire(s) : null`, and a child
`Column(mainAxisAlignment: center, children: [Icon(s.icon, size: 18, color: Colors.white70), FittedBox(fit:
BoxFit.scaleDown, child: Text(s.label, maxLines: 1, style: TextStyle(color: Colors.grey, fontSize: 10)))])`.
`_fire(s)` is the only call into `send`:
`send(s.name, alt: false, ctrl: s.ctrl, shift: s.shift, command: s.command)`.

The `Material(type: MaterialType.transparency)` wrapper is needed for `InkWell` and matches the deck's session
row (`duo_deck.dart:63-64`). `FittedBox` keeps a long label inside a narrow slot and inside the test font's wide
glyphs without clipping or an overflow error.

## 4. Layout numbers

Constants in `duo_shortcuts.dart`:

| Name | Value | Meaning |
|---|---|---|
| `kDuoShortcutMinExtent` | 56 | least strip height that shows the row |
| `kDuoShortcutSlotMin` | 52 | least slot width; below 8 x 52 the row keeps five |
| slot max | 72 | a slot never grows wider |
| status box | 16 pt high, 11 pt text | the status line in the two-row layout |
| button height | `(h - 16).clamp(40, 48)` | `h` is the strip height |

Row rule, with `w` the width inside the 40 pt side padding:
`count = w >= 8 * 52 ? 8 : 5`, `slot = min(72, w / count)`, the row centred.

| Strip | Where it occurs | Inner width | Buttons | Slot | Button | Row x range | Column height |
|---|---|---|---|---|---|---|---|
| 669 x 79.19 | laptop pose, flat with a band, 16:9 | 589 | 8 | 72 | 72 x 48 | 46.5 .. 622.5 | 64 of 79.19 |
| 669 x 60 | flat without a band (`kDuoTopClear`) | 589 | 8 | 72 | 72 x 44 | 46.5 .. 622.5 | 60 of 60 |
| 466 x >= 56 | not reachable at base (see below) | 386 | 5 | 72 | 72 x 40..48 | 53 .. 413 | fits |
| any x < 56 | e.g. a 4:3 picture leaving a low strip | | 0 | | | | status line only, as at base |

- Every button is at least 52 x 40, so the 36 pt minimum holds in every case that shows the row. The status text
  is 11 pt in the two-row layout and stays 12 pt in the text-only layout.
- Icon 18 plus a 10 pt label is about 30 pt of content in a 40 pt button.
- The 60 pt flat strip is an exact fit (16 + 44). The implementer confirms no overflow there in the layout test
  (one extra `expect` on a 669 x 60 strip is in scope for the layout test).
- Where the strip shows, from `duo_split.dart`: `above` is laid out only when the picture offset is at least
  `kDuoStripMinExtent` (24), at `Positioned(top: _top, height: top)` (257-263). The offset is non-zero in two
  branches of `duoSplitFrom`: the inner screen with a band when the picture is shorter than the room above the
  band (80-88), and the flat inner screen without a band (89-94, always 60). The cover-screen branches (95-99)
  leave `pictureTop` at 0, so the cover screen shows no strip at base and gets no buttons. The 466 pt row above is
  what the rule would give if that ever changed.
- Hit testing: the strip is a later `Stack` child than the picture, and the picture's box starts below the strip,
  so a button gets its tap before the remote gesture layer. Only the buttons take pointers; the status line stays
  under `IgnorePointer`, and the gaps stay transparent to hits.

## 5. Edits per file

### 5.1 `flutter/lib/mobile/duo/duo_shortcuts.dart` (new, about 120 lines)

Sections 3 and 4 in full. Doc comments only where the reason is not obvious (AGENTS.md comments rule).

### 5.2 `flutter/lib/mobile/duo/duo_status_strip.dart`

Additive except for `build` and the factory:

1. Import `duo_shortcuts.dart`.
2. Constructor and field: `this.send`, `final DuoShortcutSender? send;` with the doc line "Sends the shortcut
   buttons' keys; null shows no buttons."
3. `forSession`: add `send: duoShortcutSender(ffi),`.
4. Class doc comment: drop "non-interactive" (it is no longer true); keep it one line.
5. `build`: rename the current body to `Widget _status(double fontSize)` returning the same `IgnorePointer >
   Padding(horizontal: 40) > Center > Text` tree with the font size as the only parameter. Then:

```dart
@override
Widget build(BuildContext context) {
  final send = widget.send;
  if (send == null) return _status(12);
  return LayoutBuilder(builder: (context, constraints) {
    final h = constraints.maxHeight;
    if (h < kDuoShortcutMinExtent) return _status(12);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(height: 16, child: _status(11)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: DuoShortcutRow(send: send, height: (h - 16).clamp(40.0, 48.0)),
      ),
    ]);
  });
}
```

   State, timer, listener and `_line()` are untouched, so content and refresh behaviour stay as at base.

### 5.3 `flutter/test/duo_status_strip_test.dart`

Three new `testWidgets` after the existing one, which is not edited. Shared, file-local helpers only: a recording
sender (a list of `(name, alt, ctrl, shift, command)` records) and a `_pump(tester, size, {send})` that pumps
`Directionality > Align(topLeft) > SizedBox.fromSize > DuoStatusStrip(now: fixed, send: send)`. Each test ends
with `await tester.pumpWidget(const SizedBox())` to cancel the strip's timer, as the existing test does.

1. **Combos.** In a 669 x 79 strip, for each of the seven tap rows of a local expected table (id, name, ctrl,
   shift, command; alt always false): tap `Key('duo-shortcut-$id')`, expect exactly one record equal to the row,
   clear. The fake also holds `armed = {shift, alt}` and the test expects it unchanged at the end. Stated
   plainly: the sender type has no way to reach armed state, so this last check documents R2 rather than
   exercising it; R2 itself is enforced by the sender's signature and the Mission row recording `shift: false,
   alt: false`.
2. **Quit.** `tester.tap` on `duo-shortcut-quit` records nothing; `tester.longPress` records one
   `('q', alt false, ctrl false, shift false, command true)`.
3. **Layout.** 669 x 79 with a sender: the status text and all eight keys are found; each button's
   `tester.getRect` is at least 36 wide and tall, with `left >= 40` and `right <= 629`. 669 x 60 with a sender:
   eight buttons, `tester.takeException()` is null. 669 x 40 with a sender: the text shows, no
   `duo-shortcut-*` key is found. 669 x 79 without a sender: the text shows, no button.

No new test file, harness or production test hook. Expected test diff is under twice the lib diff.

## 6. Regression surface

| Existing file | Existing path whose behaviour changes | Why it is unavoidable |
|---|---|---|
| `flutter/lib/mobile/duo/duo_status_strip.dart` `build` | With a sender and a strip of 56 pt or more, the status text drops from 12 to 11 pt, moves from the strip's centre to its upper row, and the strip's lower row takes taps. Without a sender, or below 56 pt, the widget tree is the base one | The row has to live in the strip (the request), and the strip was one `IgnorePointer` |
| `flutter/lib/mobile/duo/duo_status_strip.dart` `forSession` | Sessions built by it now pass a sender | R5: the row appears for these sessions without editing `remote_page.dart` |
| Remote session touch input | Taps on the eight button rectangles in the strip no longer fall through to whatever lay beneath the strip (black background at base) | Buttons must take their taps |

Not changed: `remote_page.dart`, `input_model.dart`, `duo_split.dart`, `duo_deck.dart`, `duo_keyboard.dart`,
`duo_trackpad.dart`, `duo_resolution.dart`, every Rust file, `src/lang/*` (labels are fixed English strings on a
Duo-only strip, as the deck's `esc` is; no new translation key).

## 7. Gates

Prep (the worktree lacks two gitignored files):

```
cp /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.dart \
   /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.freezed.dart \
   /Users/lucas/rustdesk-duo/.dispatch-workspaces/top-strip-sends-mac-shortcuts/flutter/lib/
cd /Users/lucas/rustdesk-duo/.dispatch-workspaces/top-strip-sends-mac-shortcuts/flutter
~/development/flutter/bin/flutter pub get
```

Focused gate, from `flutter/` in the worktree, also the closing gate:

```
~/development/flutter/bin/flutter test test/duo_*_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_shortcuts.dart \
    lib/mobile/duo/duo_status_strip.dart test/duo_status_strip_test.dart
```

- Pass: every `duo_*` test green; `analyze` reports no issue in the three files that base does not already
  report for `duo_status_strip.dart` and its test.
- This repo has no `scripts/tests/` lints, so none apply to the touched files.
- After the gate, `git status --short` must list only the two lib files, the test file and the unit's docs; the
  two copied bridge files are gitignored and are not staged. `pubspec.lock` must be unchanged by `pub get`; if it
  changed, restore it and say so in the results.

Captain-side check (D6), not part of the implementer's gate: an inner-screen screenshot of the strip, and the M6
reacting to Mission Control and Spotlight; one tap each of Desktop (F11) and Switch is recommended.

## 8. Implementer task (one)

1. Run the prep in section 7.
2. Write the three tests of 5.3; run the strip test file and see the new ones fail to compile or fail.
3. Add `duo_shortcuts.dart` (sections 3 and 4) and the strip edits (5.2).
4. Run the focused gate until green.
5. Minimization pass over the diff against section 6; revert anything not listed there.
6. Commit on `unit/top-strip-sends-mac-shortcuts` with explicit paths, and write the results doc: the gate
   commands and exit status, the measured button rectangles from the layout test, the regression-surface table,
   whether all eight buttons were kept (expected: yes at 669 pt; nothing dropped), and any deviation from this
   plan.

## 9. Forks

None needs a ruling before implementation. Three choices the captain may want to see, each made within the spec:

- Button labels stay English and unlocalized, like the deck's `esc`.
- The cover screen gets no row because it has no strip at base; adding a strip there would mean editing
  `duo_split.dart`, which R6 excludes.
- The slot minimum of 52 pt (not 36) decides when the row falls back to five, so a 466 pt strip would show five
  buttons, not eight squeezed ones.
