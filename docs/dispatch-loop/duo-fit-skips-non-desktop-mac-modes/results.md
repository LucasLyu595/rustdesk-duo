---
name: duo-fit-skips-non-desktop-mac-modes-results
description: "Results of the Duo auto-fit unit: modes under 540 pt tall are skipped, and the flat pose gets the laptop layout (with a band) or a 60 pt top strip (without) with a full-width fit."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-fit-skips-non-desktop-mac-modes
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: a65745e637f152afe
  at: 2026-11-22T01:05:00-08:00
---

# Results: auto-fit skips Mac modes macOS cannot set (R1-R5)

Candidate commit: ee3ddd683 (unit/duo-fit-skips-non-desktop-mac-modes, base 8a1623174; committed by the captain from the implementer's worktree diff)

Ran as claude-sonnet-5-5.

## Gate

All from `flutter/` in the worktree.

| Run | Command | Result |
| --- | --- | --- |
| Red-first, on base lib code, new D1 test only added | `flutter test test/duo_resolution_test.dart` | failed: `+9 -1`, "modes macOS lists but cannot set are skipped" (laptop row expected 960x540, actual 640x360). Exit status not captured (output was piped to `tail`); the run ended "Some tests failed." |
| Focused gate | `flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart test/duo_status_strip_test.dart test/cursor_size_test.dart test/floating_mouse_cursor_offset_test.dart` | exit 0, `+70: All tests passed!` |
| Analyze | `flutter analyze lib/mobile/duo/duo_resolution.dart lib/mobile/duo/duo_split.dart test/duo_resolution_test.dart test/duo_split_test.dart` | exit 0, "No issues found!" (also clean after adding the D1 test on base lib code) |


Captain re-gate after the review nits, from `flutter/`: the nine-file `flutter test` command: exit 0, 70 passed; `flutter analyze` on the four changed files: exit 0, no issues.

## Acceptance → tests

| Criterion | Proven by |
| --- | --- |
| D1 `tryFit` with an M6-like list sends 960x540 (`fullWidth: true`) and 800x600 (without); fails on base | `test/duo_resolution_test.dart: modes macOS lists but cannot set are skipped` (rows laptop, cover, fallback); red on base, green after |
| D2 existing Duo resolution tests pass unless they encode a sub-540 pick | the eight other tests in `test/duo_resolution_test.dart` (unedited except `the fit area ends at the band top; the flat one without a band is shorter`, which R3/R4 supersede), green in the focused gate |
| D3 focused gate and analyze, no new issue | Gate section above (exit 0, `+70`; analyze clean) |
| D4 on the Duo, laptop pose switches the M6 to 960x540, text readable | MISSING from the tests: the captain's on-device check (manual) |
| D5 flat with band equals the laptop split; flat without band, 4:3, picture `Rect(0, 60, 669, 501.75)`, strip above, deck from 561.75 | `test/duo_split_test.dart: duoSplitFrom flat with a band is the laptop split; without one the picture starts 60 pt down`; `test/duo_split_test.dart: flat without a band: strip, picture and deck stack from the top`; `test/duo_split_test.dart: duoCanvasHeight caps the height above the split only` (501.75 flat expectation) |
| D6 flat with band picks 960x540, flat without band 800x600 from the M6-like list | `test/duo_resolution_test.dart: modes macOS lists but cannot set are skipped` (flat-with-band and flat-without-band rows driven through `duoFitAreaFrom` and `duoFitFullWidthFrom`; cover `duoFitFullWidthFrom` false); `test/duo_resolution_test.dart: the fit area ends at the band top; the flat one without a band is shorter` (areas 455.5 and 510.6) |
| D7 report heights and picks per pose | report, no test: table below (derived from the plan's arithmetic and the asserted values above; T = 0, view 669x951, cover view 466x678, M6 list) |

D7 per-pose table.

| Pose | Fit area | Chooser | Pick | Strip | Picture (after the fit) | Deck |
| --- | --- | --- | --- | --- | --- | --- |
| laptop | 669 x 455.5 | full width | 960x540 | 0 - 79.2 | 669 x 376.3, 79.2 - 455.5 | row in band 455.5 - 495.5, keyboard from 495.5 |
| flat with band | 669 x 455.5 | full width | 960x540 | 0 - 79.2 | 669 x 376.3, 79.2 - 455.5 | row in band 455.5 - 495.5, keyboard from 495.5 |
| flat without band | 669 x 510.6 | full width | 800x600 | 0 - 60 | 669 x 501.75, 60 - 561.75 | from 561.75 |
| cover | 466 x 305.1 | closest aspect | 800x600 | none | 466 x 305.1 from the top | from 305.1 |

The area, pick (laptop, flat with band, flat without band, cover) and 60 / 501.75 / 561.75 figures are asserted by the tests above; the strip height and 376.3 picture are arithmetic (W / (16/9)), not separately asserted.

## Captain review fixes

- Review (Fable, approve-with-nits): reworded the `DuoSplit.pictureTop` and `DuoSplitBody.above` doc comments (nit 1); added `expect(duoFitFullWidthFrom(flat, view, isDuo: true), isTrue)` to pin R4's full-width decision (nit 2); test size accepted (nit 3: mostly the 21-line M6 mode list, each test maps to a Done-when). Re-gate below.

## Deviations

None from the plan. Notes: `duoSplitFrom` uses `aspect!` inside the flat branch (guarded by `full != null`, which implies a non-null aspect). The red-first run's exit status was not captured.

## Known limits

- 540 is taken from one display (the M6's MPG321UX); a Mac refusing a 540 pt or taller mode still fails as on base.
- Picks assume T = 0; with a top inset above about 8.85 pt the flat-without-band area is wider than 4:3 and the full-width chooser picks 960x540 (still settable).
- Flat without a band and without a known aspect has no strip until the aspect arrives.

## Regression surface

| Existing file / path | Change | Why unavoidable |
| --- | --- | --- |
| `flutter/lib/mobile/duo/duo_resolution.dart`: `DuoResolutionFit.tryFit` | filters modes under 540 pt tall, falling back to the full list | R1 puts the filter here so the choosers keep their behavior |
| same file: `schedule` | `fullWidth` now `currentDuoFitFullWidth(media.size)` | flat without a band needs the full-width chooser (R4) |
| `flutter/lib/mobile/duo/duo_split.dart`: `duoSplitFrom` | band branch keys on inner screen (flat with band is the laptop split); flat without band starts 60 pt down | R3, R4 |
| same file: `duoFitAreaFrom` | flat area is band.top based with a band, 60 pt shorter without | R3, R4 |
| same file: doc comments | reworded where "laptop pose" became false | accuracy |
| Unchanged by edit, changed by behavior | `DuoSplitBody` shows `above` in flat poses; deck row sits in the band in flat with band; `duoCanvasHeight` follows the new `pictureTop` | consequence of the split change (R5) |

Laptop, cover, outer or unknown screen, aspect-unknown flat without a band, landscape and non-Duo return what base returns.

Cleanup: copied untracked gitignored `flutter/lib/generated_bridge.dart` and `flutter/lib/generated_bridge.freezed.dart` into the worktree (not to be committed); `flutter pub get` touched only ignored files.
