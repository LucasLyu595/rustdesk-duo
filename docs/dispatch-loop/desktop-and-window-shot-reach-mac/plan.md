---
name: desktop-and-window-shot-reach-mac-plan
description: "Plan to send the Duo strip's Desktop button to a Mac peer as map-mode F11 through a (name, modifiers) lookup shared with Mission, and to turn Shot into Window (Cmd+Shift+5)."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: desktop-and-window-shot-reach-mac
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T20:08:50-08:00
---

# Plan: Desktop and Window reach the Mac

Spec: `docs/dispatch-loop/desktop-and-window-shot-reach-mac/spec.md` (stable). Base `90529daea`.
Dart only, two files, no Rust, no bridge, no new state. One implementer task.

## Files

| File | Change |
|---|---|
| `flutter/lib/mobile/duo/duo_shortcuts.dart` | one table row edited, one constant and one private lookup added, three lines of `duoPeerAwareSender` edited |
| `flutter/test/duo_status_strip_test.dart` | one table row edited, two assertions and two tests added |

Nothing else references the button id, the label or `kDuoMacMissionKeys` (grep over `flutter/lib`,
`flutter/test`). `docs/DUO.md` line 80 still says "Shot (Cmd+Shift+4)"; it is the captain's (R4).

## Code shapes (`duo_shortcuts.dart`)

1. Table row (lines 45-46), R2. The id becomes `window`, so the widget key is `duo-shortcut-window`
   and the test names what the button does. Position (fifth, inside `kDuoShortcutCore`) is unchanged.

   ```dart
   DuoShortcut('window', 'Window', Icons.web_asset, '5',
       command: true, shift: true),
   ```

   `Icons.web_asset` (a framed window with a title bar) exists in the pinned Flutter's `icons.dart`.

2. New constant after `kDuoMacMissionKeys`, R1:

   ```dart
   /// kVK_F11 as a real key event: a legacy F11 misses the Show Desktop hotkey.
   const List<DuoMapKey> kDuoMacDesktopKeys = [
     (103, true),
     (103, false),
   ];
   ```

3. New private lookup, placed before `duoPeerAwareSender`:

   ```dart
   /// The map-mode keys a Mac peer needs for this combo, or null for a legacy one.
   List<DuoMapKey>? _macMapKeys(String name,
       {required bool alt,
       required bool ctrl,
       required bool shift,
       required bool command}) {
     if (alt || shift || command) return null;
     if (name == 'VK_UP' && ctrl) return kDuoMacMissionKeys;
     if (name == 'VK_F11' && !ctrl) return kDuoMacDesktopKeys;
     return null;
   }
   ```

   The Mission match is the same predicate as today's `name == 'VK_UP' && ctrl && !alt && !shift && !command`.

4. `duoPeerAwareSender` body (lines 111-116): replace the `mission` boolean with the lookup. The
   signature, the `legacy` call, `unawaited` and `_sendInOrder` stay as they are.

   ```dart
   final keys = _macMapKeys(name,
       alt: alt, ctrl: ctrl, shift: shift, command: command);
   if (keys == null || !useMapKeys()) {
     legacy(name, alt: alt, ctrl: ctrl, shift: shift, command: command);
     return;
   }
   unawaited(_sendInOrder(keys, mapKey));
   ```

   `useMapKeys()` is still read only for a combo that has map keys (short-circuit), as today.
   Update the doc comment above it to: "Sends a combo that has Mac map keys through [mapKey] when
   [useMapKeys], and everything else through [legacy]."

`duoShortcutSender`, `_legacySender`, `_canSendKeys`, `_sendInOrder` and `DuoShortcutRow` are not touched.

## Test edits (`duo_status_strip_test.dart`)

- Combo table (line 72): `'window': ('5', false, false, true, true),`. This test uses the plain
  sender, so `desktop` stays `('VK_F11', false, false, false, false)` there.
- Same test, before the loop: `expect(find.text('Window'), findsOneWidget);` and
  `expect(kDuoShortcuts[kDuoShortcutCore - 1].id, 'window');` (label, and still the fifth button).
- New test after the Mission pair, reusing `pumpPeer` with `hold: true` so the order is pinned by the
  first key being held:

  ```dart
  testWidgets('Desktop on a Mac peer sends F11 down then up as map keys and no '
      'legacy key', (tester) async {
    final (legacy, map, gates) = await pumpPeer(tester, mac: true, hold: true);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    expect(map, [(103, true)]);
    gates.single.complete();
    await tester.pump();
    expect(map, [(103, true), (103, false)]);
    expect(legacy, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  ```

- New test: `'Desktop on another peer sends today\'s legacy F11'`, `pumpPeer(tester, mac: false)`,
  tap `duo-shortcut-desktop`, expect `legacy == [('VK_F11', false, false, false, false)]` and `map` empty.
- The three existing peer tests (Mission Mac, Mission other, Spotlight on Mac) are not edited and
  must stay green; they pin R3 for the generalised match.

No new helpers, mocks or production hooks. Test diff is about twice the fix or less.

## Regression surface

| Existing path | Behaviour change | Why unavoidable |
|---|---|---|
| `kDuoShortcuts` fifth row | id `screenshot`→`window`, label, icon, key `4`→`5` | R2 itself |
| `duoPeerAwareSender` closure | Desktop (bare `VK_F11`) on iOS + guards + macOS peer now goes to `mapKey`; Mission and every other combo take the same branch as before | R1; the match is where Mission already diverges |
| Desktop on a non-Mac peer, or guards failing | none (legacy `VK_F11`; a failed guard still falls to `_legacySender`, which drops it) | pinned by the new legacy test |
| Layout, Quit guard, strip, Rust, bridge | none | not touched |

## Implementer task (one)

1. Apply the four source edits and the test edits above; nothing else.
2. Focused gate, from `flutter/` in the worktree:
   - `~/development/flutter/bin/flutter test test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart test/duo_status_strip_test.dart test/duo_trackpad_test.dart` (all seven `test/duo_*_test.dart`), all green.
   - `~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart`, no new issue against base.
   - `git status --short` shows only the two files and the unit's docs dir (the gitignored bridge files stay untracked-ignored).
3. Minimisation pass per AGENTS.md: no formatting-only hunks, no other rows touched; report the
   regression surface in `results.md` with the gate commands and exit codes. Commit on the unit branch.

No `scripts/tests/` file is touched, so no repo lint applies beyond `flutter analyze`.

## Done-when mapping

D1: the two Desktop tests. D2: the combo row plus the label assertion. D3: untouched tests green and
the two-file diff. D4: the focused gate. D5 is Lucas's tap on the Duo after install, outside the gate.

## Forks and limits

- Id: `window` chosen over keeping `screenshot` (spec left it to the planner; no other reference
  exists). No captain ruling needed.
- Not provable here: that a map-mode F11 fires Show Desktop with the M6's F-keys set as media keys.
  The spec's rdev reading says the press keeps the function-key flags; only D5 confirms it. If D5
  fails, that is a new unit (a different key sequence), not a change to this one.
