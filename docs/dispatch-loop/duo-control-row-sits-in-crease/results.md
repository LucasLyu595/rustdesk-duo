---
name: duo-control-row-sits-in-crease-results
description: "Results of the unit: laptop-pose picture ends at the crease band's top and rests on it at full width under a status strip, the deck's session row sits in the band with the keyboard right below, and auto-fit picks the lowest 16:9 mode."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-control-row-sits-in-crease
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: a47e0a1e4a035b5ff
  at: 2026-11-22T00:33:34-08:00
---

# Results: the deck's control row sits in the crease (round 2: review fixes and Revision 1)

Candidate commit: 815b11d25 (unit/duo-control-row-sits-in-crease, base d77b12c63; captain commit of the implementer's fix1+revision1 diff on top of 5cca141fd)

## Acceptance → tests

| Criterion | Proven by |
|---|---|
| D1 Laptop split: `pictureBottom == deckTop == 455.5` for 4:3, 16:9, unknown aspect | `test/duo_split_test.dart: duoSplitFrom laptop: the picture ends at the band top, whatever the aspect` |
| D2 Laptop deck: row inside the band, its × fires there, keyboard top at 495.5 (± 1) | `test/duo_deck_test.dart: laptop: the session row sits in the band, keyboard right below` |
| D3 Fit area: laptop 669x455.5; flat areas unchanged | `test/duo_resolution_test.dart: the laptop fit area ends at the band top and picks 16:9, the rest 4:3` (laptop 455.5, flat-with-band 495.5, flat-without-band 570.6, cover 305.1, non-Duo null) |
| D4 Flat, cover, landscape, non-Duo unchanged | `test/duo_split_test.dart: duoSplitFrom flat: the picture takes its aspect height, capped at 0.6 of the view`; `... no usable band falls back to 0.45 of the view`; `... landscape and non-Duo give none`; `... the latch keeps the cover split`; `test/duo_split_test.dart: a changed peer aspect relayouts the picture` (restored); `test/duo_deck_test.dart: no actions: no session row` (all unedited, green) |
| D5 Focused gate green, analyze no new issue | Gate section |
| D6 On the Duo: picture on the crease, strip above, row in the crease, keyboard right below; soft-keyboard rect hook; delay shown | MISSING: captain's on-device check (manual) |
| D7 Fit picks 1280x720 in the laptop pose, 800x600 in flat and cover | `test/duo_resolution_test.dart: the laptop fit area ends at the band top and picks 16:9, the rest 4:3`; `test/duo_resolution_test.dart: a full-width fit sends the lowest mode at least as wide as the area` |
| D8 Laptop 16:9: picture `Rect(0, 79.19, 669, 376.31)`, strip above, row in band, keyboard 495.5; 4:3: picture 0..455.5, no strip | `test/duo_deck_test.dart: laptop, 16:9: the picture rests on the crease under the strip`; canvas height: `test/duo_split_test.dart: duoCanvasHeight caps the height above the split only` |
| D9 Strip text shows name, delay, time; omits missing ones | `test/duo_status_strip_test.dart: the strip shows name, delay and time, and leaves out what is missing` |
| D10 Report: picks per pose and text size | Report below (no test) |

## Gate

| Command | Result |
|---|---|
| `flutter test` on `duo_split`, `duo_resolution`, `duo_deck`, `duo_status_strip`, `duo_fold`, `duo_keyboard`, `duo_trackpad`, `cursor_size`, `floating_mouse_cursor_offset` tests (from `flutter/`) | exit 0, 68 tests, All tests passed |
| `flutter analyze` on the 5 changed/new lib files and 4 test files | exit 1, 2 infos (`WillPopScope`, `withOpacity` in `remote_page.dart`), same 2 at base d77b12c63; none new |


Captain re-gate after review round 2 (S3-A strip condition), from `flutter/`: the nine-file `flutter test` command above: exit 0, 68 passed; `flutter analyze lib/mobile/duo/duo_deck.dart`: exit 0, no issues.

## D10 report: picks per pose

| Pose | Fit area | Chooser | Pick | Notes |
|---|---|---|---|---|
| Laptop, 669x951, band 455.5-495.5 | 669x455.5 | full width | 1280x720 | picture 669x376.31 at 79.19-455.5, no bars, strip 79.19 pt |
| Flat with band | 669x495.5 | closest | 800x600 | picture 669x501.75; as at base |
| Flat without band | 669x570.6 | closest | 800x600 | as at base |
| Cover, 466x678 | 466x305.1 | closest | 800x600 | 29.6 pt side bars; as at base |

Text size: 1280x720 at full width is 669/1280 = 0.523 pt per Mac pt; 800x600 at 455.5 tall is 0.759. Text in the laptop pose is about 69% as large (0.523 / 0.759).

## Deviations

- Round 1 deleted `a changed peer aspect relayouts the picture` from `duo_split_test.dart` although the plan listed it as not edited; restored verbatim from d77b12c63 in its original position (after `body shorter than the split`), green.
- `gap` in `duo_deck.dart` is `strip == null ? 6.0 : max(0.0, (strip - 32) / 2)` (S3-2 form, `dart:math` imported), not plan decision 2's `clamp` expression; same behavior. Also, per S3-3, the strip applies only when `maxHeight >= 60` (local `strip`); a shorter deck with `rowExtent` set adds a 6 pt leading gap (padding top is 0 whenever `rowExtent` is set) and `top = 6`, so it lays out as at base.
- Wrapping per S3-1: `duo_deck.dart` strip line, `duo_split.dart` laptop `return` (first joined, then re-wrapped by the new `pictureTop` argument), two over-long test names, the joined `expect` in `duo_resolution_test.dart`; also wrapped the new `DuoStatusStrip` constructor and one new `duoCanvasHeight` expect to stay within 80 columns. No other reflow.
- Red-first not executed in either round (sources edited before tests).
- V1 test name differs slightly from the plan (`the laptop fit area ends at the band top and picks 16:9, the rest 4:3`, shortened to fit 80 columns).
- Status-strip test name is written as an adjacent-string concatenation to fit 80 columns.
- `flutter/ios/Runner.xcodeproj/project.pbxproj` and `docs/DUO.md` untouched; `plan.md` and `spec.md` modifications in the worktree are the captain's.

## Known limits

- Auto-fit runs once per session in the pose the deck first shows in: a session that starts flat fits 800x600 and folding to the laptop pose then gives a 4:3 picture with side bars and no strip; one that starts in the laptop pose keeps 1280x720 when opened flat.
- Mouse hover (`remote_input.dart` `onPointerHover`, global position): on the Duo's inner screen (`T = 0`) hover was exact at base; with a laptop-pose strip a hardware mouse's hover maps about 79 pt too low until a button is pressed. New regression on the Duo, rare (hardware mouse on the Duo). Captain ruling 2026-11-22: known limit, since a fix needs shared `remote_input.dart`. Touch and mouse down/move/up are right.
- Virtual mouse (opt-in "show virtual mouse", off by default) with a laptop-pose strip: `floating_mouse.dart` `_getMouseGlobalPosition` and the `_updateBlockedRect` writers (`floating_mouse.dart`, `floating_mouse_widgets.dart`) assume the picture starts at the view's top, so the Mac cursor lands about 79 pt below the handle and the blocked rects are shifted by the same amount. Captain ruling 2026-11-22: known limit (off-by-default feature, fix needs two more shared files). R7's coordinate claim holds for touch and mouse buttons only.
- Deck strip condition is now `maxHeight >= rowExtent + 22` (captain, review S3-A), so a short deck never overflows; below that it lays out without the strip.
- The `_updateRect` hook (soft-keyboard key row rect) has no unit test; D6 covers it.
- The delay source is read from code, not observed; the strip omits it if the session reports none.
- A strip lower than the 32 pt row puts the keyboard at the row's bottom, not the band's (the Duo's band is 40 pt).

## Regression surface

| Existing file / runtime path | What changed | Why |
|---|---|---|
| `duo_split.dart` `duoSplitFrom`, laptop pose | edges at `band.top` (round 1); `pictureTop = band.top - W/a` when the aspect is known and the picture is shorter than the area | R1, R7 |
| `duo_split.dart` `DuoSplit` equality, `DuoSplitBody.build`, `duoCanvasHeight` | `pictureTop` compared; picture child `top`/`height` from `duoPictureOffset` (0 gives base); optional `above` strip; canvas height `W/a` in the laptop pose with a strip; crease `AbsorbPointer` and `kDuoDeckGive` removed (round 1) | R3, R7, R8 |
| `duoFitAreaFrom`, laptop pose | area `W x (band.top - T)` | R4 |
| `duo_resolution.dart` `tryFit` / `schedule` | optional `fullWidth` selects the new chooser; only the laptop pose with a band passes true; `chooseDuoResolution` not edited | R6 |
| `duo_deck.dart` `DuoDeck.build` | optional `rowExtent` strip; null gives base layout | R2 |
| `remote_page.dart` `_duoSplit` | `rowExtent:` and `above:` arguments, one import | R2, R8 |
| `remote_page.dart` `_KeyHelpToolsState._updateRect` | rect y reduced by the picture offset; 0 outside the laptop pose with a strip | keeps the three key-row-rect readers right |
| `QualityMonitorModel` | one more listener while the strip shows; nothing written | R8 |
| Every other pose (flat, cover, unusable band, landscape, non-Duo, desktop, web, Android) | none | R5, R9 |

Cleanup: untracked gitignored copies `flutter/lib/generated_bridge.dart` and `flutter/lib/generated_bridge.freezed.dart` remain in the worktree; scratch `/private/tmp/gate.txt` and `/private/tmp/x.dart` outside the repo.
