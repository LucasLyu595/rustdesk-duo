---
name: duo-strip-always-shows-plan
description: "Plan for keeping the Duo's top strip on screen in the crease layout: reserve its height above the picture, hold the crease through reports that lack it, re-sync on resume, and log each layout-branch change."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-strip-always-shows
  modified: 2026-11-26
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-26T02:49:44-08:00
---

# Plan: the strip always shows

Spec: `docs/dispatch-loop/duo-strip-always-shows/spec.md` (stable). Base `duo-mode` at `db064f5f4`.
Paths are relative to the worktree
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-strip-always-shows`. The plugin is
`~/.pub-cache/git/duo_display-0125ef92a28925cfddb543060bb933cc1cf32b00` (pinned in
`flutter/pubspec.lock:374-382`), written `plugin/` below. `split` means
`flutter/lib/mobile/duo/duo_split.dart`, `page` means `flutter/lib/mobile/pages/remote_page.dart`.

## How the strip is decided today

One gate draws it: `widget.above != null && top >= kDuoStripMinExtent` (`split:257`), where
`top = max(0, split.pictureTop - paddingTop)` (`split:103-104`) and `kDuoStripMinExtent` is 24
(`split:45`). The strip shows its buttons only when it is at least 56 pt high
(`flutter/lib/mobile/duo/duo_status_strip.dart:118`, `duo_shortcuts.dart:57`). The page always
passes `above` (`page:606`) and a sender (`duo_status_strip.dart:39`), so everything depends on
`pictureTop` and `paddingTop`.

`pictureTop` is above 0 in two branches only: the crease branch when the picture is lower than the
room above the crease (`split:80-88`), and the flat branch (`split:89-94`). Every other branch
returns 0 (`split:95-99`).

## I1 / I2: when the strip is missing

| # | Condition | Evidence | Reachable in normal use? | Recovers? |
| --- | --- | --- | --- | --- |
| 1 | Crease layout, picture height `W / aspect` reaches `band.top - 24` (4:3, 3:2; 16:10 leaves 37 pt: line, no buttons) | `split:78, 85-87, 257`; `duo_status_strip.dart:118` | Yes. After a cover-to-inner switch until the refit one second later (`duo_resolution.dart:52, 116`); for good when the refit cannot run (peer not macOS, view-only, no keyboard permission, one mode, `duo_resolution.dart:75-82`), when the Mac lists no 16:9 mode, or when the mode is changed by hand | Only through a refit; otherwise it stays |
| 2 | Crease layout, peer aspect unknown | `split:78` (`full == null`), `85-87`; `split:67-71`; `flutter/lib/models/model.dart:4571-4578` | Yes: before the first display info at connect, and for the whole session when the Mac has several displays and "all displays" is shown (`kAllDisplayValue` gives null) | First case in a moment; second never |
| 3 | `padding.top` above 0: 16:9 gives `79.19 - 60 = 19.19 < 24` | `split:103-104, 257` | Yes, see rows 3a-3d | See rows |
| 3a | Soft keyboard up: the page shows the status bar | `page:321-326`, `page:486-490` | Yes, by design | Yes, on keyboard hide (`page:296-297`) |
| 3b | Keyboard asked for but none comes up (a hardware keyboard is attached to the Duo): the bar is shown 60 ms later whether or not a keyboard appears, and no hide event follows | `page:473-491`; the only hide is in `page:296-297` | Only with a hardware keyboard | No, until a later keyboard hide |
| 3c | A keyboard show followed by a hide within 30 ms: the show timer is not cancelled by the hide branch | `page:296-317` does not cancel `_timer`; `page:321-326`; `flutter/lib/consts.dart:452` | Rare | No, until a later keyboard hide |
| 3d | A dialog with a text field: the keyboard event shows the bar whatever `_showEdit` is | `page:295, 318-326` | Yes | Yes, on keyboard hide |
| 3e | After resume: nothing hides the bar again | `page:236-240` | Not shown by the code. It needs iOS to drop the keyboard in the background without the hide event reaching Dart | Unknown |
| 3f | iOS shows the bar by itself | step 17 in `docs/DUO.md:30` (upside down, fixed in `flutter/ios/Runner/Info.plist:79-85`) | Fixed for the known case | n/a |
| 4 | A report without the crease while the inner screen is in use: the native read passes its guard with a hinge state alone, and the Dart mapping then gives no hinge and a screen that is not `inner`. The split falls to the 0.45 fallback: no strip, deck at 427.95 | `plugin/ios/duo_display/Sources/duo_display/DuoGeometryObserver.swift:107-111`; `plugin/lib/src/geometry_mapping.dart:56, 83-93`; `split:80, 89, 95-99` | Plausible on resume, a screen switch and a pose change: the plugin's own notes say regions are empty in the first layout passes and that transitions emit intermediate states (`DuoGeometryObserver.swift:22-27, 73-74`). Not observed, the Duo is offline | Only on the next native event. The second read comes one second after the last event; later changes arrive "without any event this view receives" (`DuoGeometryObserver.swift:26-28`), so it can stay |
| 4a | Knock-on of row 4 when it lasts a second: the fit area becomes the fallback's, auto-fit sets the Mac to 4:3, and row 1 then applies after the crease is back | `split:112-121`; `duo_resolution.dart:116-119, 134-135`; `flutter/test/duo_resolution_test.dart:255-257` | As row 4 | After the next refit, one second after the crease returns |
| 5 | Portrait view with the previous orientation's band (taller than wide) or one outside the view | `split:58-60`; the plugin settles 150 ms after the last event (`DuoGeometryObserver.swift:28`) | Yes, on every rotation into portrait | Yes, with the next report. Meanwhile the flat layout shows (strip at 60 pt) when the aspect is known, the 0.45 fallback (no strip) when it is not |
| 6 | Dart keeps an old report: a native send that fails is dropped, and Dart asks again only on first listen | `plugin/ios/duo_display/Sources/duo_display/DuoDisplayPlugin.swift:61-68` (`try?`); `plugin/lib/src/duo_display.dart:56-65` | Not shown; possible around background and resume | Only on the next native change |
| 7 | No report yet in this app run: `isDuo` is false, no split at all | `flutter/lib/mobile/duo/duo_fold.dart:73-78, 94-97`; `split:76` | Only at the first session start | Yes, with the first report |
| 8 | Not the crease layout: landscape, cover screen, non-Duo | `split:76, 95-99` | Yes, by design | Out of scope (R5) |

Checked and not a cause: `DuoSplitBody.build` has no other gate (`split:247-272`); the strip sits at
the top, so a body shortened by the keyboard does not cut it. `DuoStatusStrip` always paints at
least the line (`duo_status_strip.dart:113-127`). `DuoDeck` lays out below the split only
(`duo_deck.dart:38-92`). The `isDuo` latch only turns on (`duo_fold.dart:95-97`). A band is never
reported for a screen other than `inner` (`geometry_mapping.dart:83-88`). The `SafeArea` at
`page:566` pads inside the picture box and is why the offset is measured from `padding.top`.
`flutter/lib/common.dart:704-712` shows the bar only while leaving the page.

## Root causes

1. **The layout gives the strip only what the picture leaves** (rows 1, 2, 3). Supported by code
   and by two earlier device findings (unit 5, step 17). It is certain.
2. **A report without the crease switches the layout to a fallback and can stay there**, and after
   a second it also moves the Mac to 4:3 (rows 4, 4a, 5, 6). Supported by the plugin's code and
   comments; not confirmed on the device. R4's log will confirm or refute it.
3. **The status bar can stay shown** (rows 3b, 3c): real but narrow. No code path shows it staying
   after a resume or a dialog.

## Fix

### Files touched

| File | Change |
| --- | --- |
| `flutter/lib/mobile/duo/duo_split.dart` | crease branch reserves the strip (R1); held crease passed through (R2); fit area below the strip; branch log (R4) |
| `flutter/lib/mobile/duo/duo_fold.dart` | held crease per view size; `refresh()` (R2) |
| `flutter/lib/mobile/pages/remote_page.dart` | one hook line on resume plus one new method (R2, R3) |
| `flutter/test/duo_split_test.dart`, `duo_deck_test.dart`, `duo_resolution_test.dart` | new tests; expectations that encode "no strip" updated |

No Rust, no plugin, no `Info.plist`, no other Dart file.

### R1: `duoSplitFrom` reserves the strip

`duo_split.dart` gains `import 'duo_shortcuts.dart' show kDuoShortcutMinExtent;` (no cycle:
`duo_shortcuts.dart` does not import the split). No new constant: the reserve is the height at
which the strip shows its buttons.

`duoSplitFrom` gets one new named parameter, `Rect? held`, and the crease branch (`split:80-88`)
becomes:

```dart
final crease =
    band != null && geometry?.screen == DuoScreen.inner ? band : held;
