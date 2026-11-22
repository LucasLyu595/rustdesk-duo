---
name: duo-picture-fills-to-deck-plan
description: "Plan for an aspect-aware Duo split (laptop picture down to the deck, flat picture at its aspect height), a crease strip that takes no touches, an aspect-free auto-fit area, and two thin hooks that pass the peer's display aspect in."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-picture-fills-to-deck
  modified: 2026-11-21
generated:
  by: claude/claude-fable-5-2
  session: 41af5e2b-05b0-47c6-837a-53ef33c5a4f0
  at: 2026-11-21T23:48:30-08:00
---

# Plan: the Duo picture fills its width down to the deck

Spec: `docs/dispatch-loop/duo-picture-fills-to-deck/spec.md`. Base `duo-mode` at `257b4d56a`.
Worktree `/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-picture-fills-to-deck`. Two
implementation tasks, run in order by one implementer.

## Files touched

| File | Change | Notes |
|---|---|---|
| `flutter/lib/mobile/duo/duo_split.dart` | edit | split rule, crease strip, fit area, aspect helper, `DuoSplitBody` listener |
| `flutter/lib/mobile/duo/duo_resolution.dart` | edit, 2 statements in `schedule` | area comes from the fit-area function |
| `flutter/lib/mobile/pages/remote_page.dart` | +2 lines, 0 modified | two named arguments in `_duoSplit` |
| `flutter/lib/models/model.dart` | 1 call modified | `aspect:` argument on the existing `duoCanvasHeight` call |
| `flutter/test/duo_split_test.dart` | edit | 4 tests added, 1 rewritten, 4 expectations updated |
| `flutter/test/duo_resolution_test.dart` | edit | 1 test added |

Nothing else: no Rust, no bridge, no `duo_fold.dart`, `duo_deck.dart`, keyboard or trackpad file,
no lang file, no pubspec, no `project.pbxproj`.

## Facts checked while planning (beyond the spec's)

- `DuoSplitBody` is the `Scaffold` body with no app bar (`remote_page.dart` ~556), so its top is
  view y = 0 and `MediaQuery.paddingOf(context).top` there equals the `padding.top` the canvas
  reads from `MediaQueryData.fromView` (`model.dart` ~2341). The `SafeArea` inside the picture
  child removes `T`, so a picture area of `pictureBottom` gives the canvas `W x (pictureBottom - T)`;
  the full-width picture bottom is therefore `T + W / a`, as the spec defines it.
- `_DuoSplitBodyState` caches `_split` and recomputes it in two places only:
  `didChangeDependencies` (view size) and `_onFold` (geometry). Nothing recomputes it when the
  peer's display changes; a hook is needed for R5.
- Every path that changes the shown display's shape runs `FfiModel.updateCurDisplay`
  (`model.dart` ~787), which, when the display rect changed, awaits
  `canvasModel.updateViewStyle()`; that calls `updateSize()` -> `getSize()` ->
  `duoCanvasHeight(...)` and then `CanvasModel.notifyListeners()` (~2444). Callers:
  `handleSwitchDisplay` (~850; the reply to a resolution change from auto-fit or the menu, after
  `_pi.displays[display] = newDisplay`), `handlePeerInfo` (~1434), `handleSyncPeerInfo`
  (~1687, ~1692) and `switchToNewDisplay` (~1785; the mobile display picker through
  `openMonitorInTheSameTab`, `common.dart` ~3455).
- `switchToNewDisplay` does **not** call `FfiModel.notifyListeners()`, and a peer with
  multi-UI-session support sends no switch-display reply. A `DuoSplitBody` that only rebuilt with
  `FfiModel` would keep the old layout after a display switch while the canvas already has the new
  size. `CanvasModel`'s notification is the one signal all four paths share, and it fires after the
  canvas size was computed from the new display info.
- `PeerInfo.tryGetDisplayIfNotAllDisplay()` (~4570) returns null for an empty display list and for
  the all-displays view; `Display.width/height` are pixels for a macOS peer, and the scale cancels
  in the ratio.
- `FFI.canvasModel` is `late final` (~4046), one object for the life of the global `gFFI`.
- The worktree has neither `flutter/.dart_tool` nor the gitignored
  `flutter/lib/generated_bridge.dart` and `generated_bridge.freezed.dart`. Tests that reach
  `models/model.dart` need both files (`duo_deck_test.dart` and `duo_resolution_test.dart` do today;
  `duo_split_test.dart` will after this unit). See "Gate".

