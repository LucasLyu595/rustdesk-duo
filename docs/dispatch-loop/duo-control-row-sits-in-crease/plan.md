---
name: duo-control-row-sits-in-crease-plan
description: "Plan to end the laptop-pose picture at the crease band's top, start the deck there with its session row in the band and the keyboard right below it, remove the deck-give rule and the crease touch block, and aim auto-fit at the 669x455.5 picture area; Revision 1 adds a full-width laptop fit, a picture that rests on the crease, and a status strip above it."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-control-row-sits-in-crease
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 41af5e2b-05b0-47c6-837a-53ef33c5a4f0
  at: 2026-11-22T00:31:31-08:00
---

# Plan: the deck's control row sits in the crease

Spec: `docs/dispatch-loop/duo-control-row-sits-in-crease/spec.md`. Base `duo-mode` at `d77b12c63`.
Worktree `/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-control-row-sits-in-crease`. Two
tasks, run in order by one implementer.

## Files touched

| File | Change | Notes |
|---|---|---|
| `flutter/lib/mobile/duo/duo_split.dart` | edit, net deletion | laptop rule, `crease` -> `rowBand`, `kDuoDeckGive` and the `AbsorbPointer` removed, one condition in `duoFitAreaFrom` |
| `flutter/lib/mobile/duo/duo_deck.dart` | edit | optional `rowExtent` on `DuoDeck` and `DuoDeck.forSession`; 3 existing lines modified, 2 added in `build` |
| `flutter/lib/mobile/pages/remote_page.dart` | +1 argument, 0 other lines | `rowExtent:` in the existing `DuoDeck.forSession` call of `_duoSplit` |
| `flutter/test/duo_split_test.dart` | edit | 1 test rewritten, 1 removed, 5 expectations updated |
| `flutter/test/duo_deck_test.dart` | edit | 1 test rewritten |
| `flutter/test/duo_resolution_test.dart` | edit | 1 test updated |

Nothing else: no `model.dart`, `duo_resolution.dart`, `duo_fold.dart`, keyboard or trackpad file,
no Rust, bridge, lang file, pubspec or `project.pbxproj`. `docs/DUO.md` (lines ~71-73 and ~86
describe the behaviour this unit replaces) is not an owned file; see "Spec ambiguities" 4.

## Facts checked while planning (beyond the spec's)

- `kDuoDeckGive`, `DuoSplit.crease` and `AbsorbPointer` are referenced only inside
  `duo_split.dart`; in tests only `duo_split_test.dart` reaches them (through `aspect:` values and
  one touch test). No other file names them.
- `DuoDeck(` is constructed only by `DuoDeck.forSession` and by `duo_deck_test.dart`;
  `DuoDeck.forSession` is called once, in `remote_page.dart` `_duoSplit` (~607), inside a
  `Builder` that is the `below` widget of `DuoSplitBody`.
- That `Builder` is rebuilt on every split change: `_onFold` calls `setState` and then
  `onFoldChanged`, whose page `setState` rebuilds `_duoSplit` in the same frame. A view-size
  change rebuilds it too once the `Builder` reads `MediaQuery.sizeOf(context)`.
- `laptopFoldFrom` (`duo_fold.dart` ~50) needs the inner screen, posture `book` and a non-empty
  band at least as wide as tall; it does not look at the angle. The first loop of the existing
  fit-area test (`duo_resolution_test.dart` ~111) therefore covers laptop (`book`) and flat with
  a band (`open`).
- With the deck from 455.5 to 951 and a 40 pt strip: content height 489.5, key row height
  `((489.5 - 40) * 0.6 - 16) / 5 = 50.7`, clamped to 46; keyboard 495.5-741.5, trackpad
  747.5-945 (197.5 pt). At base with the deck from 495.5 the trackpad is 156 pt, so the deck gains
  about 41 pt, as the spec's intent says.
- The worktree has neither `flutter/.dart_tool` nor the gitignored
  `flutter/lib/generated_bridge.dart` and `generated_bridge.freezed.dart`; the main checkout has
  both files. See "Gate".

## Decisions

### 1. How the deck learns the band (R2): `DuoSplit.rowBand` -> an optional `rowExtent` on the deck

Chosen: the split keeps its one optional field, renamed; the deck takes the band's height as an
optional parameter; the existing page hook passes it.

```dart
// duo_split.dart
const DuoSplit({required this.pictureBottom, required this.deckTop, this.rowBand});

/// The band the deck's session row sits in, in the laptop pose.
final Rect? rowBand;

// duo_deck.dart
/// The height of the strip at the deck's top that holds the session row; null
/// lays the row out above the keyboard as usual.
final double? rowExtent;

const DuoDeck(
    {Key? key,
    required this.keys,
    required this.pointer,
    this.actions = const [],
    this.rowExtent})
    : super(key: key);

factory DuoDeck.forSession(FFI ffi,
    {List<Widget> actions = const [], double? rowExtent})
```

