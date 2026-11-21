---
name: duo-session-fits-mac-resolution-spec
description: "When a session starts on the iPhone Duo with the deck showing, set the Mac peer's display mode closest to the Duo's picture area, once per session, relying on the host's existing restore at disconnect."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-session-fits-mac-resolution
  modified: 2026-11-21
generated:
  by: claude/claude-opus-5-5
  session: c1457871-3d7f-4483-a59f-623ec1426450
  at: 2026-11-21T05:30:00-08:00
---

# Spec: a Duo session fits the Mac's resolution to the picture area

Base: `duo-mode` at `8dafe81e7` (the deck unit is merged). Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-session-fits-mac-resolution`.

## Intent

Lucas answered "Yes, auto-fit": when a session starts on the Duo, set the M6's display mode
closest to the Duo's picture area, through RustDesk's existing change-resolution support for
macOS peers; restore the original mode when the session ends; keep the manual resolution and
display menu reachable from the deck. The M6 runs stock RustDesk 1.5.3: no host changes.

## Facts already established (captain, with citations)

- Change: `bind.sessionChangeResolution(sessionId:, display:, width:, height:)`, as used by
  `getResolutionMenu` (`flutter/lib/mobile/pages/remote_page.dart` ~1547). Available modes:
  `ffiModel.pi.resolutions` (`List<Resolution>`, `width`/`height`); current display:
  `pi.tryGetDisplayIfNotAllDisplay(display: pi.currentDisplay)`.
- The host acts only with keyboard permission, records the original mode before the first
  change, and restores every changed display when the last remote connection closes, macOS
  included (`src/server/connection.rs` `change_resolution` ~4877–4925, close path ~7214–7220 →
  `display_service::restore_resolutions`). So **restore at session end needs no client code**;
  it also covers the app being killed. The unit must not add a client-side restore.
- The manual Resolution menu is inside `showOptions` (`remote_page.dart` ~1482), which the deck
  row's display button (tv icon) opens since the deck unit. Nothing to build; checked on device.
- Mac modes in `pi.resolutions` are in points (the host divides by the display scale on macOS,
  `connection.rs` ~4900).
- The deck split: `currentDuoSplit(viewSize)` in `flutter/lib/mobile/duo/duo_split.dart`; the
  picture area is the view width by `split.pictureBottom - padding.top`.

## Required behaviour

1. **Choice (pure function, new file `flutter/lib/mobile/duo/duo_resolution.dart`).** Goal
   (Lucas, revised 2026-11-21): **readable text first**. The M6 drives a 32-inch display, and
   its desktop shrunk into the Duo's picture area is unreadable. Given the modes (Mac
   "looks like" sizes in points; the host prefers the HiDPI variant when it switches,
   `src/platform/macos.mm` `MacSetMode(..., tryHiDPI=true)`) and the picture area size
   (points): pick the modes whose aspect ratio is closest (`|ln((w/h) / (aw/ah))|`, within 0.02
   of the best distance), then among them the **lowest** mode (smallest width, then smallest
   height), which gives the largest UI. Never choose by pixel count closest to the area. Empty
   list → none. The host already drops widths under 800 when it lists more than 15 modes
   (`src/platform/macos.rs` `resolutions`); the client takes the list as given.
2. **When.** At most once per session, the first time all of these hold: the deck split is
   active (Duo, portrait); peer info is set and has displays; the peer platform is macOS; the
   session has keyboard permission and is not view-only; `pi.resolutions.length > 1`; one
   display is shown (`tryGetDisplayIfNotAllDisplay` non-null). If the chosen mode already
   equals the current display size, send nothing. A later pose change does not re-fit (the
   manual menu stays for that). Sessions that never meet the conditions are never changed.
3. **Where.** New logic in `duo_resolution.dart`; `remote_page.dart` gets a thin hook only (a
   field holding the once-per-session state and one call). The change request is never sent
   during `build`; schedule it after the frame or from an existing callback.
4. **Off a Duo, in landscape, or for non-Mac peers:** nothing is sent; upstream behaviour is
   unchanged.

## Done when

1. The choice function picks the closest aspect, then the lowest mode, as above (tests with a
   realistic 4K 32-inch Mac mode list, for example 3840x2160, 3360x1890, 3008x1692, 2560x1440,
   1920x1080, 1600x900, 1280x720, 1024x768, 800x600, and the laptop area 669x456 and cover area
   about 466x251), and a test that pins "not the mode closest in size".
2. The once-per-session rule holds: conditions met → exactly one change request with the chosen
   mode; already at that size → none; conditions not met (not a Mac peer, no keyboard
   permission, view-only, one mode, no split) → none; a second trigger in the same session →
   none.
3. `remote_page.dart` diff is a thin hook; nothing is sent during build.
4. All `flutter/test/duo_*_test.dart` pass; `flutter analyze` shows no new issues in touched
   files.
5. On device (captain): the M6 switches mode when the session starts in a portrait pose, the
   Resolution menu is reachable from the deck's display button, and the M6 returns to its
   original mode after disconnect.

6. On device (captain): a Duo screenshot where the M6's menu bar text is readable; the report
   names the modes the M6 offers and the mode picked.

## Conditional follow-up (not in this unit)

If on device RustDesk cannot switch modes on the M6 (no list, or the switch fails), a separate
unit adds a fixed client-side zoom with panning in the Duo picture area. Decide only after the
device check.

## Hard constraints

- No host-side change, no Rust change, no client-side restore.
- AGENTS.md hygiene and test rules (1–3 tests per behaviour; assert the requests sent, through
  an injectable sender, not private state).
- Do not touch the keyboard files (another unit owns them), pbxproj, pubspec or generated files.
