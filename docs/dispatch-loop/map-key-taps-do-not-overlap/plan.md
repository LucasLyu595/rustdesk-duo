---
name: map-key-taps-do-not-overlap-plan
description: "One busy flag in the duoPeerAwareSender closure drops map-mode taps while a Mission or Desktop key sequence is running and is cleared in a finally."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: map-key-taps-do-not-overlap
  modified: 2026-11-26
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-26T02:38:31-08:00
---

# Plan: map-mode taps do not overlap

Spec: `docs/dispatch-loop/map-key-taps-do-not-overlap/spec.md` (R1-R4, D1-D3). Base `b20aba936`.
Files: `flutter/lib/mobile/duo/duo_shortcuts.dart`, `flutter/test/duo_status_strip_test.dart`. Nothing else.

## Code shape (`duoPeerAwareSender`, lines 135-151)

The arrow body becomes a block body so the closure can hold state; signature and doc comment unchanged.

```dart
DuoShortcutSender duoPeerAwareSender(
    {required bool Function() useMapKeys,
    required DuoShortcutSender legacy,
    required DuoMapKeySender mapKey}) {
  var busy = false;
  Future<void> run(Future<void> Function() sequence) async {
    busy = true;
    try {
      await sequence();
    } finally {
      busy = false;
    }
  }

  return (name, {required alt, required ctrl, required shift, required command}) {
    final keys = _macMapKeys(name,
        alt: alt, ctrl: ctrl, shift: shift, command: command);
    if (keys == null || !useMapKeys()) {
      legacy(name, alt: alt, ctrl: ctrl, shift: shift, command: command);
      return;
    }
    if (busy) return;
    if (identical(keys, kDuoMacDesktopKeys)) {
      unawaited(run(() => _sendDesktopThenDock(mapKey)));
      return;
    }
    unawaited(run(() => _sendInOrder(keys, mapKey)));
  };
}
```

- `busy = true` runs synchronously inside the tap (an async body runs up to its first `await`), so the
  flag is set before the first key leaves (R2). The `busy` check sits after the legacy branch (R3).
- `_sendInOrder`, `_sendDesktopThenDock`, `_macMapKeys`, `duoShortcutSender`, the row widget: untouched.
- No comment needed; no new import. Hand-format in the file's style; do not reformat the rest of the file.

## Tests (`duo_status_strip_test.dart`, `testWidgets` fake clock via `tester.pump(duration)`)

Helper: add `bool fail = false` to `pumpPeer` and, right after `map.add(...)`, one line
`if (fail && map.length == 1) return Future.error('refused');`. No other helper change.

T1 "a tap during a running Desktop sequence on a Mac peer sends nothing, and the next one after it
sends again" (`mac: true, hold: true`): tap Desktop, pump -> `[(103, true)]`; tap Desktop again and
tap Spotlight, pump -> map unchanged, `legacy == [('VK_SPACE', false, false, false, true)]` (R3);
complete the gate, pump; pump half of `kDuoMacDockDelay`, tap Mission, pump -> still two keys (single
guard, R1); pump the rest of the delay, pump -> exactly the six keys of the existing Desktop test; tap
Desktop, pump, pump `kDuoMacDockDelay`, pump -> the six keys twice (12 entries). Fails at base
(the second tap adds keys).

T2 "a Desktop sequence whose first key fails still lets the next tap send" (`mac: true, fail: true`):
tap Desktop, pump, pump `kDuoMacDockDelay`, pump -> six keys recorded; tap Desktop, pump, pump the
delay, pump -> 12. End each test with `pumpWidget(const SizedBox())` like its neighbours; add a
`pump()` where a microtask chain needs one more turn, never a real wait.

## Regression surface

| Existing path | Change | Why unavoidable |
| --- | --- | --- |
| `duoPeerAwareSender` declaration | arrow body -> block body, closure re-indented | the flag needs a scope that lives as long as the sender |
| Mac peer, Mission / Desktop tap | sequence wrapped in `run`; a tap while one is running is dropped | the requested behavior (R1, R2) |
| Legacy sends (other peers, other buttons) | none; branch returns before the `busy` check | R3 |
| `pumpPeer` test helper | one optional parameter, one line | T2 needs a failing first key |

## Notes for review (no fork, no scope change)

- `_sendInOrder` catches per key, so at base no sequence can throw: the `finally` is the release rule
  the spec asks for and protects later edits, and T2 pins the user-visible outcome but passes at base
  too. T1 is the fail-at-base regression test. Not adding a throwing seam to prove the `finally`.
- The flag is per sender; a strip rebuilt with a new sender starts unguarded, as R1 states.
- A sequence that never completes (bridge call that never returns) keeps the buttons ignored; at base
  the same hang leaves keys held. Known limit, no timer added.

## Implementer task (one)

1. Apply the code shape, add the helper parameter and T1/T2, run the gate, minimization pass over the
   diff (only the rows in the table), commit on `unit/map-key-taps-do-not-overlap`, write `results.md`.

## Focused gate (from `flutter/`; also the closing gate)

- `~/development/flutter/bin/flutter test test/duo_*_test.dart` -> all pass, including T1 and T2.
- `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart` -> no issues.
- `git status --short` -> only the two files and `docs/dispatch-loop/map-key-taps-do-not-overlap/`.