## Decisions

### 1. Aspect source: an optional parameter, fed by one pure helper

Chosen: the split functions take `double? aspect` (and `paddingTop`) as optional named parameters
with defaults; one helper in the Duo module turns a `PeerInfo` into the aspect; the two callers
that already hold the session pass it in.

```dart
// duo_split.dart
double? duoPeerAspect(PeerInfo? pi)
DuoSplit? duoSplitFrom(DuoGeometry? geometry, Size viewSize,
    {required bool isDuo, double paddingTop = 0, double? aspect})
DuoSplit? currentDuoSplit(Size viewSize, {double paddingTop = 0, double? aspect})
double duoCanvasHeight(double h, double paddingTop, Size viewSize, {double? aspect})
```

`duoPeerAspect` returns `d.width / d.height` for
`d = pi?.tryGetDisplayIfNotAllDisplay()` (current display), and null when `pi` or `d` is null or
either side is not positive. `duo_split.dart` gains
`import '../../models/model.dart' show PeerInfo;` (`duo_deck.dart` and `duo_resolution.dart`
already import the model from this folder; `model.dart` already imports `duo_split.dart`, and Dart
allows the cycle).

Rejected: a helper inside `duo_split.dart` that reads the global `gFFI`. It would leave every
caller's text unchanged, but it hides a session lookup inside a function the tests call as pure,
makes `duoSplitFrom`'s result depend on something not in its arguments, and `CanvasModel` already
has its own session (`parent.target`), which is the correct one to read.

Against AGENTS.md:

- Thin hooks in shared files: `model.dart` changes one existing call (adds
  `aspect: duoPeerAspect(parent.target?.ffiModel.pi)`); `remote_page.dart` adds two argument
  lines. No import is added to either file.
- No placeholder forced on an unrelated caller: `_duoDeckActive` (`remote_page.dart` ~594) and the
  existing tests keep calling `currentDuoSplit(size)` / `duoSplitFrom(g, size, isDuo:)` unchanged.
  Whether a split exists never depends on `aspect` or `paddingTop`, so the null check there stays
  right.
- No new kind of state: the aspect is never stored. It is read from display info each time a split
  is computed.

### 2. R5: `DuoSplitBody` listens to the canvas, as it listens to the fold

`DuoSplitBody` gains two optional parameters:

```dart
/// The peer picture's width / height, or null when unknown.
final ValueGetter<double?>? aspect;

/// Notifies when [aspect] may have changed.
final Listenable? aspectChanged;
```

`_DuoSplitBodyState`:

- `initState` adds `widget.aspectChanged?.addListener(_onAspect)` beside the fold listener;
  `dispose` removes it; `didUpdateWidget` moves the listener when the `Listenable` object differs
  (the page rebuilds with a new `DuoSplitBody` each time; the canvas model is the same object, so
  this is a no-op in the app and is there for correctness).
- One private `DuoSplit? _current()` returns
  `currentDuoSplit(_view!, paddingTop: _top, aspect: widget.aspect?.call())`.
  `didChangeDependencies` stores `_top = MediaQuery.paddingOf(context).top` beside `_view` and uses
  `_current()`; `_onFold` uses `_current()`.
- `void _onAspect()`: `final split = _current(); if (split != _split) setState(() => _split = split);`
  It does **not** call `onFoldChanged`: the canvas has just resized itself (that is what sent the
  notification), and calling `canvasModel.updateViewStyle()` again would only cause one more
  round.

`_top` is a cached `MediaQuery` value of the same kind as the existing `_view`; the listener is
the same kind as the existing fold listener. No timer, post-frame callback or cache of the aspect
is added.

Hook in `remote_page.dart`, inside the existing `_duoSplit` expression, two added lines:

```dart
aspect: () => duoPeerAspect(gFFI.ffiModel.pi),
aspectChanged: gFFI.canvasModel,
```

Why the canvas model and not `Provider.of<FfiModel>`: see the facts above; `FfiModel` does not
notify on the mobile display switch. The canvas model also notifies on pan and zoom; the listener
then does a few float operations and no `setState` because the split is equal.

Order of events on a mode change (auto-fit or menu): the peer replies with switch-display ->
`handleSwitchDisplay` stores the new display -> `updateCurDisplay` -> `updateViewStyle` ->
`getSize()` computes the canvas height from the new aspect -> `CanvasModel.notifyListeners()` ->
`_onAspect` computes the same split from the same inputs -> one `setState`. Layout and canvas
agree in the same turn. A change that leaves the display rect equal sends nothing, and the aspect
is equal too.

