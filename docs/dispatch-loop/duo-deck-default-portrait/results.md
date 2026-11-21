---
name: duo-deck-default-portrait-results
description: "The iPhone Duo deck now shows under the picture in every portrait pose, RustDesk's bottom bar and its toggle FAB are hidden while it shows, and the bar's session actions sit on a slim deck row."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-deck-default-portrait
  modified: 2026-11-21
resource: flutter/lib/mobile/duo/duo_split.dart
generated:
  by: claude/sonnet
  session: a5f2a898929b22e10
  at: 2026-11-21T05:20:30-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-21T05:25:06-08:00
---

# Results: Duo deck by default in portrait

## Gate

Run from `flutter/` in the worktree.

| Command | Exit | Result |
| --- | --- | --- |
| `~/development/flutter/bin/flutter test --reporter=expanded test/duo_fold_test.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart` | exit 0 | `+42: All tests passed!` (re-run after review round 1) |
| `~/development/flutter/bin/flutter analyze lib/mobile/duo lib/mobile/pages/remote_page.dart lib/models/model.dart test/duo_fold_test.dart test/duo_split_test.dart test/duo_deck_test.dart` (before and after) | exit 1 both times (pre-existing infos) | 16 issues before, 16 after (re-run after review round 1); diff of the two outputs with line numbers stripped is empty |

Candidate commit: `5035747ca` (unit/duo-deck-default-portrait, base 733433c0f; review round 1 applied)

Captain re-run on `ec0d0d9dc`, and again on `5035747ca` after review round 1 (42 tests, exit 0): `flutter test --reporter=expanded test/duo_fold_test.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart` — 42 tests, OK, exit 0 (run-gate.sh pass-through).

Scratch: `.../scratchpad/analyze-before.txt`, `analyze-after.txt`, `test.txt`.

## Acceptance → tests

| # | Criterion | Proven by |
| --- | --- | --- |
| 1 | Split rules: laptop band, flat with band, cover 0.45, landscape none, non-Duo none, latch keeps cover split | duo_split_test: `duoSplitFrom a band in portrait splits at the band, in any posture`, `no usable band falls back to 0.45 of the view`, `landscape and non-Duo give none`, `the latch keeps the cover split`; duo_fold_test: `the Duo latch` |
| 2 | `DuoSplitBody` layout, live relayout on geometry and view size, child State kept, `onFoldChanged` per change | duo_split_test: `fold set: child above the fold, placeholder below it`, `fold set with below: ...`, `no fold: child fills the body, no placeholder`, `switching the fold relayouts live and keeps the child state` (3 changes incl. rotation, same State), `body shorter than the split: no overflow, no placeholder`; duo_deck_test: `fold set: keyboard above trackpad...`, `no fold: no deck` |
| 3 | `duoCanvasHeight` caps for any split, unchanged with none | duo_split_test: `duoCanvasHeight caps the height above the split only`; the `model.dart` call site by inspection |
| 4 | Deck row above the keyboard, actions fire, none means as before, no overflow at 373 and 455 pt | duo_deck_test: `session actions: row above the keyboard, actions fire`, `no actions: no session row`, `deck at height 373.0 / 455.0 ... does not overflow`, `deck with actions at height 60.0 / 80.0 / 373.0 / 455.0 does not overflow` |
| 5 | Bar and bar-toggle FAB hidden while split active; other actions on the deck row | MISSING as a test: `remote_page.dart` needs the FFI; proven by inspection of the diff against the spec table, on-device check by Lucas pending |
| 6 | Analyzer shows no new issues; all duo tests pass | Gate section above (42 passed; analyze diff empty) |

## Review round 1

| Item | Disposition |
| --- | --- |
| S2 deck row follows the bar's displays condition | Fixed: the `Builder` in `_duoSplit` reads `Provider.of<FfiModel>` and passes actions only when `pi.displays` is non-empty |
| S3 lines over 80 columns | Fixed: wrapped only the lines this unit added or reworded (`duo_fold.dart` latch doc and `update` line, `duo_split.dart` three doc comments, `remote_page.dart` `_duoDeckActive`) |
| S3 60 pt overflow case never showed the row | Fixed: 60 changed to 72 and the test asserts `duo-session-row` is present |
| S3 no press feedback on the row | Fixed: the row's `Row` is wrapped in `Material(type: MaterialType.transparency)` |

## Deviations

None. The plan's two forks used as planned (session row dropped under 60 pt inner height; `List<Widget>` actions built from `DuoDeckAction`). Small implementation details beyond the plan text: `_DuoSplitBodyState` stores the last `MediaQuery` size in `_view` (set in `didChangeDependencies`) so the geometry listener never reads `MediaQuery` outside build; `_mounted`-style first-run flag is `_view == null`.

## Regression surface

| Existing file / path | Behaviour change | Why unavoidable |
| --- | --- | --- |
| `remote_page.dart` `_bottomWidget` | Bar not built while the split is active (`&& !_duoDeckActive`) | Spec 3; false off a Duo |
| `remote_page.dart` `build` (`showActionButton`) | Bar-toggle FAB absent while the split is active; line rewrapped by the formatter width | Spec 3; upstream expression off a Duo |
| `remote_page.dart` `build` | `MediaQuery` size dependency through `_duoDeckActive` (read in `_bottomWidget` and `showActionButton`) | Spec 3 |
| `remote_page.dart` `_duoSplit` | `onFoldChanged` also calls `setState`; `below` is a `Builder` passing `_duoDeckActions` | Page must re-evaluate bar and FAB on split change; fires only with a split |
| `models/model.dart` `CanvasModel.getSize` | Passes `size` to `duoCanvasHeight`; cap applies for any split | Spec 2; `h` unchanged with no split |
| `duo_fold.dart`, `duo_split.dart`, `duo_deck.dart` | Duo-only files: latch, split rules, session row; behaviour changes only once the latch is set | The unit's purpose |

New in `remote_page.dart` (additive): `_duoDeckActive`, `_duoDeckActions`. No change to `getBottomAppBar`, the `emptyOverlay` entries, keyboard, trackpad, pbxproj, pubspec or generated files.

## Known limits

- Virtual mouse still clipped below the fold; deck ignores relative mouse mode (existing backlog).
- Cover-first start before any inner geometry shows upstream's layout until the latch is set.
- With the iOS soft keyboard up the deck is squeezed into the remaining body; under 60 pt of inner height the session row is left out.
- The gesture help panel takes the bottom slot and shrinks the deck by its height.
- The `_duoDeckActions` row and bar hiding in `remote_page.dart` are not covered by an automated test.

Cleanup: none
