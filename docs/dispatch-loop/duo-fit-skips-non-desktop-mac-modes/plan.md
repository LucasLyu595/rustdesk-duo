---
name: duo-fit-skips-non-desktop-mac-modes-plan
description: "Plan for making Duo auto-fit drop Mac display modes under 540 pt tall, and for giving the flat pose the laptop layout or a 60 pt top strip with a full-width fit."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-fit-skips-non-desktop-mac-modes
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 41af5e2b-05b0-47c6-837a-53ef33c5a4f0
  at: 2026-11-22T01:02:15-08:00
---

# Plan: auto-fit skips Mac modes macOS cannot set

Sections up to "Known limit" cover R1-R2 / D1-D4. "Revision 1" at the end covers R3-R5 / D5-D7 and
wins where the two differ (files touched, the flat rows, the edited existing tests).

Spec: `docs/dispatch-loop/duo-fit-skips-non-desktop-mac-modes/spec.md`. Base `duo-mode` at `8a1623174`.
AGENTS.md at the worktree root is binding (Editing Hygiene, Tests, regression-surface check).

## Files touched

| File | Change |
| --- | --- |
| `flutter/lib/mobile/duo/duo_resolution.dart` | one new constant, a few added lines in `tryFit`, one existing call expression gets a different first argument |
| `flutter/test/duo_resolution_test.dart` | one new list, one new test; no existing test edited |

Nothing else: no host, Rust, shared Dart, or lang file.

## Change in `duo_resolution.dart`

1. Next to `kDuoAspectTolerance`, add a top-level constant with a doc comment that gives the reason (macOS
   lists modes under this height but refuses to set them as the desktop mode):

   ```dart
   const int kDuoMinMacModeHeight = 540;
   ```