### 3. R2: the crease strip is part of the split

`DuoSplit` gains an optional field:

```dart
const DuoSplit({required this.pictureBottom, required this.deckTop, this.crease});

/// The strip of the picture that takes no touches, in the laptop pose.
final Rect? crease;
```

included in `==` and `hashCode`. `duoSplitFrom` sets it to the band in the laptop pose only.
Putting it in the split (rather than reading the pose in `build`) keeps `_split` the single thing
the state compares: laptop -> flat with a 4:3 picture leaves both edges at 501.75, and the strip
must still go away; with the field in `==` that change is seen by the existing `_onFold`
comparison.

`build` adds one child to the `Stack`, between the picture and the deck:

```dart
if (split?.crease != null)
  Positioned.fromRect(rect: split!.crease!, child: const AbsorbPointer()),
```

A childless `AbsorbPointer` takes its tight size, paints nothing, and reports a hit inside its
box, so `Stack` hit testing stops there and never reaches the picture child below it
(`RawTouchGestureDetectorRegion`, `RawPointerMouseRegion` and the mouse region are all found by
hit test). The picture stays visible through it. It blocks the band rect exactly; when the deck
gives up to 12 pt, the sliver between `band.bottom` and `pictureBottom` is ordinary picture.

### 4. The split rule

`kDuoPictureFraction` stays. New constants:

```dart
/// How far the deck may give way so a laptop-pose picture fills the width.
const double kDuoDeckGive = 12;

/// The largest share of a flat inner view the picture may take.
const double kDuoFlatPictureFraction = 0.6;
```

A private `Rect? _usableBand(DuoGeometry? geometry, Size viewSize)` carries today's five checks
unchanged (non-null, non-empty, wider than tall, `top > 0`, `bottom < H`), shared by the split and
the fit area.

`duoSplitFrom`, in order (`full = paddingTop + W / aspect` when `aspect` is known):

1. `!isDuo` or `W >= H` -> null (unchanged line).
2. `band` usable and `laptopFoldFrom(geometry) != null` -> `y = full` when
   `band.bottom < full <= band.bottom + kDuoDeckGive`, else `y = band.bottom`;
   `DuoSplit(pictureBottom: y, deckTop: y, crease: band)`. (R1, R2)
3. `geometry.screen == DuoScreen.inner`, `laptopFoldFrom(geometry) == null`, aspect known ->
   `y = min(full, kDuoFlatPictureFraction * H)`; `DuoSplit(pictureBottom: y, deckTop: y)`. (R3)
4. `band` usable -> `DuoSplit(pictureBottom: band.top, deckTop: band.bottom)` (today's rule:
   flat with unknown aspect, cover with a band). (R3, R4)
5. else `0.45 * H` for both (today's rule). (R3, R4)

A laptop pose whose band fails the usable checks matches neither 2 nor 3 and keeps today's
0.45 rule (see "Spec ambiguities").

`duoCanvasHeight` forwards `paddingTop` and `aspect` to `currentDuoSplit`; its return expression
is unchanged.

### 5. R6: the fit area

```dart
/// The picture area auto-fit aims at; it does not depend on the peer's picture.
Size? duoFitAreaFrom(DuoGeometry? geometry, Size viewSize,
    {required bool isDuo, double paddingTop = 0})
Size? currentDuoFitArea(Size viewSize, {double paddingTop = 0})
```

- `split = duoSplitFrom(geometry, viewSize, isDuo: isDuo)` (aspect unknown, so no loop); null ->
  null.
- `geometry.screen == DuoScreen.inner` and `_usableBand` non-null (laptop or flat) ->
  `Size(W, band.bottom - paddingTop)`.
- `geometry.screen == DuoScreen.inner`, not the laptop pose, no usable band ->
  `Size(W, 0.6 * H - paddingTop)` (the flat cap; captain amendment at plan review, spec R6).
- else `Size(W, split.pictureBottom - paddingTop)`: exactly today's area (cover, and the laptop pose
  with an unusable band).

`currentDuoFitArea` mirrors `currentDuoSplit` (`DuoFold.instance`).

In `DuoResolutionFit.schedule` (`duo_resolution.dart` ~75-83) the `final split = ...` statement
goes and the `area:` argument becomes
`currentDuoFitArea(media.size, paddingTop: media.padding.top)`. Nothing else in that file changes;
`tryFit` and `chooseDuoResolution` are untouched.

