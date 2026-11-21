---
name: duo-session-fits-mac-resolution-results
description: "A Duo session with a controllable Mac peer is set once to the lowest display mode at the picture area's closest aspect, through a pure chooser, a once-per-session fitter, and a three-line hook."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-session-fits-mac-resolution
  modified: 2026-11-21
resource: flutter/lib/mobile/duo/duo_resolution.dart
generated:
  by: claude/sonnet
  session: a0acdebd3eb043b50
  at: 2026-11-21T05:30:38-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-21T05:34:14-08:00
---

# Results: a Duo session fits the Mac's resolution to the picture area

## Gate

From `flutter/`:

- `~/development/flutter/bin/flutter test --reporter=expanded test/duo_resolution_test.dart test/duo_split_test.dart test/duo_deck_test.dart test/duo_fold_test.dart` — 35 tests, OK, exit 0
- `~/development/flutter/bin/flutter analyze lib/mobile/pages/remote_page.dart lib/mobile/duo/duo_resolution.dart test/duo_resolution_test.dart` — 2 issues, both pre-existing deprecations in `remote_page.dart` (baseline before editing: the same 2), none in the new files, exit 1 (info-level only)

Candidate commit: `30f271b40`

`git diff --stat`: `flutter/lib/mobile/pages/remote_page.dart | 3 +++` (3 insertions, 0 deletions), plus the two new files, all committed in `b738a7cab`.

## Acceptance → tests

| Criterion | Proven by |
|---|---|
| 1. Closest aspect, then lowest mode; not closest in size | `laptop area picks the lowest mode of the closest aspect`, `cover area picks the lowest 16:9 mode`, `the mode closest in size is not chosen`, `aspect tolerance lets a lower mode beat an exact one; empty is null` |
| 2. Once per session; unmet conditions send nothing | `conditions met send exactly one request per session`, `already at the chosen size sends nothing and uses up the session`, `unmet conditions send nothing until all hold` |
| 3. Thin hook; nothing sent during build | manual: diff inspection; `remote_page.dart` +3/-0, the only send site is inside `addPostFrameCallback` in `schedule` |
| 4. Duo tests and analyze | the two gate commands above; captain re-ran all six `duo_*_test.dart` files on the candidate: 49 tests, exit 0 |
| 5. M6 switches on session start, menu reachable, mode restored | manual: on-device, captain |
| 6. Readable menu-bar screenshot, modes named | manual: on-device, captain |

## Deviations

None. `chooseDuoResolution` and the fitter follow the plan; the current-size comparison is in points (display pixels divided by scale).

## Regression surface

- Changed existing file: `flutter/lib/mobile/pages/remote_page.dart`, three added lines (import, `_duoResolution` field, one `schedule` call as the first statement of the deck `Builder` in `_duoSplit`).
- Changed runtime path: that builder, which exists only on a Duo in portrait. Elsewhere nothing of this unit runs.
- With the conditions met, one `sessionChangeResolution` request per page lifetime, the same call the Resolution menu makes; the host's own restore undoes it. No client-side restore.

## Known limits

- Keyboard permission reads true until the host's permission message arrives; if the fit runs in that window on a session without keyboard permission, the host drops the request and the fit is spent for that session (manual menu still works).
- The mode change applies to the whole Mac. The host restores it only when the last remote connection closes, so with another session open the Mac stays at the Duo's mode after the Duo disconnects.

- The fit uses the pose when the conditions first hold; starting on the cover screen then unfolding keeps the cover's mode.
- A reconnect in the same page does not re-fit (same State), also after a full drop that restored the mode.
- With the all-displays view, the fit waits until one display is shown.
- 4:3 is picked in the laptop pose (669x456 -> 800x600), per the spec's rule.
- `schedule` has no widget test (needs a live `FFI`); covered by inspection and the on-device check.

## Review round 1 (captain, inline)

- S3 keyboard-permission window: recorded under Known limits; no code change (needs new state).
- S3 gate coverage: captain ran all six Duo test files (49 passed, exit 0); row 4 updated.
- S3 stale line: corrected. Alias stamp `claude/sonnet` kept: the loop's native-producer contract requires the launch alias as identity, with the resolved model `claude-sonnet-5-5` recorded as evidence.
- S3 shared-host side effect: recorded under Known limits.
- S3 redundant parentheses in `chooseDuoResolution`: removed.

Cleanup: none
