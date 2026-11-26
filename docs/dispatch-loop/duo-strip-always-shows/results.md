---
name: duo-strip-always-shows-results
description: "The Duo's top strip now always shows in the crease layout: the strip height is reserved above the picture, the crease is held through reports without it, the resume re-reads the plugin's latest report, and each layout-branch change is logged."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-strip-always-shows
  modified: 2026-11-26
generated:
  by: claude/sonnet
  session: a6d5081f2c373dff2
  at: 2026-11-26T03:03:40-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-26T03:04:58-08:00
---

# Results: the strip always shows

Candidate commit: 868495023 (unit/duo-strip-always-shows, base c916f9854; captain commit of the implementer's working tree; results doc committed after)

Ran as claude-sonnet-5-5. Captain rulings applied: F1 = the planned resume hook only; F2 = fit area is the box below the strip; last crease kept per view size.

## Acceptance → tests

| Done-when | Proven by |
| --- | --- |
| D1. Plan lists I1/I2 with evidence | `plan.md` table (rows 1-8, file:line evidence) |
| D2. R1-R4 pinned by tests | R1: `4:3: the strip shows...`, `a top padding of 60...`, updated crease expectations in `duo_split_test.dart` and `duo_deck_test.dart`. R2: `a report without the crease leaves the layout unchanged`, `rotation to landscape and back keeps the strip`, `the held crease stays with its view size`, fit area in `duo_resolution_test.dart`. R3 and resume hook: no Dart test (needs a native host; device step 4). R4: `a branch change prints one line` |
| D3. Focused gate green | Gate section below |
| D4. On the Duo | MISSING: Lucas's device steps (manual) |

## Gate

| Command | Exit status | Result |
| --- | --- | --- |
| `flutter test test/duo_*_test.dart` (from `flutter/`) | exit 0 | 78 passed, 0 failed (rerun after review round 1) |
| `flutter analyze` on `duo_fold.dart`, `duo_split.dart`, `remote_page.dart`, `duo_split_test.dart` | exit 1 (infos only) | 2 issues, both the baseline `remote_page.dart` infos (`WillPopScope` 508, `withOpacity` 1408); none new |
| `flutter pub get` | exit 0 | no tracked file changed (`git status`: only the 6 owned files) |

Red-first: with the lib changes in and the tests not yet updated, the run was 66 passed, 6 failed: the six tests that encode the old "no strip" values (fold set child above the fold, switching the fold relayouts, body shorter than the split, duoCanvasHeight caps, deck laptop 16:9, fit area ends at the band top). Then tests were updated and the new ones added.

## Deviations

- The `held` pass-through in `duoFitAreaFrom` also passes `paddingTop` to `duoSplitFrom` (the plan's two-line change showed only `held`; without it the area ignores padding in the crease branch).
- `duo_resolution_test.dart` gained an import of `duo_fold.dart` for the glitch assertions.
- The plan's seven tests: the "fit area during a glitch" assertions were added to the existing fit-area test; the rest are new tests in a `the strip always shows` group.
- Review round 1: the rotation test now reports an inner landscape band (`455.5,0,40x669`) and asserts the strip and `below.top == 455.5` before `_geo()` is re-sent, then again after. The held-crease test asserts `heldBand(cover)` is null while `_geo()` is reported (pins the width check). Confirmed red with the fix reverted: with `held:` dropped from the `current*` wrappers 4 tests fail (rotation, held crease, glitch layout, switching the fold); with the width check removed the held-crease test fails.
- The branch-log test restores `debugPrint` in a `finally`: `addTearDown` runs after the framework's debug-variable check, which then fails the test.
- `refresh()` doc reworded: it re-reads the plugin's latest report, which is re-emitted only if it differs (not a fresh native read).
- Held-crease test calls `currentDuoSplit(portrait)` first to hold the band, as the hold happens on read.

Cleanup: none (`dart format` reflow of unrelated lines was reverted; no files outside the owned set touched)

## Known limitations

- A shown status bar still costs 60 pt of picture height while up; rows 3b/3c stay until the next keyboard hide or resume.
- A Mac with only 4:3 or 16:10 modes keeps side bars in the crease layout.
- The held crease lives for the app run, keyed by view size only.
- The resume hook has no Dart test; the root cause 2 is inferred, not seen on the device.

## Regression surface

| Existing path | Change |
| --- | --- |
| `duoSplitFrom` crease branch | `pictureTop` at least `paddingTop + 56`; a held crease counts as the crease |
| `duoFitAreaFrom` | crease area 56 pt lower; flat case skipped when a crease is held |
| `duoFitFullWidthFrom`, `currentDuoSplit`, `currentDuoFitArea`, `currentDuoFitFullWidth` | pass the held crease |
| `_DuoSplitBodyState.build` | one `_log` call |
| `DuoFold` | two fields, three methods, `reset()` clears them |
| `_RemotePageState.didChangeAppLifecycleState` | one added call (`_duoResumed`), early return for non-Duo |

## Device steps

Install with `bash duo/install-ios.sh`, open Console on the Mac, pick the Duo and filter on `DuoSplit`. Connect to the M6 with the Duo half folded, upright. After each step the strip (status line and eight buttons) should be there; note any step where it is not, with the log lines.

1. Connect on the cover screen, open to the inner screen, wait two seconds.
2. Rotate to landscape and back, then turn the Duo upside down and back.
3. Open flat, fold to the laptop pose, repeat three times at different speeds.
4. Go to the home screen for ten seconds and come back; then lock and unlock.
5. Tap the deck's keyboard button, type a word, hide the keyboard. While the keyboard is up the strip should sit below the iOS status bar.
6. Open the session menu and close it; open a dialog with a text field and cancel it.
7. On the M6, set a 4:3 mode by hand (800x600): the strip stays and the picture gets side bars. The M6 stays at 4:3 (auto-fit runs only when the Duo's picture area changes); a fold or rotation, or a reconnect, brings 16:9 back.
8. Send the lines Console shows for `DuoSplit` (one at connect, one per layout change).

## Review

Reviewer: loop-reviewer on Fable (rung 1/3). Round 1: REJECT (two tests did not pin the held crease or the cover guard; two nits). Round 2 at 50caad303: APPROVE, no findings.

| Finding | Disposition |
|---|---|
| Rotation test passed on base | fixed: reports the landscape band, asserts strip and 455.5 before and after the portrait band returns |
| Cover guard unpinned | fixed: asserts `heldBand(cover)` is null while the inner band is reported; reverting the width check fails it |
| `debugPrint` override could leak | fixed: restored in `try/finally` |
| `refresh()` doc overstated | fixed: reworded to the plugin's cached-report behaviour |

## Verify

Captain gate on 50caad303, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 89 passed; `flutter analyze` on `duo_fold.dart`, `duo_split.dart`, `remote_page.dart` and `duo_split_test.dart`: the 2 pre-existing infos in `remote_page.dart`, none new.
