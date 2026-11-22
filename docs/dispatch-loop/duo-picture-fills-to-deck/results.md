---
name: duo-picture-fills-to-deck-results
description: "Results of the Duo picture-fills-to-deck unit: aspect-aware split, crease strip that takes no touches, live aspect relayout, aspect-free auto-fit area; gate green."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-picture-fills-to-deck
  modified: 2026-11-21
generated:
  by: claude/sonnet
  session: a099aa2f489aef397
  at: 2026-11-21T23:51:23-08:00
---

# Results: the Duo picture fills its width down to the deck

Tasks 1 and 2 of the plan, one implementer. The captain committed the candidate.

Candidate commit: a2e61f5fb (unit/duo-picture-fills-to-deck, base 257b4d56a; committed by the captain from the implementer's worktree diff)

## Gate

Run from the worktree's `flutter/`.

| Command | Exit | Result |
|---|---|---|
| `~/development/flutter/bin/flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart` | exit 0 | All tests passed, 55 (split 13, resolution 8, deck 13, fold 5, keyboard 9, trackpad 7) |
| `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_split.dart lib/mobile/duo/duo_resolution.dart lib/mobile/pages/remote_page.dart lib/models/model.dart test/duo_split_test.dart test/duo_resolution_test.dart` | exit 1 (info-level issues only) | 16 issues, all `info`, none in the Duo files or tests. Base (main checkout, same command) also reports 16; the lists are identical once line numbers are stripped. No new issue. |

Captain re-gate after the review nits (format hunks restored), from `flutter/`, widened to the two other tests that touch `CanvasModel`: `~/development/flutter/bin/flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart test/cursor_size_test.dart test/floating_mouse_cursor_offset_test.dart`: exit 0, 66 passed.

Red-first: not executed. N1-N3 and N5 cannot compile against the base (new `aspect`/`aspectChanged` parameters, `duoFitAreaFrom`), which is the failure the plan names; no failing run was recorded.

## Acceptance → tests

| Criterion | Proven by |
|---|---|
| D1 laptop: 4:3 at 669 gives 501.75 for both edges; 16:9 or unknown gives `band.bottom` | `test/duo_split_test.dart: duoSplitFrom laptop: the picture runs to the band, or to full width within the deck give` (also 1.3, beyond the give, stays 495.5) |
| D2 a tap in the band does not reach the picture; a tap just above does | `test/duo_split_test.dart: laptop: a touch in the crease band does not reach the picture` (also checks flat adds no block) |
| D3 flat: 4:3 gives 501.75 for both edges; unknown aspect keeps today's split | `test/duo_split_test.dart: duoSplitFrom flat: the picture takes its aspect height, capped at 0.6 of the view` |
| D4 cover, landscape, non-Duo unchanged | `test/duo_split_test.dart: duoSplitFrom no usable band falls back to 0.45 of the view`; `duoSplitFrom landscape and non-Duo give none`; `the latch keeps the cover split`; `no fold: child fills the body, no placeholder`; `duoCanvasHeight caps the height above the split only` (cover and landscape lines); `test/duo_deck_test.dart: no fold: no deck`; all run and green. The four old laptop values were updated as the plan lists. |
| D5 fit area: laptop and flat-with-band 669x495.5, flat without band 669x570.6, lowest 4:3 pick, cover keeps today's area | `test/duo_resolution_test.dart: the fit area follows the band on the inner screen and picks 4:3` |
| D6 focused gate green; analyze no new issue | Gate section above |
| D7 on the Duo | manual, captain's on-device check after merge and reinstall; not proven here |
| R5 live aspect relayout (no D-number) | `test/duo_split_test.dart: a changed peer aspect relayouts the picture`. The two shared-file hooks (`model.dart` call, `remote_page.dart` arguments) and `DuoResolutionFit.schedule` have no test, by plan; covered by inspection and D7. |

## Auto-fit picks

Mode list: 16:9 modes 3840x2160 down to 1280x720, plus 1024x768 and 800x600; `T = 0`. Confirmed by `the fit area follows the band on the inner screen and picks 4:3` (laptop, flat with band, flat without band, cover rows; the 16:9 and 4:3 distances are the plan's arithmetic).

| Pose | Fit area | Area aspect | Distance 4:3 | Distance 16:9 | Pick | Split after the pick | Notes |
|---|---|---|---|---|---|---|---|
| Laptop, 669x951, band 455.5-495.5 | 669x495.5 | 1.350 | 0.013 | 0.275 | 800x600 | 501.75 for both edges | deck gives 6.25 pt; picture exactly 669x501.75, no bars |
| Flat with band, 669x951 | 669x495.5 | 1.350 | 0.013 | 0.275 | 800x600 | 501.75 for both edges | picture exactly 669x501.75 |
| Flat without band, 669x951 | 669x570.6 | 1.172 | 0.129 | 0.416 | 800x600 | 501.75 for both edges | captain amendment, spec R6 |
| Cover, 466x678 | 466x305.1 | 1.527 | 0.136 | 0.152 | 800x600 | 305.1 (unchanged rule) | 29.6 pt bars each side, as today |

## Build-phase notify check

Question: does anything call `CanvasModel.notifyListeners()` during build/layout, which would make `_onAspect`'s `setState` throw?

- `updateViewStyle` (the path that carries a display-shape change) starts with `await bind.sessionGetViewStyle(...)` and only then reaches `notifyListeners()` (`model.dart` ~2444). It therefore always notifies from a microtask after the async gap, never synchronously inside the caller. Its callers (`updateCurDisplay` ~803, first-image ~4339, `custom_scale_base.dart:117`, `toolbar.dart:811`, `remote_page.dart:572` timer, `:599` post-frame, `view_camera_page.dart:260`) are event, timer, post-frame or async handlers; none is inside `build` or layout.
- The other `CanvasModel` notifiers (`panX/panY`, `updateScale`, `resetOffset`, `update`, `reset`) are called from gesture handlers (`remote_input.dart` ~491), the floating mouse, FFI event handlers and `switchToNewDisplay`; none from `build`.
- `OrientationBuilder` in `remote_page.dart` (~567) defers its `updateViewStyle` through a 200 ms `Timer`, so it does not notify in the build either.

Conclusion: no build-phase path exists, so no phase guard was added; `_onAspect` keeps the plain `setState`. If one is ever added, a `SchedulerBinding.instance.schedulerPhase == persistentCallbacks` skip is the smallest fix; not needed now.

## Regression surface

| Existing file / runtime path | What changed | Why unavoidable |
|---|---|---|
| `duo_split.dart` `duoSplitFrom`, Duo, portrait, laptop pose with usable band | picture bottom moves from `band.top` to `band.bottom` (or up to 12 pt lower, `kDuoDeckGive`); deck top equals it; the split carries the band as `crease` | R1, R2 |
| same, inner screen, not laptop, aspect known | picture bottom `min(T + W/a, 0.6 H)`; deck starts there | R3 |
| same, every other case (aspect unknown outside laptop, cover, unusable band) | unchanged (band rule, then 0.45) | R3, R4 |
| non-Duo and landscape | unchanged: null returned on the first line | R4 |
| `DuoSplit` equality | now includes `crease`; `onFoldChanged` also fires on laptop <-> flat when the edges coincide | R2: the strip must appear and disappear with the pose |
| `DuoSplitBody` | laptop pose adds an invisible `AbsorbPointer` over the band; listens to `aspectChanged`; reads `padding.top`; without a split behaves as before (extra listener computes null == null) | R2, R5 |
| `CanvasModel.getSize()` (`model.dart`) | one call gets an `aspect:` argument (`duoPeerAspect(...)`, a pure read); result used only when a Duo split exists | R5: canvas and layout must use the same split |
| `_RemotePageState._duoSplit` (`remote_page.dart`) | two added argument lines; nothing else | R5 |
| `DuoResolutionFit.schedule` | fit area from `currentDuoFitArea`: inner screen with band `W x (band.bottom - T)`, inner without band `W x (0.6 H - T)`, elsewhere as before | R6 |
| `DuoSplit`, `duoCanvasHeight`, `currentDuoSplit` signatures | new optional named parameters only; existing callers (`_duoDeckActive`, tests) unchanged | R5 |

## Deviations

- Red-first run not executed (plan Gate step): N1-N5 use `aspect:`, `aspectChanged:` and `duoFitAreaFrom`, which do not exist at base, so they cannot compile there. Accepted by the captain as the red evidence.
- `dart format` reflowed two unrelated test lines (`duo_resolution_test.dart` `modes([[800, 600]])`, `duo_split_test.dart` `closeTo(255.1, 0.01)`); the captain restored both to the base text at review.

## Known limits

- Laptop pose: the crease block sits above the whole picture child, so an overlay drawn inside the band (the opt-in virtual mouse buttons when their saved position falls in the band, or a physical mouse hovering there) takes no input until the pose changes. R2 asks for this block; a narrower one needs new state, so per AGENTS.md it stays a known limit.

Cleanup: copied untracked (gitignored) `flutter/lib/generated_bridge.dart` and `flutter/lib/generated_bridge.freezed.dart` from the main checkout into the worktree; `flutter pub get` changed no tracked file. `project.pbxproj` untouched. Remove the two copied files before any cleanup of the worktree if desired.
