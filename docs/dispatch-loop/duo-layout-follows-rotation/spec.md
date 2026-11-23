---
name: duo-layout-follows-rotation-spec
description: "After a cover-to-inner switch or a rotation (including upside-down portrait), the Duo again shows the status strip, the 16:9 crease layout and a fitted Mac resolution, instead of falling back to a 4:3 picture with side gaps and no strip."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-layout-follows-rotation
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T23:10:39-08:00
---

# Spec: the Duo layout follows rotation and display changes

Base: `duo-mode` at `74f140b97`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-layout-follows-rotation` (branch
`unit/duo-layout-follows-rotation`; gitignored Dart bridge files copied in). Work type: `code`
(with an investigation step in the plan).

## Intent

Bug (Lucas, 2026-11-22). Repro: connect to the M6 on the cover screen, unfold so the inner screen
is in landscape, rotate to portrait. Result: no status strip; the remote picture starts at the very
top, about 4:3, with black gaps left and right; the control row and deck below look normal.

## Evidence (parent session, broken state)

- `devicectl device info displays`: inner display 123-456-789 active; "Main display orientation:
  portraitUpsideDown, non-flat orientation: portraitUpsideDown".
- Screenshots on the MBP: `~/rustdesk-duo-logs/screens/rotate-bug-123-456-789.png` (inner,
  2007x2853) and `rotate-bug-987-654-321.png` (cover).
- Captain, at base: `flutter/lib/mobile/duo/duo_resolution.dart` sets `_done = true` after the first
  fit (lines ~52-92) and `schedule` returns early once `_done`, so auto-fit runs once per session
  and never after a display, pose or orientation change. The M6 keeps the mode picked for the cover
  screen (4:3, 800x600), which matches the 4:3 picture with side gaps.

## Hypotheses to settle (planner, with file:line evidence)

H1. The split / strip logic (`duo_split.dart` `duoSplitFrom`, `_usableBand`, the cover latch,
`duo_fold.dart`) rejects or misreads the fold in upside-down portrait or after the cover-to-inner
switch (band in flipped coordinates, stale posture, latch stuck on "cover"), so it falls back to
a layout without the strip. Check what the duo_display plugin reports when upside down, and
whether the strip is missing because the picture top is 0 (picture taller than the room above the
band once the aspect is 4:3) rather than because the fold is lost.
H2. Auto-fit never re-runs (confirmed above).

## Required behavior

R1. Upside-down portrait on the inner screen gives the same layout as portrait: status strip with
buttons, full-width 16:9 picture on the crease, control row in the crease, deck below.
R2. Auto-fit runs again, debounced (about 1 s after the last change), when the fit area changes:
display switch (cover ↔ inner), pose change, or rotation into a portrait layout. It keeps the
earlier rules: picks only modes macOS accepts (skips 800x450), does nothing when the best mode is
already set, and the original mode is still restored on disconnect (the one the Mac had before the
first fit, not an intermediate one).
R3. The plain cases stay right: connect in portrait on the inner screen; rotate landscape → portrait
and landscape → upside-down portrait; switch cover → inner while connected.
R4. Scope: the Duo files in `flutter/lib/mobile/duo/` and their tests; `remote_page.dart` only as a
thin hook if the plan shows it is needed. No Rust change unless the investigation proves it.

## Tests

Dart tests for: a re-fit after the fit area changes (debounced, one send per settled change, no
send when the mode is already right), restore uses the pre-session mode after several fits, and
the split for an upside-down / post-switch input reproduced from what the plugin reports (if H1
holds). No new test infrastructure.

## Done when

D1. The plan names the root cause(s) with file:line evidence (H1 settled true or false; H2 fixed).
D2. R1-R3 pinned by Dart tests where the plugin input can be reproduced; the rest by the on-device
repro.
D3. Focused gate: `flutter test` on all `flutter/test/duo_*_test.dart`; `flutter analyze` on the
changed files; no new issue.
D4. On the Duo (Lucas): the repro ends with strip + 16:9 picture + no side gaps; then Desktop and
Window taps work.
