---
name: duo-control-row-sits-in-crease-spec
description: "In the Duo laptop pose, keep the Mac picture above the crease and put the deck's control row in the crease band, with the keyboard and trackpad right below the band; auto-fit aims at the 669x456 picture area."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-control-row-sits-in-crease
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 41af5e2b-05b0-47c6-837a-53ef33c5a4f0
  at: 2026-11-22T00:16:00-08:00
---

# Spec: the deck's control row sits in the crease

Base: `duo-mode` at `d77b12c63` (unit `duo-picture-fills-to-deck` merged as `9138085fe`).
Worktree: `/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-control-row-sits-in-crease`
(branch `unit/duo-control-row-sits-in-crease`). Work type: `code`.

## Intent

After seeing `9138085fe` on the Duo (laptop pose: picture 669x501.75 over the crease, deck
below), Lucas said: "also i don't think we should extend the screen to crease but the control
line above the keyboard". Relayed request:

- Laptop pose: the Mac picture stays above the crease again (ends at the band top, about 456 pt),
  at full width as far as the mode allows.
- The deck's control row (×, screen, keyboard, mouse, chat, ⋮) moves into the crease band; its
  buttons take touches there. The "touches on the crease do nothing" rule goes.
- The keyboard and trackpad start right below the band. The deck gains the height the control
  row used.
- Auto-fit aims at the new picture area (669x456, about 3:2). The M6 has only 4:3 and 16:9 modes:
  pick the one that leaves less unused space; report the mode and the bars that remain.
- Flat pose: keep the current flat layout unless the same idea applies cleanly.

## Facts (captain)

- `flutter/lib/mobile/duo/duo_split.dart` at base: laptop pose (`laptopFoldFrom != null`, usable
  band) returns `DuoSplit(pictureBottom: y, deckTop: y, crease: band)` with `y` = `band.bottom`
  or, within `kDuoDeckGive` (12 pt), the full-width aspect height; `DuoSplitBody` puts a childless
  `AbsorbPointer` over `crease`. `DuoSplit.crease`, `kDuoDeckGive` and the AbsorbPointer were all
  added by `9138085fe` for the laptop rule that this unit replaces.
- Flat pose (inner, not laptop, aspect known): `min(T + W / a, 0.6 H)` for both edges. Fit area
  (`duoFitAreaFrom`): inner with usable band → `Size(W, band.bottom - T)`; inner, not laptop,
  no band → `Size(W, 0.6 H - T)`; else today's area.
- `flutter/lib/mobile/duo/duo_deck.dart` `DuoDeck.build`: `Padding(all: 6)`, then (if actions and
  `maxHeight >= 60`) the session row (`Key('duo-session-row')`, 32 pt high), a 6 pt gap, the
  keyboard (`Key('duo-keyboard')`, `5 * rowH + 16`, `rowH = ((maxHeight - top) * 0.6 - 16) / 5`
  clamped to 46), a 6 pt gap, the trackpad (`Expanded`).
- The deck is the `below` widget of `DuoSplitBody`, built in `remote_page.dart` `_duoSplit`.
- Measured band on the inner screen: `Rect(0, 455.5, 669, 40)`, view 669x951, `T = 0`.
- `chooseDuoResolution` minimises `|ln(mode aspect / area aspect)|`. For letterboxing, the unused
  share of the area is `1 - exp(-|ln r|)`, monotonic in that distance, so "closest aspect" already
  equals "least unused space". 669x455.5 (1.469): 4:3 distance 0.097, 16:9 distance 0.191 →
  4:3, 800x600. Picture 607.3x455.5 with side bars of 30.8 pt each (28,100 pt² unused); 16:9
  would give 669x376.3 with 39.6 pt bars top and bottom (53,000 pt² unused).

## Required behavior

R1. **Laptop pose split** (`laptopFoldFrom != null`, usable band): `pictureBottom = band.top`, the
deck starts at `band.top`, whatever the aspect. Nothing blocks touches in the band any more.

R2. **Control row in the band** (laptop pose only): the deck's session row is laid out inside the
band rect (vertically centred in it, full width, same buttons, still tappable), and the keyboard
starts at `band.bottom` (± 1 pt), the trackpad below it as before. Without a band (other poses)
the deck lays out exactly as at base.

R3. **Remove what R1 makes dead**: the laptop full-width rule (`kDuoDeckGive`), the crease
`AbsorbPointer` and any `DuoSplit` field kept only for it, unless the deck needs the band (then
keep one field, renamed for its new use). Per AGENTS.md, a later round simplifies an earlier
commit of the same feature rather than layering on it.

