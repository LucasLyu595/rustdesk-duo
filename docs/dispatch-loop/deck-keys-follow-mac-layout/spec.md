---
name: deck-keys-follow-mac-layout-spec
description: "The Duo deck keyboard follows a MacBook's US layout (rows, key widths, Mac labels, Esc and F1-F12 in a half-height top row, caps lock) with no fn key and the arrow keys left where they are."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: deck-keys-follow-mac-layout
  modified: 2026-11-21
generated:
  by: claude/claude-opus-5-5
  session: c1457871-3d7f-4483-a59f-623ec1426450
  at: 2026-11-21T05:30:00-08:00
---

# Spec: the deck keyboard follows a MacBook layout

Base: `duo-mode` at `8dafe81e7`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/deck-keys-follow-mac-layout`.
Owned code: `flutter/lib/mobile/duo/duo_keyboard.dart`, `flutter/test/duo_keyboard_test.dart`.

## Intent (Lucas's words)

The layout is "not great": "Not like a Mac", "but i also dont need a fn key, and i like how the
arrow key is placed here".

## Today (`_rows` in `duo_keyboard.dart`)

5 equal-height rows: `Esc` + `` `1234567890-= `` + Delete; Tab + `qwertyuiop[]\`; `asdfghjkl;'` +
Return (no caps lock); Shift + `zxcvbnm,./` + Shift; Ctrl, Option, Cmd, space, Cmd, Option,
then ← ↑ ↓ → in one line at the right. Rows have unequal unit totals, so key columns do not
line up. Labels: `Esc`, `Delete`, `Tab`, `Return`, `Shift`, `Ctrl`, `Option`, `Cmd`.

## Required layout (US MacBook, top to bottom)

Every row sums to the same 14.5 key units, so columns line up as on a MacBook.

| Row | Keys (units) |
| --- | --- |
| 0, half height | `esc` (1.5), `F1`…`F12` (13/12 each) |
| 1 | `` ` `` `1`…`0` `-` `=` (1 each), `delete` (1.5) |
| 2 | `tab` (1.5), `q`…`p` `[` `]` (1 each), `\` (1) |
| 3 | `caps lock` (1.75), `a`…`l` `;` `'` (1 each), `return` (1.75) |
| 4 | `shift` (2.25), `z`…`m` `,` `.` `/` (1 each), `shift` (2.25) |
| 5 | `control`, `option`, `command`, space, `command`, `option`, then ← ↑ ↓ → exactly as today (four 1-unit keys in one line at the right). No `fn` key. Widths of the modifiers and space chosen so the row sums to 14.5 (for example control 1.25, option 1.25, command 1.5, space 3.75, command 1.5, option 1.25, arrows 4 x 1). |

- Row 0 is half the height of the other rows (flex 1 against flex 2). The keyboard's total
  height stays what `DuoDeck` gives it; `duo_deck.dart` is not changed.
- Keycap labels follow a MacBook: lowercase words `esc`, `delete`, `tab`, `caps lock`, `return`,
  `shift`, `control`, `option`, `command`; the modifier symbols `⌃` `⌥` `⌘` `⇧` shown with
  their word (for example on two lines). Letters stay capitals; arrows stay arrow glyphs.
  Labels scale down to fit (the existing `FittedBox`).
- New keys send RustDesk's existing names: `VK_F1`…`VK_F12` (they exist in `src/client.rs`).
- **caps lock** is a local toggle on the deck, not sent to the Mac: while on, its cap is lit
  (the armed colour) and letter keys send capitals; it stays on until tapped again; other keys
  do not clear it. With control or command armed, letters stay lowercase (as Shift does today),
  so command + C still sends Cmd+C. Non-letter keys are not affected by caps lock.
- Modifier behaviour (one-shot arm, tap again to cancel, Shift symbols) is unchanged.
- Existing key ids (`duo-key-<id>`) stay for keys that remain, so tests and taps keep working;
  new ids: `caps`, `f1`…`f12`.

## Done when

1. The rows, key order and unit widths match the table; every row sums to 14.5 units; no `fn`.
2. The arrow keys are four keys in one line at the right end of the bottom row, as today.
3. esc and F1–F12 send `VK_ESCAPE` and `VK_F1`…`VK_F12`.
4. caps lock latches, lights, capitalises letters only, ignores control/command shortcuts, and
   is not sent to the Mac.
5. Labels follow the MacBook words and symbols.
6. The keyboard does not overflow at the deck heights the deck tests use (deck 250–455 pt
   tall, 466 and 669 pt wide); all `flutter/test/duo_*_test.dart` pass; `flutter analyze` shows
   no new issues in the touched files.

## Hard constraints

- Only the two owned files change. No change to `duo_deck.dart`, the trackpad, `remote_page.dart`,
  pbxproj, pubspec or generated files.
- AGENTS.md: smallest diff, no restating comments, tests assert what the user sees or sends
  (1–3 new tests plus edits to tests whose labels or rows changed).