## Auto-fit picks (computed from `chooseDuoResolution`'s rule)

Mode list: 3840x2160, 3360x1890, 3008x1692, 2560x1440, 1920x1080, 1600x900, 1280x720 (16:9) and
1024x768, 800x600 (4:3). Distance is `|ln(mode aspect / area aspect)|`; the lowest mode within
0.02 of the best wins. `T = 0`.

| Pose | Fit area | Area aspect | Distance 4:3 | Distance 16:9 | Pick | Split after the pick | Notes |
|---|---|---|---|---|---|---|---|
| Laptop, 669x951, band 455.5-495.5 | 669x495.5 | 1.350 | 0.013 | 0.275 | 800x600 | 501.75 for both edges | deck gives 6.25 pt; picture exactly 669x501.75, no bars |
| Flat with band, 669x951 | 669x495.5 | 1.350 | 0.013 | 0.275 | 800x600 | 501.75 for both edges | picture exactly 669x501.75 |
| Flat without band, 669x951 | 669x570.6 | 1.172 | 0.129 | 0.416 | 800x600 | 501.75 for both edges | picture exactly 669x501.75 (captain amendment, spec R6) |
| Cover, 466x678 | 466x305.1 | 1.527 | 0.136 | 0.152 | 800x600 | 305.1 (unchanged rule) | picture 406.8x305.1, 29.6 pt bars each side, as the cover behaves today |

The fit still runs once per session, in the pose the deck first shows in. The implementer copies
this table into the results doc, with the laptop, flat-with-band, flat-without-band and cover rows
confirmed by the test in task 2.

## Tasks

### Task 1: split, crease strip, live aspect

Owned files: `flutter/lib/mobile/duo/duo_split.dart`, `flutter/lib/models/model.dart`,
`flutter/lib/mobile/pages/remote_page.dart`, `flutter/test/duo_split_test.dart`.

1. `duo_split.dart`: decisions 1-4 (import, `DuoSplit.crease`, constants, `_usableBand`,
   `duoPeerAspect`, `duoSplitFrom`, `currentDuoSplit`, `duoCanvasHeight`, `DuoSplitBody` parameters,
   state listener, `_top`, the `AbsorbPointer` child). `import 'dart:math';` already covers `min`.
2. `model.dart` ~2373: the call becomes
   `h = duoCanvasHeight(h, mediaData.padding.top, size, aspect: duoPeerAspect(parent.target?.ffiModel.pi));`
   (formatted as `dart format` leaves it). No other line.
3. `remote_page.dart` `_duoSplit`: the two argument lines of decision 2. No other line.
4. Tests in `duo_split_test.dart`, listed below.

### Task 2: auto-fit area

Owned files: `flutter/lib/mobile/duo/duo_split.dart` (the two fit-area functions only),
`flutter/lib/mobile/duo/duo_resolution.dart`, `flutter/test/duo_resolution_test.dart`.

1. `duo_split.dart`: `duoFitAreaFrom`, `currentDuoFitArea` (decision 5).
2. `duo_resolution.dart` `schedule`: the two-statement change of decision 5.
3. One test in `duo_resolution_test.dart`, listed below.

## Tests

New tests, five in all:

| # | File | Name | Asserts |
|---|---|---|---|
| N1 | `duo_split_test.dart`, group `duoSplitFrom` | `laptop: the picture runs to the band, or to full width within the deck give` | `_geo()`, 669x951: `aspect: 4 / 3` -> `pictureBottom == deckTop == 501.75`; `16 / 9` -> 495.5 for both; no aspect -> 495.5 for both; `aspect: 1.3` (full-width bottom 514.6, beyond the 12 pt) -> 495.5 for both |
| N2 | same group, replaces `a band in portrait splits at the band, in any posture` | `flat: the picture takes its aspect height, capped at 0.6 of the view` | for `_flat()` and for open + inner + `_band`: `4 / 3` -> 501.75 for both edges; `1.0` -> 570.6 (closeTo); no aspect -> `DuoSplit(pictureBottom: 455.5, deckTop: 495.5)` with the band and 427.95 without |
| N3 | `duo_split_test.dart` | `laptop: a touch in the crease band does not reach the picture` (widget) | child is an opaque `GestureDetector` counting taps, `aspect: () => 4 / 3`. Laptop: `tapAt(Offset(300, 475))` -> 0 taps, `tapAt(Offset(300, 450))` -> 1. Then `DuoFold.instance.update` to open + inner + `_band`, pump: `tapAt(Offset(300, 475))` -> 2 (flat adds no block) |
| N4 | `duo_split_test.dart` | `a changed peer aspect relayouts the picture` (widget) | `_flat()`, `aspect: () => a` over a local variable, `aspectChanged:` a `ChangeNotifier` owned by the test. `a = null` -> child height 427.95; set `a = 4 / 3`, notify, pump -> 501.75; `a = 16 / 9`, notify, pump -> closeTo 376.31; `onFoldChanged` count stays 0 |
| N5 | `duo_resolution_test.dart` | `the fit area follows the band on the inner screen and picks 4:3` | `duoFitAreaFrom` at 669x951 for laptop and for open + inner + band -> `Size(669, 495.5)`, and `pick(k4k, area)` -> `800x600`; inner (open posture) without band -> height closeTo 570.6 and `800x600`; `duoFitAreaFrom(null, Size(466, 678), isDuo: true)` -> height closeTo 305.1 and `800x600`; `isDuo: false` -> null |