if (crease != null) {
  final strip = paddingTop + kDuoShortcutMinExtent;
  final fitted =
      aspect == null ? strip : crease.top - viewSize.width / aspect;
  return DuoSplit(
      pictureBottom: crease.top,
      deckTop: crease.top,
      rowBand: crease,
      pictureTop: min(crease.top, max(strip, fitted)));
}
```

- 16:9 with no padding keeps today's 79.19: nothing moves in the normal case.
- 4:3, unknown aspect, or 60 pt of padding: the picture box starts 56 pt below the padding and
  ends on the crease. The canvas already follows `pictureTop`
  (`duoCanvasHeight`, `split:288-295`; `model.dart:2373`), as does the key-help offset
  (`page:1126-1130`), so the picture is fitted into the lower box with side bars. No change there.
- `min(crease.top, ...)` only guards an absurd padding.
- The gate at `split:257` is unchanged: in the crease layout `top` is now at least 56.
- The flat branch, the non-inner band branch and the 0.45 fallback are untouched.

`duoFitAreaFrom` targets the box below the strip, so the refit picks a mode that fills it (the
spec's "the refit then removes them"). Two lines change:

```dart
final split = duoSplitFrom(geometry, viewSize,
    isDuo: isDuo, paddingTop: paddingTop, held: held);