2. In `DuoResolutionFit.tryFit`, after the existing guard block (lines 62-69, left untouched, so
   `modes.length <= 1` still tests the peer's full list) and before the chooser call, build the filtered list
   with the fallback:

   ```dart
   final usable =
       modes.where((m) => m.height >= kDuoMinMacModeHeight).toList();
   ```

   and pass `usable.isEmpty ? modes : usable` to the chooser instead of `modes` (the one modified existing
   line, line 72). Everything after it (`_done`, the same-size check, `send`) is unchanged.

3. `chooseDuoResolution`, `chooseDuoResolutionFullWidth` and `schedule` are not edited. No new state, no new
   import. The filter needs no platform test of its own: `tryFit` already returns for non-macOS peers.

Not done on purpose: a filtered list of exactly one mode is still chosen (the guard is about the peer
offering a choice at all, and one settable mode beats a refused one); no filter by aspect or width.

## Tests (`flutter/test/duo_resolution_test.dart`)

Add a top-level list `m6` beside `k4k`: the six refused sizes from the spec (512x384, 640x360, 640x480,
672x378, 672x504, 800x450), the 16:9 sizes 960x540, 1024x576, 1152x648, 1280x720, 1600x900, 1920x1080,
2560x1440, 3008x1692, 3360x1890, 3840x2160, and the 4:3 sizes 800x600, 1024x768.

One new test, "modes macOS lists but cannot set are skipped", with a fresh `DuoResolutionFit` per call
(direct `tryFit` calls, as the existing full-width test does; the `run` helper has no `fullWidth`):

| Call | area | fullWidth | Expected send | Base sends |
| --- | --- | --- | --- | --- |
| laptop | 669 x 455.5 | true | 960x540 | 640x360 |
| cover | 466 x 305.1 | false | 800x600 | 512x384 |
| fallback | 669 x 455.5 | true, modes = 640x360 and 800x450 only | 640x360 | 640x360 |

The fallback row pins R1's "no mode left: choose from the full list"; it passes on base and stays in the same
test. The first two rows fail on base. The flat rows moved to Revision 1 (D6), where the area comes from
`duoFitAreaFrom`.

Fails-on-base check: derived by hand from the chooser (lowest width among the closest aspect), not run,
because the plan stage may not write a test file and the worktree lacks the gitignored bridge files. The
implementer writes the test first and records the red run before touching `duo_resolution.dart`.

Note for the captain: the spec's D1 says base sends 800x450 for the laptop case. With the spec's full M6
list, base picks 640x360 (it is 16:9 and narrower than 800x450); the 800x450 seen on the device implies
the client's list then held no narrower 16:9 mode. The test is red on base either way and asserts only the
fixed picks, so this does not change the design.

Existing tests: none change. `k4k` has no mode under 540 pt tall, so every current pick is the same; the
single-mode case in "unmet conditions" is stopped by the untouched `modes.length <= 1` guard. The tests of
the two chooser functions call them directly and are unaffected.

Test diff is about the size of the fix plus the list literal; no new infrastructure.

## Gate

Setup (once, in the worktree): copy the gitignored `generated_bridge.dart` and
`generated_bridge.freezed.dart` from `/Users/lucas/rustdesk-duo/flutter/lib/` into the worktree's
`flutter/lib/`, then from `flutter/` run `~/development/flutter/bin/flutter pub get`. Neither copy is
committed (both gitignored; stage explicit paths only).

Focused and closing gate, from `flutter/`:

```
~/development/flutter/bin/flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart test/duo_status_strip_test.dart test/cursor_size_test.dart test/floating_mouse_cursor_offset_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_resolution.dart test/duo_resolution_test.dart
```

Pass: all tests green; analyze reports no issue that base does not report for the same two files (run
analyze once before editing to record the base output).

## Acceptance -> tests

| Item | Covered by |
| --- | --- |
| D1 | new test, rows laptop (960x540, `fullWidth: true`) and flat/cover (800x600); red on base, green after |
| D2 | the eight existing tests in `duo_resolution_test.dart`, unedited, green in the gate |
| D3 | the two gate commands above |
| D4 | captain, on the Duo; outside the implementer's gate |

R1's fallback is covered by the fallback row; R1's "choosers keep their behavior" by the unedited chooser
tests.

## Regression surface

- Existing file changed: `flutter/lib/mobile/duo/duo_resolution.dart`. Existing runtime path changed:
  `DuoResolutionFit.tryFit` only, reached only from `schedule` on a Duo deck with a macOS peer, keyboard
  permission, not view-only. Unavoidable: this is where the spec puts the filter (R1), so the two choosers
  stay as they are for direct callers.
- Behavior change: a Mac peer whose list has a mode under 540 pt tall may now get a larger mode than before
  (the lowest one 540 pt or taller of the chosen aspect). A list with no such mode, or only such modes,
  behaves exactly as on base.
- Unchanged: guards, the once-per-session latch, the same-size skip, `schedule`, non-Duo and non-macOS
  sessions, the host.

## Known limit

540 is taken from one display (the M6's MPG321UX). A Mac that refuses a mode 540 pt or taller still fails
as on base (request refused, mode stays); a Mac that could set a lower mode is no longer offered it.

## Revision 1: status strip in the flat pose (R3-R5, D5-D7)

Adds `flutter/lib/mobile/duo/duo_split.dart` and `flutter/test/duo_split_test.dart` to the owned files,
plus one line of `schedule` in `duo_resolution.dart`. Not touched: `remote_page.dart`, `model.dart`,
`duo_deck.dart`, `duo_status_strip.dart`, `duo_deck_test.dart`.

### Change in `duo_split.dart`

1. New constant beside `kDuoFlatPictureFraction`, with a doc comment naming the reason (the inner screen's
   rounded top corners): `const double kDuoTopClear = 60;`

2. `duoSplitFrom`, flat with a band (R3). The laptop branch's condition (line 77) changes from
   `band != null && laptop` to `band != null && geometry?.screen == DuoScreen.inner`. `laptop` already
   implies the inner screen, so the laptop pose is untouched and the branch body is not edited. This holds
   with and without a known aspect: the callers that read `rowBand` (`schedule`, the deck's `rowExtent` in
   `remote_page.dart`) ask for the split without an aspect, so the row band must not depend on it.

3. `duoSplitFrom`, flat without a band (R4). The existing flat branch (lines 86-89, now reached only with
   no usable band) becomes:

   ```dart
   final top = paddingTop + kDuoTopClear;
   final y = min(top + viewSize.width / aspect, kDuoFlatPictureFraction * viewSize.height);
   return DuoSplit(pictureBottom: y, deckTop: y, pictureTop: top);
   ```

   Picture height is `y - top = min(W / a, 0.6 H - T - 60)`, as R4 states. Aspect unknown keeps the base
   0.45 H fallback with no strip (there is no picture to protect yet, and it keeps the existing
   fold-switch and fallback tests as they are).

4. `duoFitAreaFrom`. The inner block (lines 111-120) loses its band branch and keeps one case: inner, no
   usable band, not laptop -> `Size(W, 0.6 H - paddingTop - kDuoTopClear)`. Flat with a band then falls to
   the last line, `split.pictureBottom - paddingTop` = `band.top - T`, the laptop's area.

5. New pure function beside it, and its `current...` twin in the style of `currentDuoFitArea`:

   ```dart
   bool duoFitFullWidthFrom(DuoGeometry? geometry, Size viewSize, {required bool isDuo})
   bool currentDuoFitFullWidth(Size viewSize)
   ```

   True when the aspect-less split has a `rowBand` (laptop, flat with band) or the pose is the one of
   step 4 (flat without band); false for cover, the 0.45 fallbacks and no split. Share the step-4 condition
   through one private helper so area and chooser cannot disagree.

6. Doc comments on `DuoSplit.rowBand`, `DuoSplit.pictureTop`, `kDuoStripMinExtent` and `DuoSplitBody.above`
   say "laptop pose" / "rests on the crease"; reword the ones that become false. `DuoSplitBody.build`,
   `duoPictureOffset` and `duoCanvasHeight` are not edited.

### Change in `duo_resolution.dart` (in addition to R1)

`schedule` line 98: `fullWidth: currentDuoFitFullWidth(media.size)`. Decision: the condition keys on the
pose (step 5), not on `rowBand != null`, because flat without a band has no row band but must use the
full-width chooser (R4), and not on "inner screen", because that would also switch the unusable-band
fallback to full width, which no requirement asks for.

### Trace (no code change needed in the body or the canvas)

`DuoSplitBody.build` takes `top = duoPictureOffset(split, T) = max(0, pictureTop - T)`, puts the child at
`top` with height `pictureBottom - top`, and shows `above` at `T` with height `top` when
`top >= kDuoStripMinExtent`. Nothing in it tests the pose.

| Pose | pictureTop | top | `above` shown | child box | `duoCanvasHeight` (large `h`) |
| --- | --- | --- | --- | --- | --- |
| flat with band, 16:9 | band.top - W/a | 79.2 - T | yes when >= 24 | to band.top | `band.top - pictureTop` = W/a |
| flat with band, 4:3 (W/a + T >= band.top) | 0 | 0 | no | T-inset to band.top, as laptop | band.top - T |
| flat without band | T + 60 | 60 | yes, always (60 >= 24) | 60 to `y` | `y - (T + 60)` = min(W/a, 0.6 H - T - 60) |

`duoCanvasHeight` returns `pictureBottom - max(pictureTop, T)`, which is the picture height R3/R4 give in
each row, so canvas and layout agree; `_updateRect` in `remote_page.dart` uses the same
`duoPictureOffset`. Laptop and flat-with-band splits are now equal, so moving between them fires no
`onFoldChanged`; none is needed, the layout is identical. With the fit landed in flat with band the peer is
16:9 and the strip shows; while the peer is still 4:3 or taller the picture fills to the top with no strip,
exactly as the laptop pose does today (R5: same rules).

### Heights and picks per pose (D7; view 669x951, T = 0, band 455.5-495.5, cover view 466x678, M6 list)

| Pose | Fit area | Chooser | Pick | Strip | Picture (after the fit) | Deck |
| --- | --- | --- | --- | --- | --- | --- |
| laptop | 669 x 455.5 | full width | 960x540 | 0 - 79.2 | 669 x 376.3, 79.2 - 455.5 | row in band 455.5 - 495.5, keyboard from 495.5 |
| flat with band | 669 x 455.5 | full width | 960x540 | 0 - 79.2 | 669 x 376.3, 79.2 - 455.5 | row in band 455.5 - 495.5, keyboard from 495.5 |
| flat without band | 669 x 510.6 | full width | 800x600 | 0 - 60 | 669 x 501.75, 60 - 561.75 | from 561.75 (389.25 tall), row first |
| cover | 466 x 305.1 | closest aspect | 800x600 | none | area 466 x 305.1 from the top | from 305.1 |

Flat without band, area aspect 1.310: 4:3 is 0.017 away in log aspect and 16:9 0.305, so only 4:3
qualifies. The existing deck tests cover deck heights 250-455 without overflow, which includes 389.25.

### Tests

`flutter/test/duo_split_test.dart`:

- Replace "flat: the picture takes its aspect height, capped at 0.6 of the view" (it encodes the superseded
  base rule) with "flat with a band is the laptop split; without one the picture starts 60 pt down":
  `duoSplitFrom(openBand, ...)` equals `duoSplitFrom(_geo(), ...)` for aspect 4/3, 16/9 and null (D5);
  `_flat()` at 4/3 gives `pictureTop` 60, `pictureBottom` and `deckTop` 561.75; at 1.0 gives 570.6 (the
  0.6 cap); `_flat()` with no aspect still gives 427.95.
- New widget test "flat without a band: strip, picture and deck stack from the top" (D5): `_flat()`, aspect
  4/3, keyed `above`, `below` and child; child rect `Rect.fromLTWH(0, 60, 669, 501.75)`, `above` from 0 to
  60, `below` top 561.75.
- In "duoCanvasHeight caps the height above the split only", add one expectation after a `_flat()` update:
  `duoCanvasHeight(900, 0, view, aspect: 4 / 3)` is 501.75.
- Unchanged and still green: the five other widget tests ("a changed peer aspect relayouts the picture"
  keeps its 427.95 / 501.75 / 376.31 heights, since the child is 60 lower and ends 60 lower), "no usable
  band", "landscape and non-Duo", the latch test.

`flutter/test/duo_resolution_test.dart`:

- Edit "the laptop fit area ends at the band top and picks 16:9, the rest 4:3": the `open` posture with
  the band now expects area height 455.5 and the full-width pick 1280x720 like `book` (R3 supersedes
  495.5 / 800x600); the flat area height becomes 510.6 (R4 supersedes 570.6), pick from `k4k` stays
  800x600. Cover and non-Duo lines unchanged.
- The new R1 test gains the D6 rows, each driven from geometry through `duoFitAreaFrom` and
  `duoFitFullWidthFrom` into `tryFit` with `m6`: flat with band -> sends 960x540; flat without band ->
  sends 800x600; and `duoFitFullWidthFrom` is false for the cover.

Red on base (by reading, to be recorded by the implementer before the fix): the D5 equality (base gives
`pictureBottom` 501.75 or `deckTop` 495.5, no `rowBand`), the D5 widget rect (base child starts at 0), and
D6 (base has no `duoFitFullWidthFrom`; with base's areas and chooser it would send 512x384).

`duo_deck_test.dart` needs no change: its cases are laptop, no fold and fixed deck heights.

### Gate, acceptance, regression surface (additions)

Gate commands are unchanged; analyze adds the two split files:
`~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_resolution.dart lib/mobile/duo/duo_split.dart test/duo_resolution_test.dart test/duo_split_test.dart`.

| Item | Covered by |
| --- | --- |
| D5 | the replaced `duoSplitFrom` flat test and the new widget test in `duo_split_test.dart` |
| D6 | the D6 rows of the new test in `duo_resolution_test.dart`, plus the edited fit-area test |
| D7 | the table above; the implementer repeats it in results.md with the values the tests assert |
| R5 | no strip code changes; the widget test shows `above` in the flat pose, `duo_status_strip_test.dart` stays in the gate |

Regression surface added by the revision:

- `duoSplitFrom`: inner screen, not laptop (flat) only. With a band it now returns the laptop split; without
  a band and with a known aspect the picture starts 60 pt lower. Laptop, cover, outer or unknown screen,
  aspect-unknown flat without band, landscape and non-Duo return what base returns.
- `duoFitAreaFrom`: flat only (band.top instead of band.bottom; 60 pt less without a band).
- `schedule`: `fullWidth` is now also true for flat without a band; for every other pose it has the value
  base computes from the new split.
- Through those, without edits: `DuoSplitBody` shows `above` in flat poses, the deck row sits in the band in
  flat with band (`rowExtent` in `remote_page.dart`), `duoCanvasHeight` and `_updateRect` follow the
  new `pictureTop`.

Known limits added: the picks in the table assume T = 0, as the spec's figures do; with a top inset
above 8.85 pt (510.6 - T under 501.75) the flat-without-band area turns wider than 4:3 and the full-width chooser picks
960x540 there (still a settable mode; the captain's on-device check D4 shows which applies). Flat without
a band and without a known aspect has no strip until the aspect arrives.
