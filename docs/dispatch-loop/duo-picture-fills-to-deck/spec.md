---
name: duo-picture-fills-to-deck-spec
description: "On the iPhone Duo's inner screen, let the Mac picture fill its full width down to the deck: over the crease band in the laptop pose, at its exact aspect height in the flat pose, with auto-fit choosing the mode from the new picture area."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-picture-fills-to-deck
  modified: 2026-11-21
generated:
  by: claude/claude-opus-5-5
  session: 41af5e2b-05b0-47c6-837a-53ef33c5a4f0
  at: 2026-11-21T16:30:00-08:00
---

# Spec: the Duo picture fills its width down to the deck

Base: `duo-mode` at `257b4d56a`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-picture-fills-to-deck` (branch
`unit/duo-picture-fills-to-deck`). Work type: `code`.

## Intent

Lucas: "I don't think the dynamic resolution is at best? there are still some gap aside? and some
space not utilized in between the screen and keyboard?" Measured on the Duo (inner screen
669x951 pt, laptop pose, M6 at 800x600): the picture area above the crease is 669x456 (about
3:2), so the 4:3 picture has about 30 pt black bars each side; the 40 pt crease band between the
picture and the deck stays empty.

Lucas chose:

1. Laptop pose, "Extend over crease": the picture runs across the crease band down to the deck's
   top row. 669x496 is almost 4:3, so no side bars and no empty strip. The crease part only shows
   picture: input stays on the trackpad and deck, so no picture gesture may depend on the band.
   Fit to full width; if a few points of height are missing, the picture may take them from the
   deck or leave a sliver. Choose what wastes least and say which.
2. Flat pose, "Yes": the picture takes exactly its aspect height at full width (669x502 for 4:3)
   at the top; the deck (session row, keyboard, trackpad) takes the rest.
3. Cover screen and landscape: no regressions. A device that is not a Duo stays exactly upstream.
4. Auto-fit recomputes its target aspect from the new picture area; report the mode it picks in
   each pose.

## Facts (captain, with citations)

- Split: `duoSplitFrom(geometry, viewSize, isDuo:)` in
  `flutter/lib/mobile/duo/duo_split.dart` returns `DuoSplit(pictureBottom, deckTop)` in view
  coordinates. Today: any portrait view with a usable horizontal band splits at the band
  (`pictureBottom = band.top`, `deckTop = band.bottom`), in any posture; otherwise
  `0.45 * height`. Non-Duo or landscape → null (upstream layout).
- Laptop pose detection already exists: `laptopFoldFrom(geometry)` in `duo_fold.dart` (inner
  screen, `DuoPosture.book`, non-empty band wider than tall).
- Callers of the split: `DuoSplitBody` (layout, `duo_split.dart`), `duoCanvasHeight` (called from
  `flutter/lib/models/model.dart:2373`, the canvas size, after `h -= padding.top` in portrait),
  `_duoDeckActive` (`remote_page.dart:594`, null check only), and `DuoResolutionFit.schedule`
  (`duo_resolution.dart:75`, area = `Size(width, pictureBottom - padding.top)`).
- Auto-fit: `chooseDuoResolution(modes, area)` picks the mode closest in log-aspect to the area,
  then the lowest within 0.02. Runs once per session when the deck first shows.
- Peer picture shape: `pi.tryGetDisplayIfNotAllDisplay(display: pi.currentDisplay)` gives
  `width`/`height` of the current display (null before display info or for all-displays).
- Measured band on the Duo inner screen: about `Rect(0, 455.5, 669, 40)`; tests use that value.

## Definitions

`W` = view width, `H` = view height, `T` = `MediaQuery` `padding.top`, all logical pt. `band` = the
reported hinge rect when it passes today's usable-band checks. `a` = the peer picture aspect,
current display `width / height`, or unknown.

## Required behavior

R1. **Laptop pose** (`laptopFoldFrom(geometry) != null` and the band is usable):
`pictureBottom == deckTop` (no empty strip). Base value `band.bottom`. If `a` is known and the
full-width picture bottom `T + W / a` lies in `(band.bottom, band.bottom + kDuoDeckGive]` with
`kDuoDeckGive = 12` pt, use `T + W / a` instead: the deck gives up those few points so the picture
fills the full width with no side bars and nothing wasted. Otherwise stay at `band.bottom` (a
wider picture gets bars above and below inside the area, a taller one side bars, as the canvas
fits it today). For 669 wide, `T = 0`, 4:3: the picture bottom is 501.75, the deck gives 6.25 pt.

R2. **Laptop pose, crease is display only**: touches that land in the band rect do not reach the
picture (no tap, drag, pan or scale on the remote canvas starts there). Nothing is drawn for this;
the picture shows through. Flat pose and other poses add no such block.

R3. **Flat pose** (inner screen, `geometry.screen == DuoScreen.inner`, not the laptop pose, with or
without a band): with `a` known, `pictureBottom == deckTop == min(T + W / a, 0.6 * H)`. With `a`
unknown, today's rule (band split if usable, else 0.45).

R4. **Cover screen / other** (not inner, Duo latched): unchanged (0.45 rule; band rule if a band
is ever reported). **Landscape and non-Duo**: still null, every existing upstream path unchanged.

R5. **Live update**: when the peer's display aspect changes (auto-fit switches the mode, the user
picks a resolution, or switches display), the split, the `DuoSplitBody` layout and the canvas size
follow, as they follow a fold change today. No new timers, caches or cross-frame state: the aspect
is read from the session's display info when the split is computed.

R6. **Auto-fit target area** no longer depends on `a` (no loop): on the inner screen with a usable
horizontal band (laptop or flat), the target is `Size(W, band.bottom - T)` (669x495.5 at `T = 0`,
aspect 1.350, so the 4:3 family wins, lowest 4:3 mode: 800x600 on the M6). On the inner screen
without a usable band (not laptop): `Size(W, 0.6 * H - T)`, the flat picture's largest area
(669x570.6, aspect 1.172, also 4:3, so flat gives 669x501.75 whether or not a band is reported).
Cover: today's area. (Amended at plan review, 2026-11-21: the plan's ambiguity 2 showed that
today's 0.45 area would pick 16:9 in flat without a band, against Lucas's 669x502 flat intent.) The results doc states the mode picked in each pose for a
4:3 + 16:9 mode list.

## Hard constraints

- AGENTS.md Editing Hygiene: smallest diff, logic inside `flutter/lib/mobile/duo/`; changes to
  `remote_page.dart` and `model.dart` are thin hooks at most. No change to any non-Duo path.
- No new kind of state (no timers, post-frame chains, caches, global notifiers holding the
  aspect). Deterministic from current geometry, view size, padding and display info.
- Do not run `flutter_rust_bridge_codegen`; no Rust or bridge changes.
- Do not commit `flutter/ios/Runner.xcodeproj/project.pbxproj`.

## Done when

D1. Laptop: 4:3 at 669 wide gives `pictureBottom == deckTop == 501.75`; 16:9 or unknown aspect gives
`band.bottom` for both (unit tests).
D2. Laptop: a tap in the band does not reach the picture child; a tap just above the band does
(widget test).
D3. Flat: 4:3 gives `501.75` for both edges; unknown aspect keeps today's split (unit tests).
D4. Cover, landscape, non-Duo unchanged (existing tests still pass, updated only where they
encode the old laptop/flat values).
D5. Auto-fit area: laptop and flat-with-band give `669x495.5`, flat without band `669x570.6`, and
all pick the lowest 4:3 mode from a 4:3 + 16:9 list; cover keeps today's area (unit test).
D6. Focused gate green: `flutter test test/duo_*_test.dart` from `flutter/`; `flutter analyze`
on the changed files reports no new issue.
D7. On the Duo (captain, after merge and reinstall): laptop pose shows no side bars and no empty
crease strip; flat pose shows the picture at full width with the deck directly below.
