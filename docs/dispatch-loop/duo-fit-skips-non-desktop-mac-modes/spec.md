---
name: duo-fit-skips-non-desktop-mac-modes-spec
description: "Duo auto-fit skips Mac display modes under 540 pt tall, which macOS lists but refuses to set (laptop pose gets 960x540, not a failed 800x450), and the flat pose gets the status strip at the top too."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-fit-skips-non-desktop-mac-modes
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 41af5e2b-05b0-47c6-837a-53ef33c5a4f0
  at: 2026-11-22T01:05:00-08:00
---

# Spec: auto-fit skips Mac modes macOS cannot set

Base: `duo-mode` at `8a1623174`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-fit-skips-non-desktop-mac-modes`. Work type `code`.

## Problem (observed on the Duo, 2026-11-22 00:56)

In the laptop pose the new full-width chooser (`chooseDuoResolutionFullWidth`,
`flutter/lib/mobile/duo/duo_resolution.dart`) picked 800x450. The M6's RustDesk log:
`Change resolution of '1' to (800,450)` then `ERROR ... Failed to change resolution '1' to
(800,450): MacSetMode failed`. The Mac stayed at 2560x1440 and the picture text was tiny.

## Facts (captain, read on the M6 with CoreGraphics, read-only)

- The stock host lists every mode at the current refresh rate, including modes macOS marks not
  usable for the desktop GUI; the client gets only width and height (`src/platform/macos.mm`
  `MacGetModes`, `src/platform/macos.rs` `resolutions`).
- M6 main display (MPG321UX, 120 Hz) sizes whose only entries are not desktop-usable: 512x384,
  640x360, 640x480, 672x378, 672x504, 800x450. Every other size has a desktop-usable entry, and
  for 960x540, 1024x576, 1152x648, 1280x720, 800x600 and 1024x768 the host's `MacSetMode` choice
  (first HiDPI match, else non-HiDPI) is desktop-usable. All refused sizes are under 540 pt tall;
  all usable ones are 540 pt or taller.

## Required behavior

R1. Duo auto-fit (`DuoResolutionFit.tryFit`, macOS peers only, unchanged guards) ignores modes
with `height < 540` before choosing, in every pose. If that leaves no mode, it chooses from the
full list as before. `chooseDuoResolution` and `chooseDuoResolutionFullWidth` keep their
behavior for direct callers.

R2. With the M6's list (the sizes above plus the 16:9 and 4:3 sizes up to 3840x2160), the laptop
pose picks 960x540; flat and cover pick 800x600.

Constraints: AGENTS.md Editing Hygiene; logic in `flutter/lib/mobile/duo/`; no host, Rust or
shared-file change beyond thin hooks; no new state.

## Done when

D1. `tryFit` with an M6-like list sends 960x540 with `fullWidth: true` and 800x600 without it
(unit test, fails on base: base sends 800x450 for the laptop case).
D2. Existing Duo resolution tests pass unchanged, unless they encode a sub-540 pick.
D3. Focused gate: from `flutter/`, the Duo test files plus `test/duo_status_strip_test.dart`;
`flutter analyze` on the changed files, no new issue.
D4. On the Duo (captain): laptop pose connects and the M6 switches to 960x540 (M6 log and
`system_profiler`); text readable.

## Revision 1 (2026-11-22, same unit): status strip in the flat pose

Lucas: "and there one more, when flat, there is no strip at the top". The inner screen's top
corners are rounded; in the flat pose the full-width picture now starts at the top and its
corners are cut. Base `8a1623174` flat rule: inner, not laptop, aspect known →
`pictureBottom = deckTop = min(T + W / a, 0.6 H)`, no strip, no row band; fit area band.bottom
(with band) or `0.6 H - T` (without).

R3. **Flat pose with a usable band** (inner, not laptop): the same layout as the laptop pose —
row in the band (`rowBand`), picture full width resting on `band.top` with `pictureTop =
band.top - W / a`, the status strip above it, and the full-width fit (laptop's fit area and
chooser, so 960x540 on the M6; strip 79.2 pt, picture 376.3 pt, keyboard at band.bottom).

R4. **Flat pose without a band**: a strip of `kDuoTopClear = 60` pt at the top (clear of the
rounded corners), then the picture at full width from `T + 60` with height
`min(W / a, 0.6 H - T - 60)`, the deck directly below it with its row in the normal place. Fit:
the full-width chooser on area `Size(W, 0.6 H - T - 60)` (669x510.6, aspect 1.31 → 4:3
800x600 on the M6; picture 669x501.75 from 60 to 561.75).

R5. The strip widget, its content and its rules are those of the laptop pose
(`DuoStatusStrip`, shown when the space is at least `kDuoStripMinExtent`). Cover, landscape,
non-Duo unchanged.

Done when (revision): D5 flat with band → split equals the laptop split for the same band and
aspect; flat without band, 4:3 → picture rect `Rect(0, 60, 669, 501.75)`, strip above, deck from
561.75 (unit/widget tests). D6 fit: flat with band picks 960x540, flat without band 800x600 from
the M6-like list (unit test). D7 report the heights and picks per pose.
