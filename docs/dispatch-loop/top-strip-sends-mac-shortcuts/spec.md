---
name: top-strip-sends-mac-shortcuts-spec
description: "The Duo's top status strip gets one centred row of Mac shortcut buttons (Mission Control, Spotlight, Show Desktop, app switcher, screenshot, copy, paste, quit) that only send key combos."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: top-strip-sends-mac-shortcuts
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T02:54:20-08:00
---

# Spec: the top strip sends Mac shortcuts

Base: `duo-mode` at `5ae9f7593` (unit `deck-drops-function-row` merged as `de2c972fb`). Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/top-strip-sends-mac-shortcuts` (branch
`unit/top-strip-sends-mac-shortcuts`). Work type: `code`.

## Intent

Lucas: "I top stripe is quite high actually, maybe we can actually put something there as well?"
Asked what, he answered "some media keys, like mission control, sportlight, even show desktop?"
and "Shortcut buttons". Relayed request:

- The top strip (about 79 pt above the 16:9 picture) gets one row of tappable buttons. The status
  text (Mac name · delay · time) stays, smaller if needed. Everything centred, clear of the
  rounded top corners.
- Media-style keys: Mission Control (Ctrl+Up), Spotlight (Cmd+Space), Show Desktop (the stock
  macOS shortcut).
- Shortcut buttons: app switcher (Cmd+Tab), screenshot area (Cmd+Shift+4), copy (Cmd+C), paste
  (Cmd+V), quit app (Cmd+Q, guarded against an accidental tap).
- Icons with short labels; each button at least about 36 pt. If all eight do not fit, keep the
  media three plus Cmd+Tab and screenshot, and report what was dropped.
- The buttons only send keys; they change no local state. Tests for the key combos. The strip
  gets the row in the laptop and flat poses, wherever the strip exists.

## Facts (captain, at base)

- `flutter/lib/mobile/duo/duo_status_strip.dart`: `DuoStatusStrip` is a stateful,
  `IgnorePointer` widget: one grey 12 pt line, horizontal padding 40, centred.
  `DuoStatusStrip.forSession(FFI ffi, String id)` builds it; `remote_page.dart` `_duoSplit` passes
  `above: DuoStatusStrip.forSession(gFFI, widget.id)`.
- `flutter/lib/mobile/duo/duo_split.dart` `DuoSplitBody.build`: `above` is placed at
  `Positioned(top: _top, height: top)` with `top = duoPictureOffset(split, _top)`, only when
  `top >= kDuoStripMinExtent` (24). Laptop pose 16:9 on the inner screen: strip 79.19 pt high,
  669 pt wide. The flat pose with a band lays out like the laptop pose. Flat without a band uses
  `kDuoTopClear` (60) under the top padding.
- Key sending: `InputModel.inputKey(name, down, press)` (`input_model.dart` 1342) calls
  `bind.sessionInputKey(sessionId, name, down, press, alt, ctrl, shift, command)` with the
  model's own `alt/ctrl/shift/command` flags (which the deck's armed modifiers set), and returns
  early unless `keyboardPerm` and not `isViewCamera`. `DuoDeckInput.sendKey` also checks
  `keyboardInputAllowed`. `bind.sessionInputKey` takes explicit modifier flags
  (`src/flutter_ffi.rs` 690).
- The deck already sends `VK_SPACE`, `VK_TAB`, `VK_UP` and character names such as `c` (with the
  model flags); on the Duo, Cmd then Space reached the Mac's Cmd+Space handler (DUO.md step 4).
- M6 hotkeys (`defaults read com.apple.symbolichotkeys`, 2026-11-22): Mission Control (32) and
  Show Desktop (36) are not overridden, so the stock defaults apply: Mission Control = Ctrl+Up,
  Show Desktop = F11. Spotlight's own Cmd+Space (64) is disabled on the M6; another app answers
  Cmd+Space there. Cmd+F3 is "Command + the Mission Control key", a media key, not the F3
  keycode, so it is not a reliable injected combo.

## Required behavior

R1. **Combos.** Eight buttons, in this order, each sending exactly one press (down+up) of one key
with exactly these modifiers and no others:

| Id | Label | Combo |
|---|---|---|
| mission | Mission | Ctrl + Up (`VK_UP`) |
| spotlight | Spotlight | Cmd + Space (`VK_SPACE`) |
| desktop | Desktop | F11 (`VK_F11`), no modifier |
| switcher | Switch | Cmd + Tab (`VK_TAB`) |
| screenshot | Shot | Cmd + Shift + 4 (the `4` key, not `$`) |
| copy | Copy | Cmd + C |
| paste | Paste | Cmd + V |
| quit | Hold Quit | Cmd + Q, on long press only |

The planner verifies, with file:line from the Rust key path (`session.input_key` and what it
does with a one-character name plus `shift`), the names that make the Mac receive the `4`,
`c`, `v`, `q` keycodes with these modifiers, and uses them.

R2. **No local state.** A button sends its modifiers explicitly; it never reads, sets or clears
the deck's armed modifier flags (`InputModel.shift/ctrl/alt/command`). Armed deck modifiers are
neither added to the combo nor disarmed. It respects the same send guards as the deck
(`keyboardInputAllowed`, `keyboardPerm`, not `isViewCamera`). No other local change (no
toolbar, dialog, zoom, cursor or setting).

R3. **Quit guard: long press.** A plain tap on Quit sends nothing; a long press sends Cmd+Q
once.

R4. **Layout.** In a strip tall enough for both (the planner sets the threshold so each button
is at least 36 pt square and the text stays readable, at least 10 pt), the strip shows the status
line on top and the button row below it, both centred, inside the existing 40 pt side padding
(clear of the rounded corners). Each button is an icon over a short label. All eight fit in the
669 pt inner strip; if a strip is narrower than eight times the slot minimum, the row keeps the
first five (media three, Switch, Shot) and drops the rest. A strip below the threshold shows the
status line only, exactly as at base. The status text keeps its content and refresh behavior;
only its size may shrink.

R5. **Where.** Wherever `DuoSplitBody` shows the strip (laptop pose, flat pose with or without a
band, any pose that has a strip tall enough), for a session built by
`DuoStatusStrip.forSession`. A `DuoStatusStrip` built without a key sender (tests, other uses)
shows no buttons.

R6. **Scope.** New code in `flutter/lib/mobile/duo/` (the strip file, or one new file beside it).
`remote_page.dart`, `input_model.dart`, `duo_split.dart`, the deck, keyboard, trackpad and
resolution files are not edited unless the plan shows that is impossible, with the reason.

## Tests

- One table-style test: tapping each of the seven tap buttons sends exactly its combo (name and
  the four modifier flags) once, via a fake sender; armed state in a fake is untouched.
- One test for Quit: a tap sends nothing, a long press sends Cmd+Q once.
- One layout test: in a 669x79 strip the eight buttons and the status text show, each button at
  least 36 pt wide and tall, all inside x 40..629; in a 40 pt strip only the text shows; without a
  sender no buttons show. The existing strip test stays green.
- No new test infrastructure.

## Done when

D1. R1/R2: the combo test passes, and the sender is the only path the buttons use.
D2. R3: the Quit test passes.
D3. R4/R5: the layout test passes; the existing strip test is green.
D4. R6: the diff touches only `flutter/lib/mobile/duo/` (plus tests and the unit's docs), or the
results doc names each other file with its reason.
D5. Focused gate green: `flutter test` on all `flutter/test/duo_*_test.dart`; `flutter analyze` on
the changed lib files has no new issue.
D6. On the Duo (captain): inner-screen screenshot shows the strip with the status text and the
button row; the M6 reacts to at least Mission Control and Spotlight.
