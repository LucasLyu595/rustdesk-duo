---
name: deck-drops-function-row-spec
description: "The Duo deck keyboard loses its esc/F1-F12 row; Esc becomes a button in the deck's control row and the trackpad takes the freed height."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: deck-drops-function-row
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T02:18:51-08:00
---

# Spec: the deck keyboard drops its function row

Base: `duo-mode` at `f03b7958d`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/deck-drops-function-row` (branch
`unit/deck-drops-function-row`). Work type: `code`.

## Intent

Lucas: "I don't need the function key "F1" etc in the keyboard". His rulings on the follow-up
questions:

1. Remove the whole esc/F1-F12 row from the deck keyboard. Esc becomes a button in the deck's
   control row (the row in the crease that holds ×, screen, keyboard, mouse, chat, ⋮). Esc sends
   the same key event the old Esc key sent. The number row stays as it is.
2. Keys keep their current size. The trackpad grows by the height the F row used.

Unchanged: the MacBook layout (no Fn key, arrows where they are), the status strip, the
full-width 16:9 picture on the crease, the auto-fit (960x540 in the laptop and flat poses), the
cover screen.

## Facts (captain, at base)

- `flutter/lib/mobile/duo/duo_keyboard.dart`: `_rows[0]` is `esc` (1.5 u, `VK_ESCAPE`) plus
  `f1`..`f12` (13/12 u, `VK_F1`..`VK_F12`). `build` gives `_rows.first` flex 1 and every other row
  flex 2, so the keyboard height splits into 11 parts: F row 1/11, each of the 5 other rows 2/11.
- `_tap` for a named key: `sink.sendKey(k.name!)`, then disarms every armed modifier, then
  `setState` (so armed keycaps repaint). The key event goes out through
  `DuoDeckInput.sendKey` → `InputModel.inputKey(name)` (only if `keyboardInputAllowed`), which
  applies the armed shift/ctrl/alt/command flags.
- `flutter/lib/mobile/duo/duo_deck.dart` `DuoDeck.build`: keyboard box height `5 * rowH + 16`
  (`rowH` from `(maxHeight - top) * 0.6 - 16) / 5`, clamped to 46), a 6 pt gap, then the trackpad
  `Expanded`. The session row (`Key('duo-session-row')`) shows `actions` when `actions` is not
  empty and `maxHeight >= 60`; `DuoDeckAction` is the row's button (white, 40x32).
- The actions are built in `remote_page.dart` `_duoDeckActions`; `DuoDeck` itself holds the
  `DuoKeySink` (`keys`).

## Required behavior

R1. **No function row.** The deck keyboard has 5 rows: number row (`` ` ``1..0 - = delete), tab
row, caps row, shift row, bottom row. No `esc` and no `F1`..`F12` keycaps. All other keys, labels,
widths and behavior are as at base.

R2. **Keys keep their size.** Each remaining row is exactly as tall as at base in the same deck:
the keyboard box is 10/11 of its base height (`(5 * rowH + 16) * 10 / 11`), rows share it equally.
Key widths do not change.

R3. **Trackpad grows.** The trackpad keeps filling the rest of the deck, so it gains the 1/11 of
the base keyboard height that the F row used. Gaps, padding, the session row, the band layout
(`rowExtent`) and the no-row / short-deck cases stay as at base.

R4. **Esc in the control row.** Whenever the deck shows its session row, the row has an Esc
button (`Key('duo-deck-esc')`, a `DuoDeckAction`-style button with the text `esc`), at the
row's left end, before the actions passed in. Tapping it does exactly what the old Esc key did:
`keys.sendKey('VK_ESCAPE')`, then disarms every armed modifier, and the keyboard's armed keycaps
repaint as unarmed. No Esc button when there is no session row. `remote_page.dart` needs no
change (the deck adds the button itself, since it owns `keys`).

R5. **Nothing else changes**: `duo_split.dart`, `duo_resolution.dart`, `duo_status_strip.dart`,
`duo_trackpad.dart`, `remote_page.dart` and the cover-screen path are not edited.

## Tests

- Update `flutter/test/duo_keyboard_test.dart` to the 5-row keyboard: the named-keys, labels and
  row-table tests no longer expect `esc` or F keys; one assertion that no `esc` / `f1`..`f12`
  keycap exists.
- `flutter/test/duo_deck_test.dart`: one new test for Esc in the control row (it is in the row,
  left of the passed actions; a tap sends `VK_ESCAPE` once with the armed modifier still armed at
  send time, then the modifier is disarmed and its keycap shows unarmed). Update existing deck
  tests only where the keyboard height changes; one assertion that the trackpad is taller than at
  base by the F row's share (or keyboard height = 10/11 of base) is enough.
- No new test infrastructure.

## Done when

D1. R1: keyboard test shows 5 rows and no esc/F keycaps; existing key behavior tests green.
D2. R2/R3: a deck test pins keyboard height = `(5 * rowH + 16) * 10 / 11` (or row height equal to
base) and the trackpad taking the rest.
D3. R4: the new deck test for Esc passes.
D4. R5: the diff touches only `duo_keyboard.dart`, `duo_deck.dart`, the two test files and the
unit's docs.
D5. Focused gate green: `flutter test` on all `flutter/test/duo_*_test.dart`; `flutter analyze`
on the two changed lib files has no new issue.
D6. On the Duo (captain): inner-screen screenshot shows the control row with Esc and a keyboard
without the F row.