...
return Size(viewSize.width,
    split.pictureBottom - max(split.pictureTop, paddingTop));
```

Without an aspect every branch but the crease one returns `pictureTop == 0`, so the cover and
fallback areas are exactly today's. The crease area goes from 669x455.5 to 669x399.5. With the
full-width chooser both the M6 list and the 4K list still give 16:9 (960x540 and 1280x720); a Mac
that lists 16:10 now gets 16:9 instead, which is what leaves room for the buttons. The area still
does not depend on the peer's picture, so a fit cannot trigger another fit.

### R2: hold the crease, re-sync on resume

The crease is a physical fact of the inner screen: for one view size it is always in the same
place (upside down it is the same rect, the band is centred: 455.5 + 40 + 455.5 = 951). So the
state to keep is one pair, the last full-width inner band and the view size it was seen with. It
needs no timer and no expiry, and it cannot latch a wrong layout: the cover screen has another
view size, and a newer usable band always replaces the held one.

`duo_fold.dart` (import becomes `import 'dart:ui' show Rect, Size;`), in `DuoFold`:

```dart
Size? _heldView;
Rect? _heldBand;

/// Remembers [band] as the crease of a [view]-sized inner screen; it stays
/// true through a report without it.
void holdBand(Size view, Rect band) {
  _heldView = view;
  _heldBand = band;
}

Rect? heldBand(Size view) => view == _heldView ? _heldBand : null;

