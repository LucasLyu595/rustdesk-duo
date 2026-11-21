---
name: duo-deck-default-portrait-plan
description: "Plan to show the iPhone Duo keyboard and trackpad deck under the picture in every portrait pose, hide RustDesk's bottom bar while it shows, and move the bar's session actions onto a slim deck row."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-deck-default-portrait
  modified: 2026-11-21
generated:
  by: claude/claude-fable-5-2
  session: c1457871-3d7f-4483-a59f-623ec1426450
  at: 2026-11-21T05:17:48-08:00
---

# Plan: Duo deck by default in portrait, original bar hidden

Spec: `docs/dispatch-loop/duo-deck-default-portrait/spec.md` (stable). Base: `duo-mode` at
`733433c0f`. All paths below are relative to the worktree
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-deck-default-portrait`.

## Approach

Today the split hangs off `DuoFold.laptop` (inner screen + book posture + horizontal band).
The plan replaces that dependency with one pure function that turns *(latest geometry, "is a
Duo" latch, view size)* into an optional `DuoSplit` (where the picture ends and where the deck
starts). Three readers use it through one helper, `currentDuoSplit(viewSize)`:

1. `DuoSplitBody` lays the child and the deck out from it.
2. `duoCanvasHeight` caps the canvas from it.
3. `remote_page.dart` asks "is there a split?" to hide the bar and the bar-toggle FAB.

The bar's session actions are repeated in a new private method of `remote_page.dart` and shown
by `DuoDeck` as a 32 pt row above the keyboard. `DuoFold.laptop` and `laptopFoldFrom` stay
untouched for the debug overlay.

## Files touched

| File | Kind | Change |
| --- | --- | --- |
| `flutter/lib/mobile/duo/duo_fold.dart` | Duo-only | "Is a Duo" latch on `DuoFold`, set in `update`; `@visibleForTesting reset()` |
| `flutter/lib/mobile/duo/duo_split.dart` | Duo-only | `DuoSplit`, `duoSplitFrom`, `currentDuoSplit`; `DuoSplitBody` driven by the split; `duoCanvasHeight` gets the view size |
| `flutter/lib/mobile/duo/duo_deck.dart` | Duo-only | Optional `actions` row; `DuoDeckAction` button widget; `forSession` forwards `actions` |
| `flutter/lib/mobile/pages/remote_page.dart` | Shared (thin hooks) | Split-active getter; two edited conditions; `_duoSplit` passes actions and calls `setState`; new `_duoDeckActions` |
| `flutter/lib/models/model.dart` | Shared (one line) | `duoCanvasHeight(h, mediaData.padding.top, size)` |
| `flutter/test/duo_fold_test.dart` | Test | Latch tests; `tearDown` reset |
| `flutter/test/duo_split_test.dart` | Test | Split-rule tests; updated layout, live-change and canvas tests |
| `flutter/test/duo_deck_test.dart` | Test | Session-row tests; `tearDown` reset; overflow heights |

Not touched: `duo_keyboard.dart`, `duo_trackpad.dart`, `duo_fold_debug_overlay.dart`,
`getBottomAppBar`, `pubspec.yaml`, `flutter/ios/Runner.xcodeproj/project.pbxproj`, any
generated bridge file.

## Design decisions (the three points to settle)

### A. Reporting split changes without calling `onFoldChanged` during build

`_DuoSplitBodyState` keeps `DuoSplit? _split` and has two entry points, neither in `build`:

- **Geometry**: a listener on `DuoFold.instance.geometry` (replacing the `laptop` listener).
  It runs from the plugin's stream event, outside any build, exactly as today's `_onFold`:
  recompute, return if equal, else `setState` and call `widget.onFoldChanged` directly.
- **View size**: `didChangeDependencies`, which Flutter calls at mount and whenever
  `MediaQuery.sizeOf(context)` changes. It recomputes and stores `_split` (no `setState`
  needed, a build follows). At mount it does not notify (the callback's "not at mount"
  contract stays). On a later change it defers the callback with
  `WidgetsBinding.instance.addPostFrameCallback`, guarded by `mounted`.

This is the simplest safe option: no `LayoutBuilder`-time callback, no timer, no new notifier.
The only new state is one `bool _mounted`-style "first run" flag (or a nullable sentinel) in
the State. In widget tests the post-frame callback runs inside the same `tester.pump()`.

The split is computed from the `MediaQuery` size (the band is in view coordinates, and the
Scaffold body starts at y = 0). The existing `LayoutBuilder` stays only for the clamps against
the real body height, which is shorter than the view when the soft keyboard or the gesture
help panel takes the bottom.

### B. How `remote_page` learns the split is active and rebuilds

A one-line private getter on the page State:

```dart
bool get _duoDeckActive => currentDuoSplit(MediaQuery.sizeOf(context)) != null;
```

Read once in `build` (which registers the `MediaQuery` size dependency the spec asks for) and
once in `_bottomWidget`. Geometry changes reach the page through `onFoldChanged`, which now
also calls `setState`. Off a Duo the getter is always false, so both edited conditions reduce
to upstream's expressions.

### C. Latch reset and test isolation

`DuoFold.reset()` (`@visibleForTesting`) clears the latch and sets `geometry` and `laptop`
back to null. All three test files replace their `tearDown` with
`tearDown(DuoFold.instance.reset)`. The old tearDown pushed a flat inner geometry, which
would now *set* the latch and leave a 0.45 split behind for the next test. `flutter test` runs
each file in its own isolate, so only in-file leakage matters.

## Tasks

### Task 1: latch and reset (`flutter/lib/mobile/duo/duo_fold.dart`)

Additive only, inside `DuoFold`:

```dart
/// True once any report showed the inner screen or a hinge angle; never cleared in an app run.
bool get isDuo => _isDuo;
bool _isDuo = false;

