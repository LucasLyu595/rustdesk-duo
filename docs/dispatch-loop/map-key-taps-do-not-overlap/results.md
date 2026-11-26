---
name: map-key-taps-do-not-overlap-results
description: "One busy flag in the duoPeerAwareSender closure drops map-mode taps while a Mission or Desktop key sequence runs, released in a finally; two tests added."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: map-key-taps-do-not-overlap
  modified: 2026-11-26
generated:
  by: claude/sonnet
  session: ae22461ef97b1710f
  at: 2026-11-26T02:41:00-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-26T02:40:54-08:00
---

# Results: map-mode taps do not overlap

Candidate commit: 3bb1f48c1 (unit/map-key-taps-do-not-overlap, base b20aba936; captain commit of the implementer's working tree; results doc committed after)

## Acceptance → tests

| Done-when | Proven by |
| --- | --- |
| D1. R1-R3 pinned by the two tests | T1 "a tap during a running Desktop sequence ..." (R1 single guard incl. Mission, R3 Spotlight legacy not blocked, release after completion); T2 "a Desktop sequence whose first key fails still lets the next tap send" (R2). Red-first: T1 failed at base before the code change. |
| D2. Focused gate green | Gate table below |
| D3. Diff only in the two files and the unit's docs | `git status --short`: `duo_shortcuts.dart`, `duo_status_strip_test.dart`, unit docs only |

## Gate

| Command | Exit status | Result |
| --- | --- | --- |
| `flutter test test/duo_*_test.dart` (from `flutter/`) | exit 0 | 72 passed (red-first run before the code change: 1 failed, T1) |
| `flutter analyze lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart` | exit 0 | No issues found |

`flutter pub get` left no tracked file changed.

## Deviations

none

Cleanup: none

## Known limitations

- `_sendInOrder` catches per key, so the `finally` cannot be reached by a throw at base; T2 pins the user-visible outcome and passes at base too. T1 is the fail-at-base test.
- The flag is per sender; a strip rebuilt with a new sender starts unguarded.
- A sequence that never completes (bridge call that never returns) keeps the buttons ignored; no timer added.

## Regression surface

| Existing path | Change | Why unavoidable |
| --- | --- | --- |
| `duoPeerAwareSender` declaration | arrow body -> block body, closure re-indented | the flag needs a scope that lives as long as the sender |
| Mac peer, Mission / Desktop tap | sequence wrapped in `run`; a tap while one runs is dropped | the requested behavior (R1, R2) |
| Legacy sends (other peers, other buttons) | none; branch returns before the `busy` check | R3 |
| `pumpPeer` test helper | one optional parameter, one line | T2 needs a failing first key |

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no blocking findings.

| Nit | Disposition |
|---|---|
| New line 149 is 82 columns | fixed: parameter list wrapped; the two older over-80 comment lines in the same file (Dock keys, `_sendInOrder`, both from earlier Duo units) wrapped too; the file has no line over 80 |
| T2 passes at base | accepted: `_sendInOrder` swallows per-key errors, so T1 is the regression test; T2 guards the `finally` against later edits (disclosed in the plan) |

## Verify

Captain gate after the wrap, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 83 passed; `flutter analyze` on the two files: exit 0, no issues.
