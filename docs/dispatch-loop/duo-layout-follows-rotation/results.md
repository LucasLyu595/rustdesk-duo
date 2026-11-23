---
name: duo-layout-follows-rotation-results
description: "Duo auto-fit now re-runs one second after the fit area settles, so a cover-to-inner switch or rotation ends at the 16:9 crease layout; gate green."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: duo-layout-follows-rotation
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: aa22bd734fe456fbf
  at: 2026-11-22T23:16:09-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-22T23:18:07-08:00
---

# Results: the Duo layout follows rotation and display changes

Candidate commit: 602dbd41a (unit/duo-layout-follows-rotation, base fc33272bf; captain commit of the implementer's working tree; results doc committed after)

Ran as claude-sonnet-5-5.

## Acceptance → tests

| Done-when | Proven by |
| --- | --- |
| D1 root cause identified | plan.md "Root cause": H1 false (fold read correctly), H2 true (auto-fit one-shot, `_done` latch) |
| D2 R1-R3 pinned where the plugin input can be reproduced | R1 (upside-down portrait): no test; H1 is false (plan.md "Root cause": the plugin reports the hinge in view coordinates in every orientation), so it rests on that analysis and the device repro. R2: `a changed fit area is fitted once it has settled` (cover 800x600, then the laptop area settles to 960x540 after 1 s, debounced across area flaps); `conditions met send one request per fit area`; `a settled area whose best mode is set sends nothing; dispose drops a pending fit`; the unchanged 540 pt, chooser and guard tests; restore: `src/server/display_service.rs:575-607` (ruling 1, no new test). R3: the unchanged split tests |
| D3 focused gate | Gate section |
| D4 on-device repro | MISSING: Lucas's repro on the Duo (manual) |

## Gate

| Command | Exit status | Result |
| --- | --- | --- |
| `flutter pub get` (from flutter/) | exit 0 | no tracked file changed |
| `flutter test` test/duo_{deck,fold,keyboard,resolution,split,status_strip,trackpad}_test.dart | exit 0 | 70 passed, 0 failed |
| `flutter analyze` duo_resolution.dart, remote_page.dart, duo_resolution_test.dart | exit 0 per output | 2 issues, both pre-existing infos in remote_page.dart (WillPopScope, withOpacity); base shows the same 2 |
| Red-first: new `duo_resolution_test.dart` against base `duo_resolution.dart` | failed | compile failure (`settle`, `dispose` absent on base); source restored afterwards |

## Deviations

None. Plan forks as ruled: no restore test, first fit debounced, manual resolution choice replaced at the next area change.

Cleanup: none (base source copy for the red run was kept in the scratchpad, working tree restored).

## Known limitations

- When a guard never holds for the session (non-Mac peer, view-only, keyboard off), `_area` stays null, so a deck rebuild after a fired timer arms another 1 s no-op timer; at most one per second, no rebuild, no send.
- The timer re-reads the area when it fires; if the geometry moved without a rebuild, it fits an area that was not stable for the full second. The next settled change corrects it.

- A mode picked by hand in the Resolution menu is replaced when the fit area next changes.
- Landscape has no fit area; the Mac keeps the last portrait mode.
- The first fit is sent about 1 s after the deck first shows.
- A same-page reconnect after a full drop does not re-fit while the area is unchanged.
- With a second session open on the Mac, the host restores only when the last closes.

## Regression surface

| Existing file / path | What changed | Why unavoidable |
| --- | --- | --- |
| `duo_resolution.dart` `tryFit` | fits once per fit area, not once per page | the once-per-page latch is the bug |
| `duo_resolution.dart` `schedule` | every fit waits for a 1 s stable area | the first fit must not use pre-rotation geometry; one path |
| `remote_page.dart` `dispose` | one added `_duoResolution.dispose();` | a pending timer must not outlive the session |
| Non-Duo, landscape, non-macOS peers | none (deck not built, or unchanged guards return) | - |
| Host, plugin, split, strip | untouched | - |

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no blocking findings.

| Nit | Disposition |
|---|---|
| Test title "uses up the session" untrue | fixed: renamed to "... and settles the area" |
| D2/D3 rows relabelled against the spec; R1 has no test | fixed: rows match the spec's D2/D3; R1 stated as resting on the H1 analysis and the device repro |
| Repeated no-op 1 s timer when a guard never holds | known limit (above), no code change |
| Timer re-reads the area at fire time | known limit (above), no code change |

## Verify

Captain gate after the rename, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 81 passed; `flutter analyze` on `duo_resolution.dart`, `remote_page.dart` and the resolution test: the 2 pre-existing infos in `remote_page.dart` (507 `WillPopScope`, 1399 `withOpacity`), none new.