R4. **Auto-fit area, laptop pose**: `Size(W, band.top - T)` (669x455.5 → 800x600 on the M6). The
picker is unchanged (it already minimises unused space). Flat-with-band and flat-without-band
areas stay as at base (both pick 800x600).

R5. **Flat pose**: unchanged from base (picture `min(T + W / a, 0.6 H)` at full width, deck below,
no control row in the band). Cover, landscape, non-Duo: unchanged.

## Hard constraints

- AGENTS.md Editing Hygiene: logic in `flutter/lib/mobile/duo/`; `remote_page.dart` and
  `model.dart` at most thin hooks. No change to non-Duo paths. No Rust, bridge or codegen.
- No new kind of state (timers, post-frame callbacks, caches, global notifiers).
- Never commit `flutter/ios/Runner.xcodeproj/project.pbxproj`.

## Done when

D1. Laptop split: `pictureBottom == deckTop == 455.5` for 4:3, 16:9 and unknown aspect (unit test).
D2. Laptop deck (widget test at 669x951, band 455.5-495.5): the session row lies inside the band,
a tap on its × button there fires its action, and the keyboard's top is at 495.5 (± 1).
D3. Fit area: laptop gives 669x455.5 and picks 800x600 from a 4:3 + 16:9 list; flat areas
unchanged (unit test).
D4. Flat, cover, landscape, non-Duo results unchanged (existing tests pass; edits only where they
encode the laptop rule this unit replaces).
D5. Focused gate green: from `flutter/`, the six `test/duo_*_test.dart` files plus
`test/cursor_size_test.dart` and `test/floating_mouse_cursor_offset_test.dart`; `flutter analyze`
on the changed files reports no new issue.
D6. On the Duo (captain, after reinstall): laptop pose shows the picture above the crease, the
control row in the crease, the keyboard right below it; flat pose as before.

## Revision 1 (2026-11-22, same unit, before merge)

Lucas, relayed: "you actually right about one thing, that the screen should take up the entire
upper screen either, since there are rounded corners, but I want the gap at top, maybe we can
place something else there that won't be blocked". The inner screen's top corners are rounded
and would cut a picture that reaches the top. So in the laptop pose the spare height goes to a
strip at the TOP, the picture is full width and rests on the crease, and the strip shows a small
non-essential status line. R1-R5 stand except where these replace them.

R6. **Laptop auto-fit prefers full width.** In the laptop pose (fit area `Size(W, band.top - T)`,
669x455.5, aspect 1.469) auto-fit chooses among the modes at least as wide as the area
(`mode aspect >= area aspect`) the one closest in aspect, then the lowest (largest text); if no
mode is that wide, the existing `chooseDuoResolution` rule applies. The flat, cover and other
fits are unchanged (`chooseDuoResolution`). With the M6's 4:3 + 16:9 list this picks the lowest
16:9 mode (1280x720 in the plan's list).

R7. **Laptop picture rests on the crease.** With aspect `a` known and `W / a < band.top - T`, the
picture area is `pictureTop = band.top - W / a` to `band.top`: full width, no side bars, no bars
inside the area. The canvas height equals that area's height. Otherwise (aspect unknown, or the
picture as tall or taller than the area) `pictureTop = T`, as in R1 (a 4:3 mode picked by hand
gets side bars, as before). Touch and pointer coordinates inside the picture stay correct (the
picture child is moved, not the canvas offset).

R8. **Status strip** (laptop pose only, only when `pictureTop - T >= 24` pt): the strip from the
top of the view to `pictureTop` is black and shows one centred line, kept clear of the rounded
corners (at least 40 pt side inset, vertically centred in the strip), small grey text: the peer's
name (its hostname, else its ID), the round-trip delay in ms when the session reports it, and
the local time (HH:MM). Nothing in it is interactive or essential; missing values are left out.
Its own widget in its own file under `flutter/lib/mobile/duo/`; any timer for the clock lives
and dies with that widget.

R9. **Flat, cover, landscape, non-Duo**: unchanged (flat already checked on the Duo: full-width
4:3 picture, 669x501).

Done when (revision): D7 fit picks 1280x720 in the laptop pose from the plan's 4:3 + 16:9 list,
and 800x600 in flat and cover (unit test). D8 laptop split with 16:9: picture child occupies
`Rect(0, 79.19, 669, 376.31)` (closeTo), the strip widget lies above it, the session row in the
band, the keyboard at 495.5 (widget test); with 4:3 the picture area is 0..455.5 and no strip.
D9 strip text shows name, delay and time when known and omits the missing ones (widget test).
D10 report: the mode picked per pose and the text size of 1280x720 on the Duo compared with
800x600 (1280x720 full width: 669/1280 = 0.523 pt per Mac pt; 800x600 at 455.5 tall: 0.759; text
is about 69% as large).
