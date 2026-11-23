---
name: duo-layout-follows-rotation-plan
description: "Plan for making Duo auto-fit run again, one second after the fit area settles, so a cover-to-inner switch or a rotation ends with the 16:9 crease layout and the status strip instead of the cover screen's 4:3 mode."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-layout-follows-rotation
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T23:14:40-08:00
---

# Plan: the Duo layout follows rotation and display changes

Spec: `docs/dispatch-loop/duo-layout-follows-rotation/spec.md` (stable). Base `duo-mode` at
`74f140b97`. All paths below are relative to the worktree
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-layout-follows-rotation`.

## Root cause

One cause: **H2**. The split and the strip are right for the picture they are given; the picture
is 4:3 because auto-fit ran once, for the cover screen, and never again.

### H1 is false: the fold is read correctly

- The plugin reports the hinge in the Flutter view's own coordinates in every orientation. The
  native observer is a subview pinned to the Flutter view and reads
  `reservedRegions(kind: .division, ...)` on itself
  (`~/.pub-cache/git/duo_display-0125ef92…/ios/duo_display/Sources/duo_display/DuoGeometryObserver.swift:8-9, 60-68, 107-108`);
  the Dart side uses the frame as is (`lib/src/geometry_mapping.dart:12-16, 56`). Nothing in the
  message carries the interface orientation, so there is no flipped-coordinate case to handle:
  upside down, the band is again a horizontal rect inside the view.
- The screen is "inner" whenever a division region exists (`geometry_mapping.dart:82-88`), and the
  observer re-reads on layout, trait, safe-area and hinge events, 150 ms and 1 s after the last one
  (`DuoGeometryObserver.swift:28, 71-89, 91-103`). A cover-to-inner switch therefore ends with an
  inner report. The only latch on our side is `DuoFold._isDuo` (`flutter/lib/mobile/duo/duo_fold.dart:75-78, 95-97`),
  which only ever turns on; there is no "cover" latch that could stick.
- The broken screenshot `~/rustdesk-duo-logs/screens/rotate-bug-123-456-789.png` (2007x2853 px,
  3x, so a 669x951 pt view) shows the band branch of `duoSplitFrom` at work: the control row sits
  in the crease and the keyboard starts below it. That is `rowBand != null`, reached only through
  `_usableBand` plus `screen == inner` (`flutter/lib/mobile/duo/duo_split.dart:54-64, 80-88`). The
  fold is not lost.
- The picture in it is about 1822x1367 px = 607x456 pt: exactly 4:3, with 31 pt of black on each
  side. The numbers follow from the code with a 4:3 peer:
  `full = paddingTop + 669 / (4/3) = 501.75`, which is not below `band.top = 455.5`, so
  `pictureTop = 0` (`duo_split.dart:78, 85-87`); the picture box is 669x455.5, a 4:3 image fits
  it by height (607.3 wide, 30.8 pt gaps); and the strip is drawn only when
  `top >= kDuoStripMinExtent` (`duo_split.dart:257`), so with `top = 0` there is none.
- With a 16:9 peer the same input gives `pictureTop = 79.2`, a full-width picture and the strip.
  `flutter/test/duo_deck_test.dart:130-135` already pins that.

So the missing strip and the side gaps are the layout's correct answer to a 4:3 Mac mode. No
change in `duo_split.dart`, `duo_fold.dart`, `duo_status_strip.dart` or the plugin.

### H2 is true: auto-fit is one-shot

- `DuoResolutionFit.tryFit` returns at once when `_done` is set and sets it after the first
  completed fit; `schedule` also returns early on `_done`
  (`flutter/lib/mobile/duo/duo_resolution.dart:52, 65, 80, 88`).
- The repro connects on the cover screen. The cover fit area is 466x305.1 with the plain chooser,
  which picks 800x600 (pinned in `flutter/test/duo_resolution_test.dart:179-181`; the same with
  the M6 list, per the earlier unit's R2). `_done` is now set for the page's lifetime.
- Unfolding and rotating changes the fit area to 669x455.5 with the full-width chooser (960x540
  on the M6), but nothing asks again. The Mac stays at 800x600.
- A second path gives the same result without the cover screen: when the first fit runs on the
  first portrait frame after a rotation, the plugin still holds the landscape report (it settles
  150 ms later), whose band is taller than wide. `_usableBand` rejects it, the pose counts as
  "flat without a band" (`duo_split.dart:123-126`), and the fit sends 800x600 and latches. The
  fix below covers both, because every fit now waits for the area to settle.

## Fix

Auto-fit keeps the fit it last completed (area and full-width flag) instead of a `_done` bit, and
runs again when the current area differs from it and has stayed the same for one second.

### Files touched

| File | Change |
| --- | --- |
| `flutter/lib/mobile/duo/duo_resolution.dart` | `_done` becomes the last fitted area; new `settle` and `dispose`; `schedule` goes through `settle` |
| `flutter/lib/mobile/pages/remote_page.dart` | one line in `dispose`: `_duoResolution.dispose();` |
| `flutter/test/duo_resolution_test.dart` | one test rewritten, two added |

No Rust, no plugin, no other Dart file.

### `duo_resolution.dart`

Add `import 'dart:async';` at the top. In `DuoResolutionFit`:

```dart
/// How long the fit area must stay the same before a fit is sent.
const Duration kDuoFitSettle = Duration(seconds: 1);

