---
name: duo-session-fits-mac-resolution-plan
description: "Plan for a pure lowest-mode-at-closest-aspect choice, a once-per-session fitter with an injectable sender, and a three-line post-frame hook in the mobile remote page's Duo deck builder."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-session-fits-mac-resolution
  modified: 2026-11-21
generated:
  by: claude/claude-fable-5-2
  session: c1457871-3d7f-4483-a59f-623ec1426450
  at: 2026-11-21T05:29:07-08:00
---

# Plan: a Duo session fits the Mac's resolution to the picture area

Spec: `docs/dispatch-loop/duo-session-fits-mac-resolution/spec.md` (revised 2026-11-21: closest
aspect, then the **lowest** mode). Base `duo-mode` at `8dafe81e7`. One implementation task.

## Files touched

| File | Change | Notes |
|---|---|---|
| `flutter/lib/mobile/duo/duo_resolution.dart` | new | choice function, fitter class, session glue |
| `flutter/test/duo_resolution_test.dart` | new | 7 tests, no widgets needed |
| `flutter/lib/mobile/pages/remote_page.dart` | +3 lines, 0 modified | import, field, one call |

Nothing else: no Rust, no host code, no `duo_keyboard.dart` or its test, no pbxproj, pubspec,
generated bridge, or lang files.

## Facts checked while planning (beyond the spec's)

- Units. For a macOS peer `Display.width/height` in `pi.displays` are **pixels** and the display
  carries `scale` (`src/server/display_service.rs` ~855-880: `width: d.width()`, `scale`), while
  `pi.resolutions` are points. The desktop toolbar compares in points by dividing by the scale
  (`flutter/lib/desktop/widgets/remote_toolbar.dart` `scaledRect` ~2261). The spec's "already
  equals the current display size" is therefore evaluated in points:
  `(d.width / d.scale).round()` by `(d.height / d.scale).round()` (`Display.scale` is already
  clamped to >= 1). Comparing raw pixels would never match on a HiDPI Mac and would resend a mode
  the Mac already has.
- The deck `Builder` inside `_duoSplit` (`remote_page.dart` ~601) is built only while the split is
  active (`DuoSplitBody` places `below` only when `split != null`), and it already depends on
  `Provider.of<FfiModel>`, so it rebuilds whenever `FfiModel` notifies: peer info
  (`model.dart` ~1499), permissions (~246), switch display (~865). It is the one existing rebuild
  path that runs exactly when "split exists" and re-runs when any model-side condition changes.
- The canvas takes its size from `MediaQueryData.fromView(ui.window)` and subtracts
  `padding.top` in portrait before `duoCanvasHeight` (`model.dart` ~2340-2373). The picture area
  uses the same source so both agree.
- `duo_deck.dart` already imports the models for `DuoDeck.forSession`, and `duo_deck_test.dart`
  runs on the VM, so a duo file importing `models/model.dart` is test-safe.

## `duo_resolution.dart`

Three pieces, in this order. Doc comments one line each, as in the sibling duo files.

### 1. Choice (pure)

```dart
const double kDuoAspectTolerance = 0.02;

Resolution? chooseDuoResolution(List<Resolution> modes, Size area)
```

- Returns null when `modes` is empty or `area` has a non-positive side. Modes with a non-positive
  side are skipped (refusing bad input; no `ln` of zero).
- Distance `d(m) = |ln((m.width / m.height) / (area.width / area.height))|`; `best = min d`.
- Candidates: `d(m) <= best + kDuoAspectTolerance`.
- Result: the candidate with the smallest width, then the smallest height. Size relative to the
  area is never consulted.

### 2. Once-per-session fitter

```dart
typedef DuoResolutionSender = void Function(int width, int height);

class DuoResolutionFit {
  bool _done = false;
  bool _scheduled = false;

  void tryFit({
    required Size? area,          // null: no split
    required String platform,
    required bool keyboard,
    required bool viewOnly,
    required List<Resolution> modes,
    required Size? current,       // shown display in points; null: none or all displays
    required DuoResolutionSender send,
  });

  void schedule(FFI ffi, BuildContext context);
}
```

`tryFit`:

