---
name: duo-deck-default-portrait-spec
description: "On the iPhone Duo, show the keyboard and trackpad deck under the Mac picture in every portrait pose, and hide RustDesk's mobile bottom bar while the deck shows, keeping its session actions on the deck."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-deck-default-portrait
  modified: 2026-11-21
generated:
  by: claude/claude-opus-5-5
  session: c1457871-3d7f-4483-a59f-623ec1426450
  at: 2026-11-21T05:15:00-08:00
---

# Spec: Duo deck by default in portrait, original bar hidden

Branch base: `duo-mode` at `733433c0f`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-deck-default-portrait`.

## Intent (Lucas's words, from the device test)

"the build in keyboard and track pad should be default, in vertical. and omit the original
control bar with keyboard and mouse". His follow-up answers: the deck shows on **all portrait
screens**; the original bar is **hidden fully**.

## Today

- `flutter/lib/mobile/duo/duo_fold.dart`: `DuoFold.instance.laptop` is non-null only for
  inner screen + `DuoPosture.book` + a horizontal band (`laptopFoldFrom`).
- `flutter/lib/mobile/duo/duo_split.dart`: `DuoSplitBody` splits at the band only when
  `laptop` is non-null; `duoCanvasHeight(h, paddingTop)` caps the canvas above the band.
- `flutter/lib/mobile/pages/remote_page.dart`: `_duoSplit` puts `DuoDeck.forSession(gFFI)`
  below the band. RustDesk's bottom bar (`getBottomAppBar`) and its FAB stay as upstream.
- `flutter/lib/models/model.dart` `CanvasModel.getSize` calls
  `duoCanvasHeight(h, mediaData.padding.top)`.

## Required behaviour

### 1. When the deck shows (the "deck split")

A pure function decides, from the latest `DuoGeometry`, whether this device is a Duo, and the
view size (`MediaQuery` size, logical pixels):

- **Not a Duo → no split.** "Is a Duo" is latched true for the app run once any geometry
  arrives with `screen == DuoScreen.inner` or a non-null `hingeAngle` (UIKit only delivers a
  hinge on a hinged device). Before that, or on any other device / iOS < 27.1 / Android / web,
  there is no split and RustDesk behaves exactly as upstream. `DuoFold` gets a
  `@visibleForTesting` reset so tests can clear the latch.
- **Landscape view (width >= height) → no split** (plain upstream full-screen picture and bar).
- **Portrait with a usable band** (geometry `hinge` non-null, non-empty, wider than tall, top
  > 0 and bottom < view height) → picture from 0 to `band.top`, deck from `band.bottom` to the
  bottom. This covers the laptop pose (book) and flat with a reported band, in any posture.
- **Portrait with no usable band** (cover screen when shut, or flat with no band) → picture
  from 0 to `0.45 * viewHeight`, deck from there to the bottom (no gap). On the cover screen
  (about 466x678 pt) this leaves about 305 pt for the picture and 373 pt for the deck.
- The split is recomputed when the geometry or the view size changes (fold, open flat, shut,
  rotate). `DuoSplitBody` calls `onFoldChanged` whenever the computed split changes, from either
  cause, never during build.

`DuoFold.laptop` and `laptopFoldFrom` may stay for the debug overlay; the split must no longer
depend on them.

### 2. Canvas height

`duoCanvasHeight` caps the canvas to `split.pictureBottom - paddingTop` when there is a split,
else returns `h` unchanged. Its one call site in `model.dart` passes the view size it already
has (`mediaData.size` or the `size` used there); that one line is the only change in
`model.dart`.

### 3. Original bar hidden while the deck shows

In `remote_page.dart`, while the deck split is active:

- `getBottomAppBar()` is not shown, and the FAB that toggles it does not appear. The FAB still
  appears, as upstream, to close the iOS soft keyboard or the gesture help panel.
- The two `emptyOverlay` entries in `bottomNavigationBar` stay unchanged.
- `remote_page` rebuilds when the split changes (from `onFoldChanged`, plus a `MediaQuery`
  size dependency in `build`).
- With no split, `build`, the bar and the FAB behave exactly as upstream.

### 4. Session actions on the deck

`DuoDeck` gets an optional slim session row at its top (above the keyboard), shown only when
actions are given (no actions → deck exactly as today). `remote_page` passes buttons that
replicate every bar action except "hide bar", with the same conditions and handlers as
`getBottomAppBar`:

| Bar button | On the deck row |
| --- | --- |
| × disconnect (`clientClose`) | yes |
| tv: display options (`showOptions`) | yes |
| keyboard: iOS soft keyboard (`openKeyboard`), when not view-only and keyboard allowed | yes (system keyboard keeps IME, emoji, dictation) |
| mouse/touch: gesture help with the touch-mode switch, same condition, non-Android peer | yes; the gesture help panel still shows in the bottom slot while toggled |
| build: Android peer actions overlay, Android peer only | yes |
| chat (`onPressedTextChat`, or `showChatOptions` per the bar's rule), not web | yes |
| ⋮ more actions (`showActions`) | yes |
| expand_more: hide bar | no (nothing to hide) |

The row is small: about 32 pt high, white icons on the deck's dark background, and it must
not make the deck overflow at the cover screen deck height (about 373 pt) or the laptop deck
height (about 455 pt). The handlers stay in `remote_page.dart` (a new private method that
repeats the few lines it needs; `getBottomAppBar` itself is not reshaped).

## Hard constraints

- Non-Duo devices: no behaviour change at all (no split, bar, FAB and canvas as upstream).
- AGENTS.md editing hygiene: smallest diff; new logic in `flutter/lib/mobile/duo/`; shared files
  (`remote_page.dart`, `model.dart`) get thin hooks only; `getBottomAppBar` is not refactored;
  no new dependencies; no comments that restate code; one `import` per package style.
- Do not touch the keyboard, trackpad or deck input code beyond adding the session row.
- Do not commit `flutter/ios/Runner.xcodeproj/project.pbxproj`.
- Tests in `flutter/test/*_test.dart`, run on the VM. Do not run `flutter_rust_bridge_codegen`.

## Done when

1. The split rules in §1 hold for: laptop band; flat with band; cover screen (outer, closed)
   with the 0.45 split; landscape gives none; a non-Duo geometry (unknown screen, no hinge
   angle) gives none; the latch keeps the cover split after an inner geometry was seen.
2. `DuoSplitBody` lays the child and the deck per the split, relayouts live on geometry and
   view-size changes, keeps the child's State, and calls `onFoldChanged` on each change.
3. `duoCanvasHeight` caps to the picture area for any split and is unchanged with none.
4. `DuoDeck` with session actions shows the row above the keyboard and the actions fire; with
   none it lays out as before; neither overflows at 373 and 455 pt deck heights.
5. `remote_page.dart` hides the bar and the bar-toggle FAB while the split is active and keeps
   every other bar action reachable through the deck row (inspection; verified on device).
6. `flutter analyze` reports no new issues in touched files; all `flutter/test/duo_*_test.dart`
   pass.

## Out of scope / known limits

- The virtual mouse is still clipped below the fold; the deck ignores relative mouse mode
  (existing backlog items).
- If the cover screen reports no hinge angle and the app starts while the phone is shut, the
  cover shows upstream's layout until the inner screen has been seen once (clean fallback).