/// Asks the device again, for a report missed while the app was away.
void refresh() {
  if (_subscription == null) return;
  DuoDisplay.current().then<void>((_) {},
      onError: (Object error) => debugPrint('DuoFold: $error'));
}
```

`reset()` also clears `_heldView` and `_heldBand`. `DuoDisplay.current()` records the native
snapshot and feeds it to the existing subscription when it differs
(`plugin/lib/src/duo_display.dart:68-78, 95-101`), which covers row 6.

`duo_split.dart`, one new private function, used by the three `current*` wrappers
(`split:106-109, 137-143`), which pass `held: _heldBand(viewSize)`:

```dart
Rect? _heldBand(Size viewSize) {
  final fold = DuoFold.instance;
  final geometry = fold.geometry.value;
  final band = _usableBand(geometry, viewSize);
  // A band as wide as the view belongs to this view, not to the screen or
  // orientation the app just left.
  if (band != null &&
      geometry?.screen == DuoScreen.inner &&
      band.left.abs() < 1 &&
      (band.width - viewSize.width).abs() < 1) {
    fold.holdBand(viewSize, band);
  }
  return fold.heldBand(viewSize);
}
```

The width check matters: right after an inner-to-cover switch the old inner band (669 wide) still
passes `_usableBand` on the 466-wide cover view; without the check it would be held for the cover
size and the cover screen would keep the crease layout.

`duoFitAreaFrom` and `duoFitFullWidthFrom` take `Rect? held` and pass it to `duoSplitFrom`;
`duoFitAreaFrom` skips its flat case when a crease is held
(`if (held == null && _flatWithoutBand(geometry, viewSize))`). So a glitch does not move the fit
area either, and row 4a is gone. `duoSplitFrom` stays pure; all tests that call it without `held`
keep their results.

Recompute points: `DuoSplitBody` already recomputes on every size or padding change
(`split:211-225`, which covers metrics and orientation), on every report (`split:227-232`) and on
every aspect change (`split:234-237`). The resume hook below adds the missing one.

Effect to accept: on the inner screen, once a crease was seen, a report without one keeps the
crease layout for as long as the view size stays. `docs/DUO.md:92` records that the Duo reports
the crease when flat, so the flat-without-band layout was already not reached there in steady
state; it still applies before any crease was seen.

### R3 and the resume hook: `remote_page.dart`

In `didChangeAppLifecycleState` (`page:236-240`) one line after `trySyncClipboard();`:
`_duoResumed();`. New method beside `_duoDeckActive` (`page:596`):

```dart
void _duoResumed() {
  if (!mounted) return;
  DuoFold.instance.refresh();
  if (_duoDeckActive && !keyboardVisibilityController.isVisible) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }
}
```

Non-Duo sessions skip the status bar call (`_duoDeckActive` is false) and `refresh()` returns at
once without a subscription. This heals rows 3b, 3c and 3e at the next resume. Rows 3b and 3c are
not otherwise fixed: with R1 a shown status bar no longer removes the strip, it only makes the
picture 60 pt lower. See fork F1.

### R4: branch log in `_DuoSplitBodyState`

New field `String? _logged;` and method; called once in the `LayoutBuilder` builder right after
`final top = duoPictureOffset(split, _top);` (`split:246`). The builder runs on rebuilds, not per
frame, and the method prints only when the branch changes (and once at mount).

```dart
void _log(DuoSplit? split, double top) {
  final strip = widget.above != null && top >= kDuoStripMinExtent;
  final buttons = strip && top >= kDuoShortcutMinExtent;
  final layout = split == null
      ? 'none'
      : split.rowBand != null
          ? 'crease'
          : split.pictureTop > 0
              ? 'flat'
              : 'fallback';
  final branch = '$layout $strip $buttons';
  if (branch == _logged) return;
  _logged = branch;
  final g = DuoFold.instance.geometry.value;
  final band = g?.hinge;
  String n(double? v) => v == null ? 'none' : v.toStringAsFixed(1);
  debugPrint('DuoSplit: layout=$layout strip=$strip buttons=$buttons '
      'offset=${n(top)} pad=${n(_top)} '
      'view=${n(_view?.width)}x${n(_view?.height)} '
      'band=${n(band?.top)}+${n(band?.height)} '
      'held=${split?.rowBand != null && split?.rowBand != band} '
      'screen=${g?.screen.name} pose=${g?.posture.name} '
      'aspect=${widget.aspect?.call()?.toStringAsFixed(3)}');
}
```

`debugPrint` is what `duo_fold.dart:88` already uses and goes to the device log, not the UI.
Numbers are formatted by hand because `Rect.toString()` is stripped in release builds
(`duo_fold_debug_overlay.dart:53`). `buttons` means the strip has room for them.

## Tests

New, in `flutter/test/duo_split_test.dart` unless noted. No new helpers beyond the file's own.

| Test | Pins | Fails on base because |
| --- | --- | --- |
| crease, 4:3: the strip shows and the picture box starts below it | `above` at `0,0 669x56`, child at `0,56 669x399.5` | no strip, child from 0 |
| crease, 60 pt top padding (`tester.view.padding = FakeViewPadding(top: 60)`), 16:9: the strip shows | `above` at top 60, height 56 | offset 19.19, no strip |
| a report without the crease, then the crease again: layout unchanged | after `_geo()`, an `unknown` screen without hinge, then `_geo()`: same child, `above` and `below` rects each time, `onFoldChanged` not called | deck jumps to 427.95, strip gone |
| rotation: portrait, landscape view, portrait view with the landscape band still reported, then the portrait band | landscape has no split; back in portrait `below` starts at 455.5 and the strip shows before the new report | flat layout or fallback until the report |
| the held crease stays with its view size (plain `test`) | with `_geo()` still reported, `currentDuoSplit(cover)`; then an outer report: `currentDuoSplit(cover)` is the 305.1 fallback with no `rowBand`, and `currentDuoSplit(portrait)` still has the row band | n/a on base; guards the width check |
| a branch change prints one line | `debugPrint` replaced for the test: one line at mount with `layout=crease strip=true`, none on an unchanged rebuild, one more with `layout=none` after a landscape view | no line |
| fit area during a glitch (`duo_resolution_test.dart`, added to the fit-area test) | `currentDuoFitArea(view)` is 669x399.5 and `currentDuoFitFullWidth(view)` true before and after a report without the crease | 669x427.95, false |

Existing expectations that change (update only these values, do not restructure):

- `duo_split_test.dart` "fold set: child above the fold": child rect becomes `0,56 669x399.5`.
- `duo_split_test.dart` "switching the fold relayouts live": height 399.5 after `_geo()`; after
  `_flat()` on the same view it stays 399.5 with `changes == 1`; landscape gives 669 and
  `changes == 2`.
- `duo_split_test.dart` "body shorter than the split": child height becomes `h - 56`.
- `duo_split_test.dart` "duoCanvasHeight caps": `duoCanvasHeight(900, 50, view)` becomes 349.5.
- `duo_deck_test.dart` "laptop, 16:9" tail (`:143-147`): 4:3 gives the picture `0,56 669x399.5`
  and the strip with bottom 56 instead of `findsNothing`.
- `duo_resolution_test.dart` "the fit area ends at the band top" (`:244`): 669x399.5; rename it to
  say "below the strip". The modes it picks do not change.

Resume has no Dart test: the hook's effect is the native re-read and the status bar call, and
neither can be exercised without a mock host, which the spec rules out. It is device step 4.

## Focused gate

From `flutter/`:

```
~/development/flutter/bin/flutter test test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart test/duo_status_strip_test.dart test/duo_trackpad_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_split.dart lib/mobile/duo/duo_fold.dart lib/mobile/pages/remote_page.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_resolution_test.dart
```

All tests pass; `analyze` shows no issue that is not on base (compare with the same command on
`db064f5f4` for `remote_page.dart`). The plan touches nothing under `scripts/tests/`, so no repo
lint applies. No Rust is touched, so no cargo gate.

## Regression surface

| Existing path | Change | Why it cannot be avoided |
| --- | --- | --- |
| `duoSplitFrom` crease branch | `pictureTop` is at least `paddingTop + 56` (was 0 for a tall picture or unknown aspect); a held crease counts as the crease | R1 and R2 are this branch |
| `duoFitAreaFrom` | crease area 56 pt lower; flat case skipped when a crease is held | the refit must aim at the box R1 leaves, and must not move during a glitch |
| `duoFitFullWidthFrom`, `currentDuoSplit`, `currentDuoFitArea`, `currentDuoFitFullWidth` | pass the held crease | one source for every caller, so canvas, deck row and fit agree |
| `_DuoSplitBodyState.build` | one `_log` call | R4 |
| `DuoFold` | two fields, three methods, `reset()` clears the fields | R2 |
| `_RemotePageState.didChangeAppLifecycleState` | one added call; returns early for non-Duo | R2 resume, R3 |

Unchanged: landscape and non-Duo (no split), the cover screen (its view size never holds a
crease), the flat layout before any crease was seen, a 16:9 picture with no padding, the deck,
the strip widget, the keyboard paths in `remote_page.dart`.

## Known limits

- A shown status bar still costs the picture 60 pt of height while it is up, and in rows 3b and 3c
  it stays until the next keyboard hide or resume. The strip and its buttons show throughout.
- A Mac that has only 4:3 or 16:10 modes keeps side bars beside the picture in the crease layout.
- Row 7: before the first report of an app run there is no Duo layout at all; unchanged.
- The held crease lives for the app run and is keyed by view size only. A device whose crease
  moved for the same view size would get the new one with its next report.
- Root cause 2 is inferred from the plugin, not seen on the device.

## Forks for the captain

- **F1, status bar on the Duo deck.** Planned: re-hide on resume only (above). Alternative: do not
  show the bar at all while the crease layout is up, by guarding the two existing calls
  (`page:323-324`, `page:487-488`) with `if (!_duoDeckActive)`. That removes rows 3a-3d and keeps
  the picture at full height while typing, but it edits two upstream lines, also changes the cover
  screen, and why upstream shows the bar with the keyboard on iOS is not known, so it needs a
  device check of the soft keyboard. Recommendation: keep the planned hook; take the alternative
  only on Lucas's word.
- **F2, fit area below the strip.** Planned as part of R1. If the captain wants auto-fit untouched,
  drop the `duoFitAreaFrom` return change (keep the `held` pass-through); the cost is permanent
  side bars on Macs whose closest wide mode is 16:10.

## Implementer task

One task, in this order:

1. `duo_fold.dart`: the two fields, `holdBand`, `heldBand`, `refresh`, the `reset()` lines, the
   import.
2. `duo_split.dart`: the import, `held` on `duoSplitFrom` / `duoFitAreaFrom` /
   `duoFitFullWidthFrom`, the new crease branch, the fit-area return, `_heldBand` and its use in
   the three `current*` wrappers, `_logged` and `_log` with its one call.
3. `remote_page.dart`: the hook line and `_duoResumed`. Nothing else in that file.
4. Tests: the seven new ones and the six listed updates. If another existing expectation fails,
   update it only when it encodes the old "no strip" value, and name it in the results; anything
   else is a finding to report, not to patch.
5. Run the focused gate. Report the regression surface as in the table, the test list against
   D1-D3, and any deviation. Keep to `AGENTS.md`: no refactor of existing code, no comments that
   restate code, one `use`/import style as nearby.

## Device steps for Lucas (D4)

Install with `bash duo/install-ios.sh`, open Console on the Mac, pick the Duo and filter on
`DuoSplit`. Connect to the M6 with the Duo half folded, upright. After each step the strip (status
line and eight buttons) should be there; note any step where it is not, with the log lines.

1. Connect on the cover screen, open to the inner screen, wait two seconds.
2. Rotate to landscape and back, then turn the Duo upside down and back.
3. Open flat, fold to the laptop pose, repeat three times at different speeds.
4. Go to the home screen for ten seconds and come back; then lock and unlock.
5. Tap the deck's keyboard button, type a word, hide the keyboard. While the keyboard is up the
   strip should sit below the iOS status bar.
6. Open the session menu and close it; open a dialog with a text field and cancel it.
7. On the M6, set a 4:3 mode by hand (800x600): the strip stays, the picture gets side bars, and
   within about two seconds the M6 goes back to 16:9.
8. Send the lines Console shows for `DuoSplit` (one at connect, one per layout change).