Hook in `remote_page.dart`, one added argument in the existing `DuoDeck.forSession(gFFI, ...)`
call (the `context` is the `Builder`'s):

```dart
rowExtent: currentDuoSplit(MediaQuery.sizeOf(context))?.rowBand?.height,
```

In the laptop pose `deckTop == band.top`, so a strip of `band.height` at the deck's top is the
band rect, and the keyboard placed right after the strip starts at `band.bottom`. The deck needs
one number and no view coordinates. `rowBand` does not depend on `aspect` or `paddingTop` (the
laptop branch reads neither), so the bare `currentDuoSplit(size)` call is exact, the same way
`_duoDeckActive` uses it two lines above.

`rowBand` stays in `==` and `hashCode`. A flat picture whose aspect height happens to equal
`band.top` gives the same two edges as the laptop pose; with the field compared, `_onFold` still
sees laptop <-> flat as a change, fires `onFoldChanged`, and the page rebuilds the deck with or
without the strip.

Rejected:

- **`DuoDeck` reads the split itself** (`currentDuoSplit` in `build`). The deck would depend on a
  global it is not given, and would not rebuild on a fold change unless its parent does; every
  existing deck test would silently depend on fold state.
- **`DuoSplitBody` passes the band to `below`.** `below` is a `Widget`; this needs a builder
  parameter or an inherited widget, which changes `DuoSplitBody`'s API for every caller and adds
  an abstraction for one number.
- **No field, read `DuoFold.instance.laptop.value?.band`.** The laptop fold exists for a band
  that fails the split's usable checks (the split then uses 0.45 of the view), so the deck would
  reserve a strip that is not on the crease; and the equal-edges case above would go unseen.

Against AGENTS.md:

- Thin hook: `remote_page.dart` gains one argument line and no import; `model.dart` is untouched.
- No placeholder forced on a caller: both new parameters are optional; every existing `DuoDeck(`
  and `DuoSplit(` call compiles unchanged.
- No new kind of state: nothing is stored. The value is read from the split each time the deck is
  built, and the split already is what the body and the page react to.
- R3 / "simplify the earlier commit": the field count of `DuoSplit` stays at what `9138085fe`
  left (one optional `Rect`), a constant and a `Stack` child go away, and the laptop branch
  becomes one `return`.

### 2. Deck layout with a strip

`DuoDeck.build`, with `rowExtent` as `strip`:

- Padding: `const EdgeInsets.all(6)` becomes
  `EdgeInsets.fromLTRB(6, rowExtent == null ? 6 : 0, 6, 6)` (no top inset under a strip, so the
  strip starts at `deckTop`).
- `showRow` line: unchanged.
- `top`: `rowExtent ?? (showRow ? 32.0 + 6 : 0.0)`.
- `Column` children: one line added before the row block,
  `if (rowExtent != null) SizedBox(height: showRow ? gap : rowExtent)`, and the existing
  `const SizedBox(height: 6)` after the row becomes `SizedBox(height: rowExtent == null ? 6 : gap)`,
  where `gap` is `((rowExtent - 32) / 2).clamp(0.0, rowExtent)` computed beside `top` (no new
  import). The 32 pt row `SizedBox` with `Key('duo-session-row')`, its `Material` and `Row` are
  not touched or moved.

Result with a 40 pt strip: 4 pt, the 32 pt row, 4 pt, then the keyboard. With a strip and no
actions (peer displays not yet known), the strip stays empty and the keyboard still starts below
the band. With `rowExtent == null` every expression evaluates to its base value: padding 6 on all
sides, `top` 38 or 0, gap 6.

The row keeps the deck's 6 pt side inset (it spans x 6 to 663 of 669); see "Spec ambiguities" 1.
The area of the strip beside the buttons is the deck's black `ColoredBox` and takes no action.

Known limit, left as is: a strip lower than the 32 pt row (not a size the Duo reports; the band
is 40 pt) puts the keyboard at the row's bottom instead of the band's, and a deck shorter than
the strip plus the keyboard's 22 pt minimum overflows the way a deck under 34 pt does at base.

### 3. R1 and R3: what goes from `9138085fe`

| Item from `9138085fe` | Disposition |
|---|---|
| `kDuoDeckGive` and its doc comment | removed |
| laptop branch `y = full within the give ? full : band.bottom` | replaced by `return DuoSplit(pictureBottom: band.top, deckTop: band.top, rowBand: band);` |
| `DuoSplit.crease` ("takes no touches") | renamed `rowBand` with the new doc comment; constructor, `==`, `hashCode` follow the rename |
| the `AbsorbPointer` child in `DuoSplitBody.build` | removed; the `Stack` is picture + deck again |
| test `laptop: a touch in the crease band does not reach the picture` | removed (the rule it pins is gone; a tap in the band is now covered by the deck test) |
| test `laptop: the picture runs to the band, or to full width within the deck give` | rewritten for R1 |
| `_usableBand`, `duoPeerAspect`, `kDuoFlatPictureFraction`, the flat branch, `aspect` / `aspectChanged`, `_onAspect`, `_top`, `duoFitAreaFrom`, `currentDuoFitArea`, the `model.dart` and `remote_page.dart` aspect hooks | kept untouched: the flat pose (R5) still uses all of them |

`duoSplitFrom` after the change, in order (`full` and `laptop` computed as today):

1. `!isDuo` or `W >= H` -> null (unchanged).
2. usable band and laptop -> `band.top` for both edges, `rowBand: band`. (R1)
3. inner, not laptop, aspect known -> `min(full, 0.6 H)` for both (unchanged).
4. usable band -> `DuoSplit(pictureBottom: band.top, deckTop: band.bottom)` (unchanged).
5. else `0.45 H` for both (unchanged).

Only step 2's body changes. A laptop pose whose band fails the usable checks still falls to step
5, as at base. `duoCanvasHeight` is untouched; in the laptop pose it now returns
`band.top - paddingTop`.

### 4. R4: the fit area

`duoFitAreaFrom`, one condition changed:

```dart
if (band != null && laptopFoldFrom(geometry!) == null) {
  return Size(viewSize.width, band.bottom - paddingTop);
}
```

(was `if (band != null)`). The laptop pose with a usable band then reaches the function's last
line, `Size(W, split.pictureBottom - T)`, which is `Size(W, band.top - T)` because the split it
reads is the aspect-free one. Flat with a band (`band.bottom - T`), flat without a band
(`0.6 H - T`), cover and the laptop pose with an unusable band give what they give at base.
`duo_resolution.dart` is not edited: `schedule` already calls `currentDuoFitArea`, and
`chooseDuoResolution` is unchanged.

## Auto-fit picks (computed from `chooseDuoResolution`'s rule)

Mode list: 3840x2160, 3360x1890, 3008x1692, 2560x1440, 1920x1080, 1600x900, 1280x720 (16:9) and
1024x768, 800x600 (4:3). Distance is `|ln(mode aspect / area aspect)|`; the lowest mode within
0.02 of the best wins. `T = 0`.

| Pose | Fit area | Area aspect | Distance 4:3 | Distance 16:9 | Pick | Split after the pick | Notes |
|---|---|---|---|---|---|---|---|
| Laptop, 669x951, band 455.5-495.5 | 669x455.5 | 1.469 | 0.097 | 0.191 | 800x600 | 455.5 for both edges | picture 607.3x455.5, bars of 30.8 pt on each side (28,100 pt² unused); 16:9 would be 669x376.3 with 39.6 pt bars above and below (53,000 pt²). Changed by this unit |
| Flat with band, 669x951 | 669x495.5 | 1.350 | 0.013 | 0.275 | 800x600 | 501.75 for both edges | picture exactly 669x501.75, no bars; as at base |
| Flat without band, 669x951 | 669x570.6 | 1.172 | 0.129 | 0.416 | 800x600 | 501.75 for both edges | picture exactly 669x501.75, no bars; as at base |
| Cover, 466x678 | 466x305.1 | 1.527 | 0.136 | 0.152 | 800x600 | 305.1 | picture 406.8x305.1, bars of 29.6 pt on each side; as at base |

The fit still runs once per session, in the pose the deck first shows in. The implementer copies
this table into the results doc, with all four rows confirmed by the test in task 2.

## Tasks

### Task 1: laptop split and the row in the band

Owned files: `flutter/lib/mobile/duo/duo_split.dart`, `flutter/lib/mobile/duo/duo_deck.dart`,
`flutter/lib/mobile/pages/remote_page.dart`, `flutter/test/duo_split_test.dart`,
`flutter/test/duo_deck_test.dart`.

1. `duo_split.dart`: decision 3 (rename, constant removed, laptop branch, `AbsorbPointer` child
   removed). Leave `full` where it is; it still feeds the flat branch.
2. `duo_deck.dart`: decisions 1 and 2 (field, constructor, factory, the five lines in `build`).
3. `remote_page.dart` `_duoSplit`: the one `rowExtent:` argument of decision 1. No other line.
4. Tests in `duo_split_test.dart` and `duo_deck_test.dart`, listed below.

### Task 2: auto-fit area

Owned files: `flutter/lib/mobile/duo/duo_split.dart` (`duoFitAreaFrom` only),
`flutter/test/duo_resolution_test.dart`.

1. `duo_split.dart`: the one-condition change of decision 4.
2. The test update in `duo_resolution_test.dart`, listed below.

## Tests

Three tests carry the new behaviour; none adds infrastructure.

| # | File | Name | Asserts |
|---|---|---|---|
| N1 | `duo_split_test.dart`, group `duoSplitFrom`; rewrites `laptop: the picture runs to the band, or to full width within the deck give` | `laptop: the picture ends at the band top, whatever the aspect` | `_geo()`, 669x951, for `aspect` 4 / 3, 16 / 9 and none: `pictureBottom == 455.5` and `deckTop == 455.5` |
| N2 | `duo_deck_test.dart`; rewrites `fold set: keyboard above trackpad, both below the band` | `laptop: the session row sits in the band, the keyboard right below it` (widget) | view 669x951, laptop geometry with `_band`; `DuoSplitBody(below: DuoDeck(..., rowExtent: currentDuoSplit(const Size(669, 951))!.rowBand!.height, actions: [clear -> a++, tv]), child: SizedBox.expand())`. Row rect (`Key('duo-session-row')`): `top >= 455.5`, `bottom <= 495.5`; `tester.tap(find.byIcon(Icons.clear))` -> `a == 1`; keyboard `top` closeTo(495.5, 1); `kb.bottom <= tp.top`; `tp.bottom <= 951` |
| N3 | `duo_resolution_test.dart`; updates `the fit area follows the band on the inner screen and picks 4:3` | `the fit area ends at the band top in the laptop pose and picks 4:3` | posture `book` + band -> `Size(669, 455.5)` and `pick(k4k, area) == '800x600'`; posture `open` + band -> `Size(669, 495.5)` and `800x600`; the flat-without-band (570.6), cover (305.1) and `isDuo: false` lines stay as they are |

N2 reads the strip height from the split the same way the page hook does, so it fails if the
split stops carrying the band or the deck stops honouring it.

Existing expectations updated, only where they encode the laptop rule being replaced
(`duo_split_test.dart`):

| Test | Line(s) | Old | New | Why |
|---|---|---|---|---|
| `fold set: child above the fold, placeholder below it` | ~52, ~54 | child `0,0,669,495.5`; placeholder from 495.5 | child `0,0,669,455.5`; placeholder `LTRB(0, 455.5, 669, 951)` | picture ends and deck starts at the band top |
| `fold set with below: that widget replaces the placeholder` | ~70 | below from 495.5 | `LTRB(0, 455.5, 669, 951)` | same |
| `switching the fold relayouts live and keeps the child state` | ~104 | 495.5 | 455.5 | same; the flat step and all `changes` counts are unchanged |
| `body shorter than the split: no overflow, no placeholder` | ~131 | heights `[480.0, 400.0]` | `[450.0, 400.0]` | a 480 pt body is now taller than the 455.5 deck top and shows the area below; 450 keeps the test's meaning |
| `duoCanvasHeight caps the height above the split only` | ~291 | 445.5 | 405.5 | 455.5 - 50 |

Removed: `laptop: a touch in the crease band does not reach the picture` (decision 3).

Not edited: `a changed peer aspect relayouts the picture`, `flat: the picture takes its aspect
height, capped at 0.6 of the view`, `no usable band falls back to 0.45 of the view`, `landscape
and non-Duo give none`, `the latch keeps the cover split`, `no fold: child fills the body, no
placeholder`; in `duo_deck_test.dart` every test but the rewritten one (they build the deck
without `rowExtent` and pin the base layout: row above the keyboard, keyboard top at 6 with no
actions, no overflow at each height); the first seven `duo_resolution_test.dart` tests;
`duo_fold_test.dart`, `duo_keyboard_test.dart`, `duo_trackpad_test.dart`.

No test for the `remote_page.dart` argument: it would need a live `FFI` or a test-only seam,
which AGENTS.md rules out. It is covered by the diff (one line), by N2 using the same expression,
and by D6 on the device.

## Acceptance -> tests

| Done-when | Evidence |
|---|---|
| D1 laptop split 455.5 for 4:3, 16:9, unknown | N1 |
| D2 row inside the band, its × fires there, keyboard top at 495.5 (± 1) | N2 |
| D3 laptop area 669x455.5 picks 800x600; flat areas unchanged | N3 (laptop and flat-with-band lines new or kept; flat-without-band and cover lines unedited) |
| D4 flat, cover, landscape, non-Duo unchanged | the unedited tests listed above; edits limited to the five expectations, one removal and three rewrites in "Tests" |
| D5 focused gate | commands under "Gate" |
| D6 on the Duo | captain, after merge and reinstall; not part of this gate |

## Gate

Preparation, once, in the worktree (none of it is committed):

1. `cp /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.dart /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.freezed.dart flutter/lib/`
   The files are gitignored and absent from the worktree; the tests cannot compile without them.
   This is a copy, not a codegen run. If the main checkout lacks them, stop and report; do not
   run `flutter_rust_bridge_codegen`.
2. From `flutter/`: `~/development/flutter/bin/flutter pub get`. If it changes a tracked file (for
   example `pubspec.lock`), restore it with `git checkout -- <file>` and say so in the results
   doc.

Focused and closing gate, from `flutter/` (the same commands both times):

```
~/development/flutter/bin/flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart test/cursor_size_test.dart test/floating_mouse_cursor_offset_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_split.dart lib/mobile/duo/duo_deck.dart lib/mobile/pages/remote_page.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_resolution_test.dart
```

Pass: every test passes; `analyze` reports no issue that the base does not have in the same
files. For the baseline, run the same `analyze` line once in the main checkout
`/Users/lucas/rustdesk-duo/flutter` (branch `duo-mode` at the base commit, read-only) and compare
the issue lists.

Red-first check for the results doc: with the tests edited and the sources at base, N1 and N3
fail on values and N2 fails to compile (`rowExtent`, `rowBand`); record that once, do not keep a
failing commit.

This unit touches nothing under `scripts/tests/`; this repository has no scratch-git or
selftest-coverage lint, so none joins the gate. `git status --short` before each commit must show
only the six files above (plus this unit's docs); `flutter/ios/Runner.xcodeproj/project.pbxproj`
is never staged. Stage explicit paths.

## Regression surface

| Existing file / runtime path | What changes | Why unavoidable |
|---|---|---|
| `duo_split.dart` `duoSplitFrom`, laptop pose with a usable band | picture bottom and deck top move from `band.bottom` (or up to 12 pt lower) to `band.top`, for any aspect; the split's optional rect is named `rowBand` | R1, R3 |
| `duoSplitFrom`, every other case (flat, cover, unusable band, landscape, non-Duo) | none: steps 1 and 3-5 are the base code | R5 |
| `DuoSplitBody.build` | the invisible `AbsorbPointer` over the band is gone; in the laptop pose the band is covered by the deck instead of the picture | R1, R3 |
| `DuoSplit` equality | compares `rowBand` where it compared `crease`: same rect, same poses, so `onFoldChanged` fires for the same transitions as at base | rename only |
| `CanvasModel.getSize()` through `duoCanvasHeight`, Duo in the laptop pose | canvas height is `band.top - T` (was `band.bottom - T` or the full-width height); no code change in `model.dart` | R1 |
| `duoFitAreaFrom` / `DuoResolutionFit.schedule`, laptop pose with a usable band | area is `W x (band.top - T)` (was `band.bottom - T`); the pick on the M6 stays 800x600 | R4 |
| `duoFitAreaFrom`, every other case | none | R4, R5 |
| `DuoDeck.build` with `rowExtent == null` (flat, cover, every existing test) | same widgets and sizes; three expressions gain a null check that selects the base value, and the padding is no longer `const` | R2 needs the strip in the same `Column`; a parallel build method would duplicate the whole deck |
| `DuoDeck.build` with `rowExtent` set (laptop pose) | no top inset; the row is centred in a strip of that height; the keyboard follows the strip; keyboard and trackpad get the height freed | R2 |
| `_RemotePageState._duoSplit` (`remote_page.dart`) | passes `rowExtent` to `DuoDeck.forSession`; the deck `Builder` now also depends on `MediaQuery` size | R2: the page is the one place that builds the deck |

Desktop, web, Android and non-Duo iOS: no path changes. `DuoSplitBody` returns no split there,
the deck is never built, and `model.dart` is not edited.

## Spec ambiguities (not changed; chosen reading stated)

1. **"Full width" row (R2).** The plan keeps the deck's 6 pt side inset, so the row spans x 6 to
   663 and lines up with the keyboard below it. Its buttons are spread evenly, so an inset-free
   row would move each by under 2 pt. Dropping the inset needs a second layout path in the deck;
   not done.
2. **A strip with no actions.** While the peer's displays are unknown the page passes no actions.
   R2 does not say what the band shows then; the plan keeps the strip empty so the keyboard never
   sits on the crease.
3. **Laptop pose with an unusable band.** As in the previous unit: R1 needs a usable band, so
   this case keeps the 0.45 rule with no strip.
4. **`docs/DUO.md`.** Lines ~71-73 ("the picture runs over the crease down to the deck. Touches on
   the crease do nothing ...") and ~86 (fit area 669x496) describe the replaced behaviour. The
   spec does not list the guide; the previous unit's guide text was a separate captain commit
   after D-on-device. Left to the captain the same way.
5. **Frontmatter status.** The plan-stage template says `draft`; the captain's task prompt asks
   for `stable`. The plan carries `stable` as instructed.

## Revision 1

Spec: "## Revision 1" (R6-R9, D7-D10). This section is the delta on top of candidate `5cca141fd`
(first round implemented: `DuoDeck.rowExtent`, `DuoSplit.rowBand`, laptop picture to `band.top`,
fit area 669x455.5). Everything above stands except where this section replaces it: the laptop
row of "Auto-fit picks", the `duoCanvasHeight` sentence of decision 3, and the "Gate" command
lines. One task, one implementer.

### Files touched (delta)

| File | Change | Notes |
|---|---|---|
| `flutter/lib/mobile/duo/duo_resolution.dart` | edit, additive | new `chooseDuoResolutionFullWidth`; `tryFit` gains optional `fullWidth`; one argument in `schedule` |
| `flutter/lib/mobile/duo/duo_split.dart` | edit | `DuoSplit.pictureTop`, `duoPictureOffset`, `kDuoStripMinExtent`, laptop branch, `DuoSplitBody.above`, picture `Positioned`, `duoCanvasHeight` |
| `flutter/lib/mobile/duo/duo_status_strip.dart` | new | `DuoStatusStrip` and `DuoStatusStrip.forSession` |
| `flutter/lib/mobile/pages/remote_page.dart` | +1 import, +1 argument in `_duoSplit`, 1 line modified + 2 added in `_KeyHelpToolsState._updateRect` | thin hooks |
| `flutter/test/duo_resolution_test.dart` | edit | 1 test updated, 1 added |
| `flutter/test/duo_deck_test.dart` | edit | 1 test added |
| `flutter/test/duo_split_test.dart` | edit | 1 expectation added, 1 test restored (note 11) |
| `flutter/test/duo_status_strip_test.dart` | new | 1 test |

Not touched: `model.dart`, `input_model.dart`, `remote_input.dart`, `duo_deck.dart`,
`duo_fold.dart`, Rust, bridge, lang files, `project.pbxproj`.

### Facts checked for the revision

- **Delay.** `Session::handle_test_delay` (`src/ui_session_interface.rs` ~1929) calls
  `update_quality_status` with `delay` for every server `TestDelay`, with no check of the
  quality-monitor option; `flutter.rs` ~717 pushes the event on every platform; Dart
  `QualityMonitorModel.updateQualityStatus` (`model.dart` ~3937) stores `_data.delay` (a string
  of whole milliseconds) and calls `notifyListeners()` whether or not `_show` is set. The io
  loop's status tick (`io_loop.rs` ~389-423) also sends speed and fps about once a second, so the
  model notifies at least that often. The delay is therefore available on mobile with the monitor
  hidden; the strip shows it. This is read from the code, not observed; D6 on the Duo confirms it.
- **Peer name.** `PeerInfo.hostname` (`model.dart` ~4521, `''` until peer info arrives); the
  page has `widget.id`.
- **Picture child structure** (`remote_page.dart` ~556-590): `DuoSplitBody.child` is
  `RawPointerMouseRegion` (a `Listener`) -> `Overlay` -> `Container` -> `SafeArea` ->
  `RawTouchGestureDetectorRegion` -> `getBodyForMobile()` (a `Stack` with `ImagePaint`,
  `QualityMonitor`, `KeyHelpTools`, `CursorPaint`). The canvas therefore starts `T` below the
  child's top, and existing code relies on exactly that.
- **Coordinate readers**, traced for a child moved down by `d = pictureTop - T`:

| Reader | Coordinates it uses | After the move |
|---|---|---|
| touch gestures, `remote_input.dart` (`cursorModel.move`, `updatePan`, `isInRemoteRect`, ...) | `d.localPosition` of the detector inside the `SafeArea` | right: local to the canvas area, which moves with the child |
| physical mouse down / move / up, `input_model.dart` `_pointerPositionForRemoteCanvas` (~1937) | `event.localPosition` of the outer `Listener`, minus window `padding.top`, minus `getAdjustY()` | right, provided the child keeps its `SafeArea` inset (decision R1.2) |
| `ImagePaint`, `CursorPaint` (`remote_page.dart` ~1309, ~1357), `updateScale` (`model.dart` ~2751), `getRemotePosInRect` (~3316) | canvas offset plus `getAdjustY()`, painted inside the child | right while `getAdjustY()` is right |
| `shouldIgnoreTouchTap` / `_lastMouseDownPos` | global against global | unaffected |
| `CanvasModel.getSize` (~2340) | window size and padding, then `duoCanvasHeight` | right with the `duoCanvasHeight` change (R1.2) |
| `KeyHelpTools._updateRect` (`remote_page.dart` ~1121) -> `keyHelpToolsRect`, read by `getAdjustY` (~2380), `getSize` (~2353) and `shouldBlock` (~3286) | **global y** (`localToGlobal(Offset.zero)`), treated as "distance from the body's top" | wrong by `d` while the iOS soft keyboard and its key row show: thin fix R1.3 |
| mouse hover, `RawPointerMouseRegion.onPointerHover` (`remote_input.dart` ~663) | **global** `evt.position` | wrong by `d` (it is already wrong by `T` at base): known limit, see ambiguities |

### Decisions

#### R1.1 (R6) A second chooser, picked by an argument

```dart
// duo_resolution.dart
/// Among the modes at least as wide as [area] in aspect, the closest, then the
/// lowest; without such a mode, [chooseDuoResolution].
Resolution? chooseDuoResolutionFullWidth(List<Resolution> modes, Size area)
```

Body: null for an empty area; `target = area.width / area.height`;
`wide = modes.where((m) => m.height > 0 && m.width / m.height >= target)`;
`return chooseDuoResolution(wide.isEmpty ? modes : wide, area)`. Inside `wide` the distance is
one-sided, so the existing function already gives "closest in aspect, then the lowest" with its
0.02 tolerance. `chooseDuoResolution` is not edited.

`DuoResolutionFit.tryFit` gains one optional named parameter, `bool fullWidth = false`, and its
one chooser line becomes
`final mode = (fullWidth ? chooseDuoResolutionFullWidth : chooseDuoResolution)(modes, area);`.
`schedule` adds one argument:

```dart
fullWidth: currentDuoSplit(media.size)?.rowBand != null,
```

`rowBand` is set exactly in the laptop pose with a usable band, the same condition under which
the fit area is `Size(W, band.top - T)`. Nothing is stored; every existing `tryFit` caller and
`currentDuoFitArea` keep their signatures. The fit area itself is unchanged (it is computed from
the aspect-free split, which has no `pictureTop`).

#### R1.2 (R7) `DuoSplit.pictureTop`; the child is positioned, the canvas is not shifted

```dart
const DuoSplit(
    {required this.pictureBottom,
    required this.deckTop,
    this.rowBand,
    this.pictureTop = 0});

/// Where the picture starts when it rests on the crease and is shorter than
/// its area; 0 when it starts at the view's top inset.
final double pictureTop;

/// How far below the view's top the picture child starts.
double duoPictureOffset(DuoSplit? split, double paddingTop) =>
    split == null ? 0 : max(0, split.pictureTop - paddingTop);
```

`pictureTop` joins `==` and `hashCode`. The laptop branch of `duoSplitFrom` becomes

```dart
return DuoSplit(
    pictureBottom: band.top,
    deckTop: band.top,
    rowBand: band,
    pictureTop: full != null && full < band.top
        ? band.top - (full - paddingTop)
        : 0);
```

(`full = T + W / a`, so the condition is the spec's `W / a < band.top - T` and the value is
`band.top - W / a`.) No other branch changes; they keep the default 0.

`DuoSplitBody.build`: `final top = duoPictureOffset(split, _top);` and the picture's
`Positioned` becomes `top: top` with
`height: max(0.0, (split == null ? height : min(split.pictureBottom, height)) - top)`.
With `top == 0` both are the base values.

The child is placed at `pictureTop - T`, not at `pictureTop`, and its `MediaQuery` is left alone:
the `SafeArea` inside it still insets `T`, so the canvas runs from `pictureTop` to `band.top` and
there is no double padding. This is what keeps `_pointerPositionForRemoteCanvas` right (it
subtracts the window's `padding.top` from a position local to the child's root). Removing the
top padding from the child's `MediaQuery` instead would make that subtraction wrong by `T` and
need an edit in `input_model.dart`. On the Duo's inner screen `T = 0` and the two coincide.

`duoCanvasHeight`: the return expression becomes
`max(0, min(h, split.pictureBottom - max(split.pictureTop, paddingTop)))`. With the default
`pictureTop` it is the base expression; with a 16:9 picture it is `W / a` (376.31), so the canvas
is exactly the picture: full width, no bars inside the area. `model.dart` is not edited (the
aspect is already passed in).

An aspect change (auto-fit's reply, a mode picked by hand) moves the picture through the existing
`_onAspect` listener, because `pictureTop` is part of the split it compares. No new listener.

#### R1.3 Thin fix for the one global-y reader

`_KeyHelpToolsState._updateRect` (`remote_page.dart` ~1121) reports the key row's rect in global
coordinates; three readers treat its `bottom` as a distance from the body's top. With the child
moved down by `d`, the picture would be drawn `d` too low while the iOS soft keyboard shows
(reachable from the deck's keyboard button). Fix at the one writer, so the three readers stay
untouched:

```dart
final media = MediaQueryData.fromView(View.of(context));
final dy = duoPictureOffset(
    currentDuoSplit(media.size,
        paddingTop: media.padding.top,
        aspect: duoPeerAspect(gFFI.ffiModel.pi)),
    media.padding.top);
```

and `pos.dy` becomes `pos.dy - dy` in the existing `Rect.fromLTWH`. `dy` is 0 whenever there is
no strip, so every non-Duo and every other Duo case passes the same rect as today. No state. It
has no unit test (it needs a live `FFI` and the platform keyboard); the captain checks it at D6
by opening the soft keyboard in the laptop pose. If the captain prefers the smaller diff, the
alternative is to leave `_updateRect` alone and list "soft keyboard open in the laptop pose with
a strip: picture `d` too low" as a known limit; see ambiguities.

#### R1.4 (R8) The status strip

New file `flutter/lib/mobile/duo/duo_status_strip.dart`:

```dart
/// One non-interactive status line for the strip above a laptop-pose picture.
class DuoStatusStrip extends StatefulWidget {
  const DuoStatusStrip(
      {super.key, this.name, this.delay, this.changed, this.now = DateTime.now});

  /// The peer's name, or null when unknown.
  final ValueGetter<String?>? name;

  /// The round-trip delay in ms, or null when the session has not reported it.
  final ValueGetter<String?>? delay;

  /// Notifies when [name] or [delay] may have changed.
  final Listenable? changed;

  final ValueGetter<DateTime> now;

  factory DuoStatusStrip.forSession(FFI ffi, String id)
}
```

- `forSession`: `name: () => ffi.ffiModel.pi.hostname.isNotEmpty ? ffi.ffiModel.pi.hostname : id`,
  `delay: () => ffi.qualityMonitorModel.data.delay`, `changed: ffi.qualityMonitorModel` (it
  notifies about once a second, which also picks up the hostname when peer info arrives).
  Imports: `dart:async`, `package:flutter/material.dart`, `'../../models/model.dart' show FFI`.
- Text: the non-empty parts of `[name, '$delay ms', 'HH:MM']` joined by `'  ·  '` (two spaces,
  middle dot, two spaces); the time is 24-hour local, zero-padded. An empty or null name or delay
  is left out.
- State: `_text` (the line shown) and `_timer`. `initState` listens to `changed` and arms
  `_timer = Timer(Duration(seconds: 60 - now().second), _tick)`; `_tick` refreshes and re-arms.
  The `changed` listener and `_tick` call one `_refresh()` that rebuilds the line and calls
  `setState` only when it differs. `didUpdateWidget` moves the listener when the `Listenable`
  differs (same pattern as `DuoSplitBody.aspectChanged`); `dispose` removes it and cancels the
  timer. The timer is the "clock lives and dies with the widget" state the spec allows; nothing
  else is added.
- Build: `IgnorePointer` -> `Padding(EdgeInsets.symmetric(horizontal: 40))` -> `Center` ->
  `Text(_text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
  style: const TextStyle(color: Colors.grey, fontSize: 12))`. The black behind it is
  `DuoSplitBody`'s existing `ColoredBox`.

Placement: `DuoSplitBody` gains one optional parameter and one `Stack` child.

```dart
/// The least height above a laptop-pose picture that shows [DuoSplitBody.above].
const double kDuoStripMinExtent = 24;

/// Shown above the picture when it rests on the crease and leaves room.
final Widget? above;

// in build, after the picture child
if (widget.above != null && top >= kDuoStripMinExtent)
  Positioned(top: _top, left: 0, right: 0, height: top, child: widget.above!),
```

The strip widget covers `T .. pictureTop` (height `pictureTop - T`), so its line is centred in
the part below the top inset; on the Duo (`T = 0`) that is the whole strip. `top > 0` happens
only in the laptop pose, so no pose check is needed. Hook in `_duoSplit`, one added argument
(plus `import '../duo/duo_status_strip.dart';` beside the other Duo imports):

```dart
above: DuoStatusStrip.forSession(gFFI, widget.id),
```

### Auto-fit picks (replaces the laptop row above)

Same mode list, `T = 0`. Laptop uses `chooseDuoResolutionFullWidth`; the others
`chooseDuoResolution`.

| Pose | Fit area | Chooser | Candidates | Pick | Split after the pick | Notes |
|---|---|---|---|---|---|---|
| Laptop, 669x951, band 455.5-495.5 | 669x455.5 (1.469) | full width | the seven 16:9 modes (1.778 >= 1.469), all at distance 0.191 | 1280x720 | picture 79.19-455.5, deck from 455.5 | picture exactly 669x376.31, no bars; strip 79.19 pt; 0.523 pt per Mac pt |
| Flat with band, 669x951 | 669x495.5 (1.350) | closest | 4:3 at 0.013, 16:9 at 0.275 | 800x600 | 501.75 for both edges | picture exactly 669x501.75; as at base |
| Flat without band, 669x951 | 669x570.6 (1.172) | closest | 4:3 at 0.129, 16:9 at 0.416 | 800x600 | 501.75 for both edges | as at base |
| Cover, 466x678 | 466x305.1 (1.527) | closest | 4:3 at 0.136, 16:9 at 0.152 | 800x600 | 305.1 | picture 406.8x305.1, 29.6 pt side bars; as at base |

For D10 the results doc repeats this table and states: 1280x720 at full width is 0.523 pt per
Mac pt, 800x600 at 455.5 tall is 0.759, so text is about 69% as large in the laptop pose. The fit
still runs once per session, in the pose the deck first shows in (see ambiguities).

### Task (one implementer, on top of `5cca141fd`)

Owned files: the eight in "Files touched (delta)".

1. `duo_resolution.dart`: R1.1.
2. `duo_split.dart`: R1.2 and the `above` parameter, constant and `Stack` child of R1.4.
3. `duo_status_strip.dart`: R1.4.
4. `remote_page.dart`: the `above:` argument and import (R1.4) and the `_updateRect` hook (R1.3).
   No other line.
5. Tests below, and restore `a changed peer aspect relayouts the picture` in
   `duo_split_test.dart` from `d77b12c63` (note 11).

### Tests (delta)

| # | File | Name | Asserts |
|---|---|---|---|
| V1 | `duo_resolution_test.dart`; updates `the fit area ends at the band top in the laptop pose and picks 4:3` | `the fit area ends at the band top in the laptop pose; laptop picks 16:9, the rest 4:3` | the `book` case: area `Size(669, 455.5)` and `chooseDuoResolutionFullWidth(k4k, area)` -> 1280x720; the `open` + band, flat-without-band and cover lines keep `pick(k4k, area) == '800x600'` |
| V2 | `duo_resolution_test.dart`, new | `a full-width fit sends the lowest mode at least as wide as the area` | `DuoResolutionFit().tryFit(..., area: Size(669, 455.5), fullWidth: true, modes: k4k)` sends `['1280x720']`; `chooseDuoResolutionFullWidth` over `[1024x768, 800x600]` -> 800x600 (no mode that wide: the existing rule) |
| V3 | `duo_deck_test.dart`, new | `laptop, 16:9: the picture rests on the crease under the strip` (widget) | view 669x951, laptop geometry; `DuoSplitBody(aspect: () => a, aspectChanged: notifier, above: SizedBox.expand(key: strip), below: deck with rowExtent and one action, child: SizedBox.expand(key: picture))` with `a = 16 / 9`: picture rect `left 0`, `top` closeTo(79.19, 0.01), `width 669`, `height` closeTo(376.31, 0.01); strip rect `top 0`, `bottom` closeTo(79.19, 0.01); session row within 455.5-495.5; keyboard top closeTo(495.5, 1). Then `a = 4 / 3`, notify, pump: picture rect `Rect.fromLTWH(0, 0, 669, 455.5)` and the strip key `findsNothing` |
| V4 | `duo_status_strip_test.dart`, new file | `the strip shows name, delay and time, and leaves out what is missing` (widget) | `DuoStatusStrip(name: () => name, delay: () => delay, changed: notifier, now: () => DateTime(2026, 11, 22, 9, 5))` with both null: `find.text('09:05')`; set `name = 'm6'`, `delay = '23'`, notify, pump: `find.text('m6  ·  23 ms  ·  09:05')`; `delay = null`, notify, pump: `find.text('m6  ·  09:05')`. The test ends by pumping an empty widget, so a clock timer left running fails it |
| V5 | `duo_split_test.dart`, one line added to `duoCanvasHeight caps the height above the split only` | (same test) | in the laptop pose, `duoCanvasHeight(900, 0, view, aspect: 16 / 9)` closeTo(376.31, 0.01) |

Existing tests stay as they are: `laptop: the picture ends at the band top, whatever the aspect`
still holds (both edges 455.5), and no first-round expectation changes, because every existing
`DuoSplitBody` test in the laptop pose runs without an aspect (`pictureTop` 0).

Acceptance:

| Done-when | Evidence |
|---|---|
| D7 laptop picks 1280x720; flat and cover pick 800x600 | V1, V2 |
| D8 16:9 picture at `Rect(0, 79.19, 669, 376.31)`, strip above, row in the band, keyboard at 495.5; 4:3 picture 0-455.5 and no strip | V3 (canvas height: V5) |
| D9 strip text shows what is known and omits the rest | V4 |
| D10 report | results doc, from the picks table |
| D1-D5 | unchanged from the first round; the gate reruns them |

### Gate (replaces the two command lines above; preparation unchanged)

```
~/development/flutter/bin/flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_status_strip_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart test/cursor_size_test.dart test/floating_mouse_cursor_offset_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_split.dart lib/mobile/duo/duo_deck.dart lib/mobile/duo/duo_resolution.dart lib/mobile/duo/duo_status_strip.dart lib/mobile/pages/remote_page.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_resolution_test.dart test/duo_status_strip_test.dart
```

Pass criteria, baseline comparison for `analyze`, the `git status` check and the `project.pbxproj`
rule are as in "Gate" above. Red-first for the results doc: with the tests edited and the sources
at `5cca141fd`, V2-V4 fail to compile (`fullWidth`, `above`, `DuoStatusStrip`) and V1 and V5 fail
to compile or on values; record once.

### Regression surface (delta on `5cca141fd`)

| Existing file / runtime path | What changes | Why unavoidable |
|---|---|---|
| `DuoResolutionFit.tryFit` / `schedule`, laptop pose with a usable band | the mode comes from the full-width chooser: 1280x720 instead of 800x600 on the M6 | R6 |
| `tryFit` in every other pose, and every existing caller | none: `fullWidth` defaults to false and selects `chooseDuoResolution`, which is not edited | R6 |
| `duoSplitFrom`, laptop pose, aspect known and picture shorter than the area | the split carries `pictureTop = band.top - W / a`; edges unchanged | R7 |
| `duoSplitFrom`, every other case | none: `pictureTop` stays 0 | R9 |
| `DuoSplit` equality | also compares `pictureTop`; it differs only between laptop splits of different aspect, which `_onAspect` must see | R7 |
| `DuoSplitBody.build` | the picture child's `top` and `height` come from `duoPictureOffset`; 0 gives the base layout. With a strip, the child starts lower and the optional `above` widget is laid over the gap | R7, R8 |
| `CanvasModel.getSize()` through `duoCanvasHeight`, laptop pose with a strip | canvas height is `W / a` instead of `band.top - T`; elsewhere the expression gives the base value | R7 |
| `_KeyHelpToolsState._updateRect` (`remote_page.dart`) | the reported rect's y is reduced by the picture child's offset; 0 for every non-Duo session and every Duo case without a strip | R1.3: the rect's readers assume the body starts at the view's top |
| `_RemotePageState._duoSplit` | passes `above: DuoStatusStrip.forSession(...)`; the widget is mounted only while the strip shows | R8 |
| `QualityMonitorModel` | one more listener while the strip shows; nothing written | R8 |

Desktop, web, Android and non-Duo iOS: no path changes; `_updateRect` evaluates one pure
expression that returns 0.

### Spec ambiguities and notes for the captain (revision)

6. **Mouse hover with a strip.** `RawPointerMouseRegion.onPointerHover` passes the global
   position, so a hovering hardware pointer would map `pictureTop` too low in the laptop pose
   with a strip (it is already off by `T` at base on any phone with a top inset). The fix is to
   pass `evt.localPosition` less the safe-area inset there, in shared `remote_input.dart`, which
   desktop also runs; not planned. Touch, and mouse down / move / up, are right. Known limit
   unless the captain rules otherwise.
7. **R1.3 is a choice.** The `_updateRect` hook is three lines and adds no state, so the plan
   includes it; it touches one existing line of `remote_page.dart` outside `_duoSplit` and cannot
   be unit tested. Striking it leaves a known limit (soft keyboard open in the laptop pose with a
   strip: picture drawn `pictureTop - T` too low).
8. **Fit runs once, in the first pose.** A session that starts flat fits 800x600; folding to the
   laptop pose then shows 4:3 with side bars and no strip (R7's "otherwise" case), and a session
   that starts in the laptop pose keeps 1280x720 when opened flat (669x376 picture). R6 does not
   ask for a refit on a pose change, and one would need new state; not planned.
9. **Strip height.** R8 says the strip runs "from the top of the view"; the plan centres the line
   in `T .. pictureTop` so a top inset never covers it. Identical on the Duo (`T = 0`).
10. **R7 applies to any peer.** The spec does not limit it to macOS; any laptop-pose picture
    shorter than its area rests on the crease with a strip above.
11. **Dropped first-round test.** `5cca141fd` removed `a changed peer aspect relayouts the
    picture` from `duo_split_test.dart`; the first-round plan listed it as not edited, and it
    pins the listener R7 now depends on. The implementer restores it unchanged from `d77b12c63`
    (it passes on the candidate: flat pose, values 427.95 / 501.75 / 376.31).
12. **Delay source is read from code, not observed** (see facts). If D6 shows no delay on the
    Duo, the strip simply omits it; no code change is needed.