1. `_done` -> return.
2. Any condition missing -> return **without** setting `_done` (the spec says "the first time all
   of these hold"): `area == null`, `platform != kPeerPlatformMacOS`, `!keyboard`, `viewOnly`,
   `modes.length <= 1`, `current == null`.
3. `mode = chooseDuoResolution(modes, area)`; null -> return (not done).
4. `_done = true`. If `mode.width != current.width.round() || mode.height != current.height.round()`
   call `send(mode.width, mode.height)`. Already at that size: nothing sent, and the session is
   still used up (a later pose change must not re-fit).

"Peer info is set and has displays" is carried by `current`: the glue passes null when
`pi.isSet` is false or `tryGetDisplayIfNotAllDisplay` returns null (which it does for an empty
display list and for the all-displays view).

### 3. Session glue (`schedule`)

```dart
void schedule(FFI ffi, BuildContext context) {
  if (_done || _scheduled) return;
  _scheduled = true;
  final view = View.of(context);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scheduled = false;
    // read everything now, not at build time
    final media = MediaQueryData.fromView(view);
    final split = currentDuoSplit(media.size);
    final pi = ffi.ffiModel.pi;
    final d = pi.isSet.isTrue
        ? pi.tryGetDisplayIfNotAllDisplay(display: pi.currentDisplay) : null;
    tryFit(
      area: split == null ? null
          : Size(media.size.width, split.pictureBottom - media.padding.top),
      platform: pi.platform,
      keyboard: ffi.ffiModel.keyboard,
      viewOnly: ffi.ffiModel.viewOnly,
      modes: pi.resolutions,
      current: d == null ? null : Size(d.width / d.scale, d.height / d.scale),
      send: (w, h) => bind.sessionChangeResolution(
          sessionId: ffi.sessionId, display: pi.currentDisplay, width: w, height: h),
    );
  });
}
```

The sketch fixes behaviour, not formatting; the implementer drops the inline comment unless it
earns its place. `build` only sets a flag and registers a callback; the request leaves in the
post-frame callback. The `_scheduled` flag keeps one pending callback per frame however often the
builder runs. The view is captured at schedule time so the callback never touches a possibly
unmounted `BuildContext`. If the page is gone by then, `ffi` is the global and the worst case is
one request on a closed session id, which the bridge ignores as it does for the menu.

## Hook in `remote_page.dart` (additive, three lines)

1. Import, beside the other duo imports (~line 30): `import '../duo/duo_resolution.dart';`
2. Field in `_RemotePageState`, beside the existing state fields:
   `final _duoResolution = DuoResolutionFit();`
3. One call as the first statement of the existing deck `Builder` in `_duoSplit` (~line 602,
   before `final ffiModel = Provider.of<FfiModel>(context);`):
   `_duoResolution.schedule(gFFI, context);`

Why this point and not `onFoldChanged` or an `FfiModel` listener: `onFoldChanged` does not fire at
mount and knows nothing about peer info; a listener added in `initState` needs a matching removal
and its own split check. The deck builder already exists only when the split does and already
re-runs on every model change, so both orders (displays first, or split first) reach the call,
and when the deck is not built (not a Duo, landscape) the fitter is never invoked at all. No
existing line is modified.

A reconnect inside the same page keeps the same State and so the same fitter: no second fit.
The host keeps the changed mode across a reconnect only while a connection is open; after a full
drop it restores, and this session then stays at the Mac's own mode with the manual menu
available. That follows the spec's "at most once per session" as written; see open question 2.

## Tests: `flutter/test/duo_resolution_test.dart`

Plain `test()` cases; the sender is a closure appending `'${w}x$h'` to a list. Shared fixture,
the spec's 4K 32-inch list:

```
3840x2160, 3360x1890, 3008x1692, 2560x1440, 1920x1080, 1600x900, 1280x720, 1024x768, 800x600
```

A helper `fit(DuoResolutionFit f, {area = Size(669, 456), platform = kPeerPlatformMacOS,
keyboard = true, viewOnly = false, modes = k4k, current = Size(3840, 2160)})` returns nothing and
records sends. Expected values below were computed from the rule while planning.

| # | Test | Asserts | Done-when |
|---|---|---|---|
| 1 | laptop area 669x456 with the 4K list | `800x600` (4:3 is the closest aspect, 0.096 against 0.192 for 16:9; lowest of 1024x768, 800x600) | 1 |
| 2 | cover area 466x251 with the 4K list | `1280x720` (16:9 closest, 0.043; lowest of the seven 16:9 modes) | 1 |
| 3 | not the mode closest in size: area 1338x912 (laptop area doubled) with the 4K list | `800x600`, not `1024x768` whose width is nearer the area's | 1 |
| 4 | aspect tolerance and empty list: modes 1366x768, 1360x768, 1280x720, 1024x768 with area 683x384 -> `1280x720` (exact-aspect 1366x768 loses to a lower mode within 0.02); `[]` -> null | 1 |
| 5 | conditions met -> sends once; triggering again, also with another area, sends nothing more | sends == `['800x600']` after three calls | 2 |
| 6 | already at the chosen size (`current: Size(800, 600)`) -> nothing sent; a later trigger with a different current size still sends nothing | sends empty | 2 |
| 7 | each unmet condition sends nothing: platform `'Windows'`, `keyboard: false`, `viewOnly: true`, a one-mode list, `area: null`, `current: null`; then the same fitter with all met sends `['800x600']` | sends empty after the six, one entry after the seventh call | 2 |

Seven tests for two behaviours plus the spec's explicit "not closest in size" pin; test 7 loops
over the unmet cases instead of one test each. No widget test for `schedule`: it would need a
live `FFI` or a test-only seam in production code, which AGENTS.md rules out; Done-when 3 is
verified from the diff (the only send site is inside `addPostFrameCallback`) and Done-when 5-6 on
device by the captain.

## Done-when mapping

| Done-when | Evidence |
|---|---|
| 1 choice rule | tests 1-4 |
| 2 once per session | tests 5-7 |
| 3 thin hook, nothing sent in build | `git diff --stat` shows `remote_page.dart` +3/-0; send only inside the post-frame callback |
| 4 duo tests and analyze | focused gate below |
| 5, 6 on device | captain, after merge of the implement stage's candidate; not the implementer's |

## Gate (implementer; from `flutter/`, Flutter is not on PATH)

Before any edit, record the analyzer baseline:

```
~/development/flutter/bin/flutter analyze lib/mobile/pages/remote_page.dart 2>&1 | tail -3
```

Closing gate:

```
~/development/flutter/bin/flutter test --reporter=expanded test/duo_resolution_test.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_fold_test.dart 2>&1 | tail -3
~/development/flutter/bin/flutter analyze lib/mobile/pages/remote_page.dart lib/mobile/duo/duo_resolution.dart test/duo_resolution_test.dart 2>&1 | tail -5
```

Pass: "All tests passed!"; the issue count for `remote_page.dart` equals the baseline and the two
new files report none. `duo_keyboard_test.dart` and `duo_trackpad_test.dart` are left to the
captain's wider `duo_*` run because the keyboard files are changing under another unit. The repo
has no `scripts/tests/` lints, so none apply. Results must report the before/after analyzer
counts, the test tail, and `git diff --stat`.

## Regression surface

- Existing file changed: `flutter/lib/mobile/pages/remote_page.dart` only, three added lines.
- Existing runtime path changed: the deck `Builder` in `_duoSplit` gains one call. That builder
  runs only on a Duo in portrait. Off a Duo or in landscape it is never built, so no code of this
  unit executes and upstream behaviour is byte-for-byte the old path.
- On a Duo in portrait with a non-Mac peer, no keyboard permission, view-only, one mode, or the
  all-displays view: one post-frame callback per model change that reads state and returns.
- On a Duo in portrait with a controllable Mac: one `sessionChangeResolution` request per page
  lifetime, the same call the Resolution menu makes. The host's own restore undoes it.
- `getResolutionMenu`, `showOptions`, `DuoSplitBody`, `duo_split.dart`, `CanvasModel`: untouched.

## Known limits (state in results, do not fix)

- The fit uses the pose at the moment the conditions first hold; opening the session on the
  cover screen and then unfolding keeps the cover's mode. The spec accepts this.
- If the user picks the all-displays view before peer conditions settle, the fit waits until a
  single display is shown.

## Open questions for the captain

1. **4:3 on the laptop pose.** With the spec's 4K list and the 669x456 area the rule yields
   `800x600`: the area's aspect (1.47) is nearer 4:3 than 16:9. That is the largest text, as the
   revised goal asks, but on a 16:9 panel macOS shows a 4:3 mode pillarboxed or stretched, and
   the local user of the 32-inch display sees that until disconnect. The plan follows the spec;
   if 16:9 is wanted in that pose the rule needs a different tie-break (for example "native
   aspect first"), which is a spec change, not an implementer choice.
2. **Reconnect after a full drop** does not re-fit (same page State). Re-fitting would need the
   fitter reset on reconnect, a second hook; left out as the spec says once per session.