Existing expectations updated, only where they encode the old laptop values (each fails on the
new code for the reason given):

| Test | Line(s) | Old | New | Why |
|---|---|---|---|---|
| `fold set: child above the fold, placeholder below it` | ~52 | child `0,0,669,455.5` | `0,0,669,495.5` | laptop picture now runs to the band bottom; placeholder rect unchanged |
| `switching the fold relayouts live and keeps the child state` | ~104 | 455.5 | 495.5 | same; the flat step (427.95, unknown aspect) and all `changes` counts are unchanged |
| `body shorter than the split: no overflow, no placeholder` | ~144 | `h == 480 ? 455.5 : h` | `h` | a 480 pt body is now shorter than the 495.5 picture area, so the child fills it |
| `duoCanvasHeight caps the height above the split only` | ~210 | 405.5 | 445.5 | 495.5 - 50 |

`duo_deck_test.dart`, `duo_fold_test.dart`, `duo_keyboard_test.dart`, `duo_trackpad_test.dart` and
the seven existing `duo_resolution_test.dart` tests need no edit (the deck test's laptop case
asserts `kb.top >= band.bottom`, still true at 495.5).

No test for the two shared-file hooks or for `schedule`: either would need a live `FFI` or a
test-only seam in production code, which AGENTS.md rules out. They are covered by the diff (one
call each) and by D7 on the device.

## Acceptance -> tests

| Done-when | Evidence |
|---|---|
| D1 laptop values | N1 |
| D2 band takes no touch, just above does | N3 |
| D3 flat values, unknown aspect keeps today's split | N2 |
| D4 cover, landscape, non-Duo unchanged | existing `no usable band falls back to 0.45 of the view`, `landscape and non-Duo give none`, `the latch keeps the cover split`, `no fold: child fills the body, no placeholder`, the cover and landscape lines of `duoCanvasHeight caps...`, and `duo_deck_test.dart` `no fold: no deck`, all unedited apart from the four values in the table above |
| D5 fit area and pick | N5 |
| D6 focused gate | commands under "Gate" |
| D7 on the Duo | captain, after merge and reinstall; not part of this gate |
| R5 (no D-number) | N4, plus the event trace in decision 2 |

## Gate

Preparation, once, in the worktree (none of it is committed):

1. `cp /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.dart /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.freezed.dart flutter/lib/`
   The files are gitignored and absent from the worktree; the tests cannot compile without them.
   This is a copy of the main checkout's files, not a codegen run. If the main checkout lacks
   them, stop and report; do not run `flutter_rust_bridge_codegen`.
2. From `flutter/`: `~/development/flutter/bin/flutter pub get` (the worktree has no
   `flutter/.dart_tool`). If it changes a tracked file (for example `pubspec.lock`), restore that
   file with `git checkout -- <file>` and say so in the results doc.

Focused and closing gate, from `flutter/` (the same commands both times):

```
~/development/flutter/bin/flutter test test/duo_split_test.dart test/duo_resolution_test.dart test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_split.dart lib/mobile/duo/duo_resolution.dart lib/mobile/pages/remote_page.dart lib/models/model.dart
```

Pass: every test passes; `analyze` reports no issue in the two Duo files and no issue in
`remote_page.dart` or `model.dart` that the base does not have. For the baseline, run the same
`analyze` line once in the main checkout `/Users/lucas/rustdesk-duo/flutter` (branch `duo-mode`
at the base commit, read-only) and compare the issue lists.