/// Sets the peer's display mode when a Duo deck shows, and again when the
/// picture area changes.
class DuoResolutionFit {
  Size? _area;              // area of the last completed fit (replaces _done)
  bool _fullWidth = false;  // its chooser
  Size? _pendingArea;       // what the running timer waits on
  bool _pendingFullWidth = false;
  Timer? _timer;
  bool _disposed = false;
  bool _scheduled = false;
```

`tryFit` (signature unchanged), two lines change:

- `if (_done) return;` goes; after the existing guard block (which already returns on
  `area == null`) add `if (area == _area && fullWidth == _fullWidth) return;`.
- `_done = true;` becomes `_area = area; _fullWidth = fullWidth;`.

Everything else in `tryFit` stays: the macOS / keyboard / view-only / mode-count / `current`
guards, the 540 pt filter, the two choosers, and "send only when the mode differs from
`current`". A fit whose best mode is already set still records the area and sends nothing.

New:

```dart
/// Runs [fit] once [area] and [fullWidth] have stayed the same for
/// [kDuoFitSettle]. Public for tests.
@visibleForTesting
void settle(Size? area, bool fullWidth, VoidCallback fit) {
  if (_disposed) return;
  if (area == null || (area == _area && fullWidth == _fullWidth)) {
    _timer?.cancel();
    _timer = null;
    return;
  }
  if (_timer != null && area == _pendingArea && fullWidth == _pendingFullWidth) {
    return;
  }
  _timer?.cancel();
  _pendingArea = area;
  _pendingFullWidth = fullWidth;
  _timer = Timer(kDuoFitSettle, () {
    _timer = null;
    fit();
  });
}

void dispose() {
  _disposed = true;
  _timer?.cancel();
}
```

`schedule`: drop `_done` from the first line (`if (_scheduled) return;`). In the post-frame
callback, after `_scheduled = false;`, read the media once, and wrap the existing body (from
`final media = ...` to the end of the `tryFit(...)` call, unchanged, re-reading media and peer
info when it runs) in the closure passed to `settle`:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _scheduled = false;
  final now = MediaQueryData.fromView(view);
  settle(currentDuoFitArea(now.size, paddingTop: now.padding.top),
      currentDuoFitFullWidth(now.size), () {
    // existing body, unchanged
  });
});
```

`@visibleForTesting` comes from `package:flutter/foundation.dart`, which `widgets.dart` already
re-exports; if the analyzer disagrees, drop the annotation rather than add an import.

### `remote_page.dart`

In `dispose()` (line 196), next to the other up-front teardown and before `super.dispose()`:
`_duoResolution.dispose();`. Without it a pending timer could fire after the session closed.
The existing hook at line 607 (`_duoResolution.schedule(gFFI, context)`) is unchanged.

### How the re-fit is triggered and debounced

- `schedule` is called on every build of the deck's `Builder` (`remote_page.dart:606-607`). That
  builder rebuilds when the split changes (`DuoSplitBody` calls `onFoldChanged`, which calls
  `setState` on the page: `duo_split.dart:220-231`, `remote_page.dart:599-602`), when the view
  size changes (`MediaQuery.sizeOf`, line 614) and when `FfiModel` notifies (line 608). A display
  switch, a pose change and a rotation into portrait each go through at least one of these.
- Each call compares the current fit area with the last fitted one. Equal: nothing, and a pending
  timer is dropped (the area went back). Different from the pending one: the timer restarts.
  Same as the pending one: the timer keeps running. So one send per settled change.
- One second is not arbitrary: the plugin re-reads 150 ms and again 1 s after the last native
  event (`DuoGeometryObserver.swift:28`). A timer started at the 150 ms report ends after the
  late report, which restarts it if the geometry changed again.
- When the timer fires and a guard is not met yet (peer info not set), nothing is recorded; the
  next build starts a new timer. Peer info arriving notifies `FfiModel`, which rebuilds the deck.
- The fit area does not depend on the peer's picture (`duo_split.dart:111-121`), so the mode
  change a fit causes cannot trigger another fit.
- Landscape has no fit area (`area == null`): a pending fit is dropped and the Mac keeps its mode.

### Restore keeps the pre-session mode (no client code)

Restore is the host's, as the first fit unit established, and it already handles several changes:

- On each change request the host calls `set_last_changed_resolution(name, original, changed)`
  (`src/server/connection.rs:4903-4913`). That function inserts `original` only when the display
  has no entry and otherwise updates `changed` alone (`src/server/display_service.rs:575-588`).
  The second and later fits therefore do not overwrite the mode recorded before the first one.
- When the last remote connection closes, `restore_resolutions` sets each display back to
  `res.original` and clears the table (`display_service.rs:591-607`, called from
  `connection.rs:7219-7220`).

The unit adds no client-side restore and no Rust change.

## Tests (`flutter/test/duo_resolution_test.dart`)

Timers run under `testWidgets` with `tester.pump(duration)`; no new dependency or helper file.
`settle` is driven directly with a closure that calls `tryFit` with the test's current area,
flag and `current` size, and the M6 list already in the file.

| # | Test | Pins | Fails on base |
| --- | --- | --- | --- |
| 1 | Rewrite `conditions met send exactly one request per session` as "one request per fit area": three `tryFit` calls on the laptop area send `['800x600']`; a call with area 466x251 adds `'1280x720'`; the same call again adds nothing | a changed area fits again, an unchanged one does not | yes (base stops at `['800x600']`) |
| 2 | `testWidgets` "a changed fit area is fitted once it has settled": cover area 466x305.1 (plain) settles, 1 s later `['800x600']`, `current` becomes 800x600. Then laptop area 669x455.5 (full width), 600 ms, flat area 669x510.6, 600 ms, laptop area again, 999 ms: still one send; 1 ms more: `['800x600', '960x540']`. `settle` with the same area again and 2 s: no further send | R2 debounce, one send per settled change, the repro's cover → inner sequence ends at 960x540 | yes (no `settle`) |
| 3 | `testWidgets` "a settled area whose best mode is set sends nothing; dispose drops a pending fit": `current` 960x540, laptop area settles, 1 s: nothing sent; area 669x440 (full width, same pick) settles, 1 s: nothing sent; then the cover area, `dispose()`, 2 s: nothing sent | "does nothing when the best mode is already set", no send after the page is gone | yes (no `settle` / `dispose`) |

Test 2 of the existing file (`already at the chosen size sends nothing and uses up the session`)
keeps passing; rename it only if its title becomes untrue ("... and settles the area").

Not added, on purpose:

- A split test for an upside-down input. H1 is false, and the plugin's report in that orientation
  is an ordinary horizontal band, which `duo_split_test.dart` and `duo_deck_test.dart:130-135`
  already cover for both aspects.
- A restore test. Restore is host code this unit does not change (see Fork 1).

## Gate

From `flutter/`:

```
~/development/flutter/bin/flutter test test/duo_deck_test.dart test/duo_fold_test.dart \
  test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart \
  test/duo_status_strip_test.dart test/duo_trackpad_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_resolution.dart \
  lib/mobile/pages/remote_page.dart test/duo_resolution_test.dart
```

All tests pass; `analyze` shows no issue that the base does not show for the same files (record
the base count for `remote_page.dart` first). The unit touches nothing under `scripts/tests/`, so
no repo lint applies beyond these.

On device (Lucas, D4): connect on the cover screen, unfold, rotate to portrait and to upside-down
portrait. About a second after the rotation the M6 switches to 960x540, the picture is full width
on the crease and the strip shows; Desktop and Window taps work. After disconnect the M6 log has
`Restore resolution of display ... to (<the mode before the session>)`.

## Acceptance → evidence

| Spec item | Evidence |
| --- | --- |
| D1 root cause, H1 / H2 | "Root cause" above |
| R1 upside-down portrait layout | H1 analysis (view-relative band) + re-fit to 16:9; on-device repro |
| R2 debounced re-fit, earlier rules kept | tests 1-3; existing 540 pt and chooser tests unchanged |
| R2 restore to the pre-session mode | host code cited above; M6 log on device |
| R3 plain cases | existing Duo tests unchanged; test 2 (cover → inner); on-device |
| R4 scope | files-touched table |
| D3 gate | "Gate" |

## Regression surface

| Existing file / path | What changes | Why unavoidable |
| --- | --- | --- |
| `duo_resolution.dart` `tryFit` | fits once per fit area instead of once per page | the bug is the once-per-page latch |
| `duo_resolution.dart` `schedule` | every fit, the first included, waits until the area has been stable for 1 s | the first fit must not use the pre-rotation geometry either (second path above); one path instead of two |
| `remote_page.dart` `dispose` | one added call | a pending timer must not outlive the session |
| Non-Duo devices, landscape, non-macOS peers | none: the deck builder is not built, or the unchanged guards return; on a Duo with a non-macOS peer a 1 s timer ends in the unchanged guard | - |
| Host, plugin, split, strip | untouched | - |

New state: four fields and a timer in `DuoResolutionFit`, all inside the feature's own class. The
spec allows state for the re-fit; nothing existing reads it.

## Implementer task (one)

1. Edit `flutter/lib/mobile/duo/duo_resolution.dart` as in "Fix" (import, constant, fields,
   the two `tryFit` lines, `settle`, `dispose`, `schedule`).
2. Add `_duoResolution.dispose();` in `remote_page.dart` `dispose()` before `super.dispose()`.
3. Rewrite test 1 and add tests 2 and 3 in `flutter/test/duo_resolution_test.dart`.
4. Run the gate; do the AGENTS.md minimization pass (no other line in either file changes, no
   formatting-only change); write `results.md` with the regression surface and the gate output.

Do not run `flutter_rust_bridge_codegen`; do not touch the plugin, Rust, or the other Duo files.

## Known limits

- A mode picked by hand in the Resolution menu stays until the fit area next changes (pose,
  display or rotation into portrait); that change fits again and replaces it. Keeping a manual
  choice would need a further flag and a rule for when it expires.
- Landscape has no deck and no fit area, so rotating to landscape leaves the Mac at the last
  portrait mode, as today.
- The first fit of a session is sent about 1 s after the deck first shows, not on the first frame.
- A reconnect inside the same page after a full drop (the host restored the mode) does not fit
  again while the area is unchanged; unchanged from the first fit unit.
- With a second session open on the Mac, the host restores only when the last one closes;
  unchanged.

## Forks for the captain

1. **Restore test.** The spec asks for a Dart test that restore uses the pre-session mode after
   several fits. Restore is entirely host-side and already correct for repeated changes
   (`display_service.rs:575-588`); no Dart code takes part, so a Dart test cannot pin it, and a
   Rust test would pass on base and touch a shared file for no fix. Recommended: no new test;
   the code citation plus the M6 log line on device. Alternative: a small `#[cfg(test)]` test of
   `set_last_changed_resolution` in `display_service.rs` (outside the spec's R4 scope).
2. **First fit debounced too.** Recommended (one path, and it closes the stale-geometry path).
   Alternative: first fit immediate, only re-fits debounced; that can send two mode changes in a
   second when a session starts mid-rotation.
3. **Manual resolution choice** is replaced on the next fit-area change (first known limit).
   Recommended: accept as a known limit.