@visibleForTesting
void reset() {
  _isDuo = false;
  geometry.value = null;
  laptop.value = null;
}
```

In `update`, add one line **before** `geometry.value = next` so listeners see the latch:

```dart
if (next.screen == DuoScreen.inner || next.hingeAngle != null) _isDuo = true;
```

Update the file header comment's "stays null, so RustDesk behaves exactly as upstream" only if
it becomes false; it stays true (no report → no latch → no split), so leave it.

### Task 2: the split (`flutter/lib/mobile/duo/duo_split.dart`)

New, above `DuoSplitBody`:

```dart
/// Where the remote picture ends and the deck starts, from the top of the view.
@immutable
class DuoSplit {
  const DuoSplit({required this.pictureBottom, required this.deckTop});
  final double pictureBottom;
  final double deckTop;
  // == and hashCode over both fields
}

/// The fraction of a portrait view given to the picture when the fold reports no usable band.
const double kDuoPictureFraction = 0.45;

DuoSplit? duoSplitFrom(DuoGeometry? geometry, Size viewSize, {required bool isDuo});

DuoSplit? currentDuoSplit(Size viewSize) => duoSplitFrom(
    DuoFold.instance.geometry.value, viewSize, isDuo: DuoFold.instance.isDuo);
```

`duoSplitFrom` rules, in order:

1. `!isDuo` → null.
2. `viewSize.width >= viewSize.height` → null.
3. `band = geometry?.hinge`; usable when non-null, `!band.isEmpty`, `band.width > band.height`,
   `band.top > 0`, `band.bottom < viewSize.height` → `DuoSplit(band.top, band.bottom)`.
4. Otherwise → `DuoSplit(0.45 * h, 0.45 * h)`.

`duo_split.dart` gains `import 'package:duo_display/duo_display.dart';` for `DuoGeometry`
(already a dependency).

`_DuoSplitBodyState` changes (this is the unit's own file from the previous unit, so editing
existing lines is in scope):

- `Rect? _band` → `DuoSplit? _split`, first set in `didChangeDependencies`.
- Listener moves from `DuoFold.instance.laptop` to `DuoFold.instance.geometry`; body per §A.
- `didChangeDependencies` per §A.
- `build`: child height `split == null ? height : min(split.pictureBottom, height)`; the
  below widget shows when `split != null && height > split.deckTop`, positioned at
  `top: split.deckTop`. Structure (ColoredBox → LayoutBuilder → Stack with the child always
  the first `Positioned`) is unchanged, which is what keeps the child's State.
- Doc comments on the class, `below` and `onFoldChanged` reworded from "fold/band" to "split".

`duoCanvasHeight`:

```dart
/// The canvas height to use: [h] without a split, else capped to the picture area.
double duoCanvasHeight(double h, double paddingTop, Size viewSize) {
  final split = currentDuoSplit(viewSize);
  if (split == null) return h;
  return max(0, min(h, split.pictureBottom - paddingTop));
}
```

### Task 3: session row (`flutter/lib/mobile/duo/duo_deck.dart`)

- `DuoDeck` gets `final List<Widget> actions;` (constructor default `const []`).
  `DuoDeck.forSession(FFI ffi, {List<Widget> actions = const []})` forwards it.
- New public widget, so the styling lives in `duo/` and `remote_page` only supplies icon and
  handler:

  ```dart
  class DuoDeckAction extends StatelessWidget {
    const DuoDeckAction({super.key, required this.icon, required this.onPressed});
    final Widget icon;
    final VoidCallback? onPressed;
    // IconButton: white, iconSize 20, padding zero,
    // constraints BoxConstraints.tightFor(width: 40, height: 32)
  }
  ```

- `build`: `const _sessionRowH = 32.0`. Inside the existing `LayoutBuilder`:
  `final showRow = actions.isNotEmpty && constraints.maxHeight >= 60;`
  `final top = showRow ? _sessionRowH + 6 : 0.0;`
  `rowH = (((constraints.maxHeight - top) * 0.6 - 16) / 5).clamp(0.0, 46.0)`.
  Column children gain, first and only when `showRow`, a
  `SizedBox(key: Key('duo-session-row'), height: 32, child: Row(mainAxisAlignment: spaceEvenly, children: actions))`
  and a 6 pt gap. With `actions` empty, `top` is 0 and the Column is exactly today's.
- The `maxHeight >= 60` guard (stateless, one condition) exists because the iOS soft keyboard
  shrinks the Scaffold body: on the cover screen the deck can drop to roughly 75 to 110 pt, and
  below 60 pt of inner height the fixed parts (32 + 6 + 16 + 6) would overflow. Under 60 the
  row is left out and the deck lays out as today. The FAB that closes the soft keyboard is
  still shown by upstream's rule, so nothing becomes unreachable.
- Sizes: six 40 pt buttons need 240 pt; the cover deck is about 454 pt wide inside padding.
  At 373 pt the keyboard rows come to about 35 pt and the trackpad to about 123 pt; at 455 pt
  about 45 pt and 138 pt.

`DuoDeckInput`, the keyboard and the trackpad are not touched.

### Task 4: hooks in `flutter/lib/mobile/pages/remote_page.dart`

Edited existing lines (each minimal, each a no-op when there is no split):

1. `_bottomWidget`: `_showBar && gFFI...` → `_showBar && !_duoDeckActive && gFFI...`.
   The gesture-help branch is untouched, so the panel still shows in the bottom slot.
2. `build`: `!_showBar || keyboardIsVisible || _showGestureHelp` →
   `(!_showBar && !_duoDeckActive) || keyboardIsVisible || _showGestureHelp`.
   The FAB's `onPressed` is untouched: its `_showBar` branch is unreachable while the split is
   active because the FAB then only exists for the keyboard or the help panel.
3. `_duoSplit`:

   ```dart
   Widget _duoSplit(Widget child) => DuoSplitBody(
       onFoldChanged: () {
         gFFI.canvasModel.updateViewStyle();
         if (mounted) setState(() {});
       },
       below: Builder(
           builder: (context) =>
               DuoDeck.forSession(gFFI, actions: _duoDeckActions(context))),
       child: child);
   ```

   The `Builder` keeps `_duoDeckActions` (and its `Provider.of<FfiModel>` lookup) from running
   at all unless the deck is actually mounted, so nothing new executes off a Duo.

Added (new lines only): the `_duoDeckActive` getter from §B and

```dart
List<Widget> _duoDeckActions(BuildContext context)
```

which repeats the bar's conditions and handlers, in the bar's order, as `DuoDeckAction`s:

| Action | Condition (copied from `getBottomAppBar`) | Handler |
| --- | --- | --- |
| `Icons.clear` | always | `clientClose(sessionId, gFFI)` |
| `Icons.tv` | always | `setState(() => _showEdit = false); showOptions(this.context, widget.id, gFFI.dialogManager)` |
| `Icons.keyboard` | `!(isWebDesktop \|\| ffiModel.viewOnly \|\| !ffiModel.keyboard)` | `openKeyboard` |
| `Icons.build` | same, and `gFFI.ffiModel.isPeerAndroid` | `gFFI.dialogManager.toggleMobileActionsOverlay(ffi: gFFI)` |
| `Icons.touch_app` / `Icons.mouse` by `gFFI.ffiModel.touchMode` | same, and not Android peer | `setState(() => _showGestureHelp = !_showGestureHelp)` |
| chat | `!isWeb`; inside the same `futureBuilder(... "KEY_IS_SUPPORT_VOICE_CALL")`, same icon and same `showChatOptions` / `onPressedTextChat` choice | as the bar |
| `Icons.more_vert` | always | `setState(() => _showEdit = false); showActions(widget.id)` |

`ffiModel` is `Provider.of<FfiModel>(context)` as in the bar. No "hide bar" action.
`getBottomAppBar`, the two `emptyOverlay` entries and the rest of `build` are not modified.
No import changes are needed (`duo_deck.dart` and `duo_split.dart` are already imported).

### Task 5: `flutter/lib/models/model.dart`

One line in `CanvasModel.getSize`:
`h = duoCanvasHeight(h, mediaData.padding.top, size);` (`size` is the local `mediaData.size`).

### Task 6: tests

`flutter/test/duo_fold_test.dart`
- Add `tearDown(DuoFold.instance.reset)`.
- New test "the Duo latch": false after `reset`; stays false for a geometry with
  `screen: unknown`, `hingeAngle: null`; true after an inner geometry; still true after a
  following outer/closed/no-angle geometry; true for an outer geometry with a hinge angle.
- Existing tests unchanged.

`flutter/test/duo_split_test.dart`
- `tearDown` → `DuoFold.instance.reset`.
- New group `duoSplitFrom` (pure, Done-when 1), two or three tests covering: laptop band on
  669x951 → (455.5, 495.5); flat (`open`) with the same band → same; cover (outer, closed, no
  hinge) on 466x678 → both at 305.1 (`closeTo`); band unusable (vertical band, `Rect.zero`,
  band bottom beyond the view) → 0.45; landscape 951x669 → null; `isDuo: false` → null.
- New test "the latch keeps the cover split" through `DuoFold.update` + `currentDuoSplit`:
  unknown-screen/no-angle geometry → null; inner geometry then outer/closed → 0.45 split.
- "fold set: child above…", "fold set with below…", "no fold: child fills…": unchanged
  (they still hold: the first two latch through the inner geometry, the third has none).
- "switching the fold relayouts live…": updated. After the 80° step (still 1 change),
  `update(_flat())` now gives the 0.45 split: child height `closeTo(427.95)`, placeholder
  present, `changes == 2`. Then set the view to 951x669 and pump: child height 669, no
  placeholder, `changes == 3` (the view-size path of §A). Same State object at the end.
- "body shorter than the fold…": rewritten to keep what it pins (the body-height clamps):
  view 669x951 with the laptop band, `DuoSplitBody` inside a top-aligned `SizedBox` of height
  480 then 400 → no exception, no placeholder, child height 455.5 then 400.
- "duoCanvasHeight…": pass `const Size(669, 951)`; same four expectations; add the cover case
  (`update` outer/closed after the latch, `Size(466, 678)`, `duoCanvasHeight(900, 50, …)` →
  `closeTo(255.1)`) and landscape → unchanged `h`.

`flutter/test/duo_deck_test.dart`
- `tearDown` → `DuoFold.instance.reset`.
- New test "session actions: row above the keyboard, actions fire": deck with two
  `DuoDeckAction`s in a 466x373 box; `duo-session-row` bottom <= keyboard top; tapping each
  icon calls its handler.
- New test "no actions: no session row" (`find.byKey('duo-session-row')` finds nothing and
  the keyboard top equals the 6 pt padding, as before).
- Overflow loop: add 373 to the heights; add a second loop with actions at 60, 80, 373, 455.
- Existing two `DuoSplitBody` tests unchanged.

Test diff stays proportionate: about 8 new tests and 3 edited ones against roughly 150 lines
of non-test change. No test infrastructure, no test-only hooks beyond the spec's `reset`.
`remote_page.dart` gets no widget test (it needs the FFI); Done-when 5 is by inspection and
on device, as the spec says.

## Done-when mapping

| # | Done-when | Task | Evidence |
| --- | --- | --- | --- |
| 1 | Split rules incl. latch | 1, 2 | `duoSplitFrom` group, "latch keeps the cover split", "the Duo latch" |
| 2 | `DuoSplitBody` layout, live relayout on geometry and view size, State kept, `onFoldChanged` each change | 2 | updated "switching the fold…" + the three layout tests + clamp test |
| 3 | `duoCanvasHeight` caps for any split, unchanged with none | 2, 5 | updated `duoCanvasHeight` test; `model.dart` line by inspection |
| 4 | Deck row shows, actions fire, none → as before, no overflow at 373 / 455 | 3 | session-row tests + both overflow loops |
| 5 | Bar and bar-toggle FAB hidden, other actions on the deck | 4 | inspection of the diff against the spec table; on-device check by Lucas |
| 6 | `flutter analyze` clean on touched files, all `duo_*_test.dart` pass | all | gate below |

## Gate

Flutter is not on `PATH`; use `~/development/flutter/bin/flutter`. Run from
`flutter/` in the worktree.

Before editing (baseline for "no new issues"; `remote_page.dart` and `model.dart` carry
pre-existing analyzer output):

```
~/development/flutter/bin/flutter analyze lib/mobile/duo lib/mobile/pages/remote_page.dart lib/models/model.dart test/duo_fold_test.dart test/duo_split_test.dart test/duo_deck_test.dart > <scratch>/analyze-before.txt 2>&1
```

Focused and closing gate:

```
~/development/flutter/bin/flutter test --reporter=compact test/duo_fold_test.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_keyboard_test.dart test/duo_trackpad_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo lib/mobile/pages/remote_page.dart lib/models/model.dart test/duo_fold_test.dart test/duo_split_test.dart test/duo_deck_test.dart > <scratch>/analyze-after.txt 2>&1
```

Pass = every duo test green, and the after file has no issue that the before file lacks
(compare with line numbers stripped). Also `git status --short` shows only the eight files
above plus `docs/dispatch-loop/duo-deck-default-portrait/`, and not
`flutter/ios/Runner.xcodeproj/project.pbxproj`. Do not run `flutter_rust_bridge_codegen`; if
analyze cannot resolve the generated bridge in this worktree, that shows in the baseline too
and the before/after comparison still holds — report it rather than generating anything.

This repo has no `scripts/tests/` lints; none apply to the touched files.

## Regression surface

| Existing file / path | Behaviour change | Why unavoidable |
| --- | --- | --- |
| `remote_page.dart` `_bottomWidget` | Bar not built while the split is active | Spec §3; one added `&& !_duoDeckActive`, false off a Duo |
| `remote_page.dart` `build` (`showActionButton`) | Bar-toggle FAB absent while the split is active | Spec §3; same guard, upstream expression off a Duo |
| `remote_page.dart` `build` | Now depends on `MediaQuery` size (rebuilds on rotation/resize) | Spec §3 asks for it; the page already rebuilds through its `OrientationBuilder` path on the same events |
| `remote_page.dart` `_duoSplit` (`onFoldChanged`) | Also calls `setState` | The page must re-evaluate the bar and FAB when the geometry changes; fires only on a split change, which never happens off a Duo |
| `model.dart` `CanvasModel.getSize` | Passes `size`; cap now applies for any split, not only the laptop fold | Spec §2; returns `h` unchanged with no split |

Off a Duo (no geometry, or geometry with unknown screen and no hinge angle), `isDuo` is false,
`currentDuoSplit` is null everywhere, and every path above evaluates upstream's expression.
The Duo-only files changed by the previous units (`duo_split.dart`, `duo_deck.dart`,
`duo_fold.dart`) change behaviour only once the latch is set.

Implementer closes with the AGENTS.md minimization pass over the final diff and lists this
table, updated to what actually changed, in `results.md`.

## Known limits (carried into results.md)

- From the spec: virtual mouse clipped below the fold; relative mouse mode ignored by the
  deck; cover-first start before any inner geometry shows upstream's layout.
- With the iOS soft keyboard up, the deck is squeezed into what is left of the body; under
  60 pt of inner height the session row is left out (Task 3). Under about 22 pt the deck
  already overflowed before this unit; unchanged.
- While the gesture help panel is open it takes the bottom slot and the deck shrinks by its
  height (the spec keeps the panel there).

## Design forks for the captain

1. **Session row under a squeezed deck (Task 3 guard).** Planned: drop the row below 60 pt of
   inner deck height. Alternative: have `DuoSplitBody` hide the whole deck below a minimum
   height. The planned option is one stateless condition and keeps the trackpad usable; say so
   if the other is preferred.
2. **Action buttons as widgets, not data.** `DuoDeck.actions` is `List<Widget>` (built from
   `DuoDeckAction`) so the chat button can keep the bar's `futureBuilder` rule verbatim. A data
   list would be tidier but could not carry that rule without changing it.

Neither changes the approved scope.