Red-first check for the results doc: before the `duo_split.dart` change, N1-N3 and N5 fail to
compile or fail (new parameters, new function); record that once, do not keep a failing commit.

This unit touches nothing under `scripts/tests/`; this repository has no scratch-git or
selftest-coverage lint, so none joins the gate. `git status --short` before each commit must show
only the six files above (plus this unit's docs); `flutter/ios/Runner.xcodeproj/project.pbxproj`
is never staged. Stage explicit paths.

## Regression surface

| Existing file / runtime path | What changes | Why unavoidable |
|---|---|---|
| `duo_split.dart` `duoSplitFrom`, Duo latched, portrait, laptop pose | picture bottom moves from `band.top` to `band.bottom` (or up to 12 pt lower); deck top equals it; the split carries the band as `crease` | R1, R2 |
| same, inner screen, not laptop, aspect known | picture bottom becomes `min(T + W / a, 0.6 H)` instead of band top or 0.45 H; the deck starts there and, when a band is reported, runs across it | R3 |
| same, every other case (aspect unknown outside the laptop pose, cover, laptop with an unusable band) | none: steps 4 and 5 are today's code | R3, R4 |
| `duoSplitFrom` / `currentDuoSplit` for a non-Duo or a landscape view | none: the first line still returns null before anything new runs | R4 |
| `DuoSplitBody` layout and hit testing | in the laptop pose an invisible `AbsorbPointer` covers the band; the state also listens to `aspectChanged` and reads `padding.top` | R2, R5 |
| `DuoSplitBody` without a split (non-Duo, landscape) | the child still fills the body; one more listener on the canvas model whose callback computes null == null and does nothing | R5 needs the listener attached before a split exists (a fold can appear later) |
| `CanvasModel.getSize()` (`model.dart`), all mobile sessions | evaluates `duoPeerAspect(...)` (reads the current display's size, no side effect) and passes it on; the result is used only when a Duo split exists, otherwise `duoCanvasHeight` returns `h` as today | R5: the canvas must use the same split as the layout, and it is the caller that owns the session |
| `CanvasModel.getSize()` on a Duo in portrait | canvas height follows the new picture bottom | R1, R3 |
| `_RemotePageState._duoSplit` (`remote_page.dart`) | passes the aspect getter and the canvas model to `DuoSplitBody`; nothing else in the page changes; `_duoDeckActive` is untouched | R5 |
| `DuoResolutionFit.schedule` | the fit area is `W x (band.bottom - T)` on the inner screen with a band (was `band.top - T`); elsewhere identical | R6 |
| `DuoSplit` equality | two splits with equal edges and different `crease` are now unequal, so `onFoldChanged` also fires on laptop <-> flat when the edges happen to match (one extra `updateViewStyle` and page `setState`) | R2: the strip must appear and disappear with the pose |

Desktop, web, Android and non-Duo iOS: `getSize()` evaluates one extra pure expression inside its
existing `isMobile` branch and gets the same result as before; no other path is reached.

## Spec ambiguities (not changed; chosen reading stated)

1. **Laptop pose with an unusable band.** R1 needs a usable band, R3 says "not the laptop pose",
   R4 says "not inner". A half-folded inner screen whose band fails the checks fits none. Plan:
   today's rule (0.45), the most conservative reading; it changes nothing for that case.
2. **Flat without a band picks 16:9.** R6 keeps "today's area" there (669x427.95), which is nearer
   16:9, so auto-fit picks 1280x720 and the flat picture is 669x376, not the 669x502 the intent
   describes for 4:3. With a band reported while flat, the pick is 800x600 and the picture is
   669x502. Whether the Duo reports a band when open flat decides which one Lucas sees; D7 shows it.
   **Captain ruling at plan review:** R6 amended; flat without a band uses `Size(W, 0.6 H - T)`
   and picks 800x600 (decision 5, auto-fit table, N5 updated).
3. **"As they follow a fold change today" (R5).** A fold change also calls `onFoldChanged`
   (canvas `updateViewStyle` plus a page `setState`). For an aspect change the plan relayouts
   `DuoSplitBody` only, because the canvas resize is what sends the notification. The outcome the
   spec asks for (split, layout and canvas follow) holds.
4. **Crease rect after the deck gives.** R2 names "the band rect"; the up-to-12 pt sliver between
   `band.bottom` and the picture bottom stays touchable picture.
5. **Frontmatter status.** The plan-stage template says `draft`; the captain's task prompt for this
   unit asks for `stable`. The plan carries `stable` as instructed.
