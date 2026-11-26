---
name: map-key-taps-do-not-overlap-spec
description: "While a Duo map-mode key sequence (Mission, or Desktop with its Dock step) is running, further map-mode taps are ignored; the guard is released in a finally block."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: map-key-taps-do-not-overlap
  modified: 2026-11-26
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-26T02:37:29-08:00
---

# Spec: map-mode taps do not overlap

Base: `duo-mode` at `b20aba936`. Worktree:
`/Users/lucas/rustdesk-duo/.dispatch-workspaces/map-key-taps-do-not-overlap` (prepared with
`duo/prep-worktree.sh`). Work type: `code`.

## Intent

Close the known limit of unit `desktop-also-shows-dock`: a second Desktop tap within the 200 ms
pause can interleave its keys with the first. Lucas's rule (relayed): while a multi-key map-mode
sequence is running, ignore further taps; release the guard in a `finally`, so a failed key never
locks the button.

## Facts (at base)

`flutter/lib/mobile/duo/duo_shortcuts.dart`: `duoPeerAwareSender` (135) picks map keys through
`_macMapKeys`; Desktop runs `unawaited(_sendDesktopThenDock(mapKey))` (147), Mission
`unawaited(_sendInOrder(keys, mapKey))` (150). `_sendInOrder` catches per key, so it never throws.

## Required behavior

R1. One guard per sender (state in the `duoPeerAwareSender` closure; one sender per session strip):
while any map-mode sequence started by that sender is running, a further map-mode tap (Mission or
Desktop) sends nothing. A single guard for both sequences, not one per button, so Mission's and
Desktop's Control keys can never interleave either.
R2. The guard is set before the sequence starts and cleared in a `finally` after it ends, whether
it completes or a key fails.
R3. Legacy sends (non-Mac peers, every other button) are never blocked.
R4. Scope: `duo_shortcuts.dart` and `flutter/test/duo_status_strip_test.dart` (plus the unit's docs).

## Tests

- Two quick Desktop taps on a Mac peer send exactly one sequence (six keys); a tap after it
  finishes sends a second one.
- A sequence whose first key throws still releases the guard (the next tap sends again).
- Existing tests stay green.

## Done when

D1. R1-R3 pinned by the two tests. D2. Focused gate: `flutter test` on all duo tests and `flutter
analyze` on the two files. D3. Diff only in the two files and the unit's docs.
