---
name: mission-button-reaches-mac-plan
description: "Plan to make the Duo strip's Mission button send four map-mode macOS key events (Control, Up) to a Mac peer through a new iOS-only Rust function hooked into the empty iOS raw-key stub, leaving every other button and peer as at base."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: mission-button-reaches-mac
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T19:49:57-08:00
---

# Plan: the Mission button reaches the Mac

Spec: `docs/dispatch-loop/mission-button-reaches-mac/spec.md` (stable). Base `duo-mode` at `5850aceaf`.
Worktree `/Users/lucas/rustdesk-duo/.dispatch-workspaces/mission-button-reaches-mac`, branch
`unit/mission-button-reaches-mac`.

Reading note: `libs/hbb_common` is not initialised in the worktree (empty directory). Everything under `src/`
and `flutter/` was read in the worktree at base; `flutter/lib/generated_bridge.dart` and
`src/bridge_generated.rs` (both gitignored) were read in the main checkout `/Users/lucas/rustdesk-duo`; rdev
was read from the pinned checkout `~/.cargo/git/checkouts/rdev-946d845ad6d1f465/0904f23` (`Cargo.lock` 6751).

## 1. Settled facts (file:line, at base)

### 1.1 The wire event

| Field | Value | Why |
|---|---|---|
| `mode` | `KeyboardMode::Map` | `handle_key_` routes `Map` to `map_keyboard_mode` (`src/server/input_service.rs` 2530-2534) |
| union | `chr = platform_code` | `map_keyboard_mode` calls `sim_rdev_rawkey_position(evt.chr(), evt.down)` (1723-1735), which builds `RawKey::MacVirtualKeycode(code)` on macOS (1621-1640) |
| `down` | `down_or_up` | the same call; it is the only field that says press or release |
| `press` | `false` | `connection.rs` 3391-3435: off Linux `is_press = me.press`; false sends the event once through `input_key(me, false)`. `press = true` would make the server synthesize its own down+up |
| `modifiers` | empty | see 1.3 |

### 1.2 Keycodes

`kVK_Control = 59` and `kVK_UpArrow = 126` (rdev `src/keycodes/macos_virtual_keycodes.rs` 86, 124), mapped to
`ControlLeft` and `UpArrow` (`src/keycodes/macos.rs` 94, 157). rdev posts a raw-keycode **press** as
`CGEvent::new_keyboard_event(source, keycode, true)` with no flag rewrite (`src/macos/simulate.rs` 145-158;
`workaround_fn`, which strips SecondaryFn/NumericPad from arrows, runs on release only, 188-199). The server's
event source is `CombinedSessionState` (`input_service.rs` 716-717), so the Up press carries the system's own
arrow flags plus Control while Control is held. That is what the legacy path cannot give. The M6 runs stock
1.5.3, whose rdev was not read; D5 on the device is the proof.

### 1.3 Caps Lock: the map events carry no modifiers

- Today's buttons: `_input_key` (`src/ui_session_interface.rs` 1127-1165) fills `modifiers` only through
  `legacy_modifiers` (`src/keyboard.rs` 425-456): Alt, Shift, Control, Meta. It never adds `CapsLock` or
  `NumLock`.
- macOS server: every legacy event and every non-legacy `Chr` event builds a `LockModesHandler`
  (`input_service.rs` 2497-2526; both `skip_led_sync_*` functions return `false` on macOS, 2414-2417 and
  2459-2462). `LockModesHandler::new` on macOS (239-262) reads only whether `modifiers` contains `CapsLock`
  and releases the server's virtual Caps Lock when it does not.
- So an event with empty `modifiers` gives exactly the Caps Lock outcome of today's legacy Ctrl+Up
  (`CapsLock` absent in both). The map events must not add `CapsLock`, and must not add `Control` either: map
  mode ignores `modifiers` for the key itself, and the real Control key event supplies it.

### 1.4 Corrections to the spec's facts (no scope change)

- `swap_modifier_key` also rewrites `chr` when the `allow_swap_key` toggle is on (`ui_session_interface.rs`
  729-770): on a macOS peer 59 (Control) becomes Meta's keycode. Base behaves the same way (it swaps the legacy
  `Control` modifier to `Meta`, 712-727), so with that toggle on Mission is Cmd+Up before and after. No action.
- On a macOS server a map modifier with `press == false` is never inserted into `pressed_modifiers`
  (`connection.rs` 3416-3422). The held key is tracked by `record_pressed_key` in `KEYS_DOWN`
  (`input_service.rs` 1635, 2123-2130) and released by `fix_key_down_timeout` (1020; 10 s loop at 932, forced
  at exit 945). The sequence releases Control itself 3 events later, so this only matters if the session dies
  mid-sequence.

### 1.5 Ordering across the bridge (drives the Dart design)

`sessionHandleFlutterRawKeyEvent` returns `Future<void>` and runs through `executeNormal`
(`flutter/lib/generated_bridge.dart` 3000-3029, main checkout); on the Rust side that is
`FLUTTER_RUST_BRIDGE_HANDLER.wrap` (`src/bridge_generated.rs` 1160-1172), whose executor is a thread pool
(`flutter_rust_bridge-1.80.1/src/handler.rs` 84-89, 177-189). Four calls fired without waiting can reach
`send_key_event` in any order. **Each call must be awaited before the next.** Once in the session's send queue
the order holds, and the macOS server spaces events itself (`handle_key` runs `key_sleep`, 12 ms, after each:
`input_service.rs` 1593-1605, 863-873), so no client-side delay is added.

### 1.6 Peer platform in Dart

`ffi.ffiModel.pi.platform` (`flutter/lib/models/model.dart` 4522) equals `kPeerPlatformMacOS` = `"Mac OS"`
(`flutter/lib/consts.dart` 39); same test as `desktop/pages/remote_page.dart` 1246.

## 2. Design

### 2.1 Rust (R1)

One new iOS-only method beside the stub; the stub gets one line. The stub's parameter names keep their
underscores so its signature lines are not touched.

```rust
    #[cfg(target_os = "ios")]
    fn send_duo_map_key(&self, name: &str, platform_code: i32, down: bool) {
        if name != "duo_map_key" {
            return;
        }
        let Ok(chr) = u32::try_from(platform_code) else {
            return;
        };
        let mut key_event = KeyEvent::new();
        key_event.set_chr(chr);
        key_event.down = down;
        key_event.mode = KeyboardMode::Map.into();
        self.send_key_event(&key_event);
    }
```

Hook, as the whole body of the iOS `handle_flutter_raw_key_event` (922-933):

```rust
        self.send_duo_map_key(_name, _platform_code, _down_or_up);
```

- `press` stays at its default `false`; `modifiers` stays empty (1.3). No new `use`: `KeyEvent` and
  `KeyboardMode` come from the existing `base::message_proto::*` (line 14) and are already used at 1146/1164.
- A negative code is dropped, as the non-iOS path does (`if position_code < 0 || platform_code < 0`, 969).
- Place the function directly above the iOS stub (before line 922), inside the same `impl`. No comment needed.
- `_keyboard_mode`, `_position_code`, `_lock_modes`, `_session_id` stay unused.

### 2.2 Dart (R2, R3): a peer-aware sender, built in `duo_shortcuts.dart`

Choice: **wrap the base sender in a peer-aware sender**; keep the `DuoShortcutSender` typedef, `DuoShortcut`,
`kDuoShortcuts` and `DuoShortcutRow` byte-identical.

Why not a map-key list on `DuoShortcut` plus a second callback: the callback would have to pass through
`DuoStatusStrip` (`duo_status_strip.dart` 31, 39, 123), which R4 puts out of scope, and adding a named
parameter to the typedef would make the existing test's fake sender unassignable, forcing edits to the tests
that must stay green. The wrapper needs neither; the strip keeps calling `duoShortcutSender(ffi)`.

Shapes (all in `flutter/lib/mobile/duo/duo_shortcuts.dart`):

```dart
/// One map-mode key: the peer's keycode, and whether it goes down.
typedef DuoMapKey = (int code, bool down);

typedef DuoMapKeySender = Future<void> Function(int code, bool down);

/// kVK_Control and kVK_UpArrow as real key events: a legacy Ctrl+Up reaches
/// the Mac without the arrow's own flags and misses the Mission Control hotkey.
const List<DuoMapKey> kDuoMacMissionKeys = [
  (59, true),
  (126, true),
  (126, false),
  (59, false),
];

/// Sends Mission as [kDuoMacMissionKeys] through [mapKey] when [useMapKeys],
/// and everything else through [legacy].
DuoShortcutSender duoPeerAwareSender(
        {required ValueGetter<bool> useMapKeys,
        required DuoShortcutSender legacy,
        required DuoMapKeySender mapKey}) =>
    (name,
        {required alt, required ctrl, required shift, required command}) {
      final mission = name == 'VK_UP' && ctrl && !alt && !shift && !command;
      if (!mission || !useMapKeys()) {
        legacy(name, alt: alt, ctrl: ctrl, shift: shift, command: command);
        return;
      }
      unawaited(_sendInOrder(kDuoMacMissionKeys, mapKey));
    };

/// The bridge runs each call on a pool thread, so each is awaited to keep the order.
Future<void> _sendInOrder(List<DuoMapKey> keys, DuoMapKeySender mapKey) async {
  for (final (code, down) in keys) {
    await mapKey(code, down);
  }
}
```

Wiring. The base function is renamed (its body is untouched; only its declaration line changes) and the public
name becomes the wrapper, so `duo_status_strip.dart` is not edited:

```dart
DuoShortcutSender _legacySender(FFI ffi) => (name, { ... }) { /* base body, unchanged */ };

bool _canSendKeys(FFI ffi) {
  final input = ffi.inputModel;
  return input.keyboardInputAllowed && input.keyboardPerm && !input.isViewCamera;
}

DuoShortcutSender duoShortcutSender(FFI ffi) => duoPeerAwareSender(
    useMapKeys: () =>
        isIOS &&
        _canSendKeys(ffi) &&
        ffi.ffiModel.pi.platform == kPeerPlatformMacOS,
    legacy: _legacySender(ffi),
    mapKey: (code, down) => bind.sessionHandleFlutterRawKeyEvent(
        sessionId: ffi.sessionId,
        name: 'duo_map_key',
        platformCode: code,
        positionCode: 0,
        lockModes: 0,
        downOrUp: down));
```

Points the implementer must keep:

- The guards are read **once per tap**, in `useMapKeys`, not per key: a permission that flips mid-sequence
  cannot strand Control down. When a guard fails the tap falls to `legacy`, whose own unchanged guard drops it,
  so a blocked tap sends nothing, as at base (R2 "same send guards").
- `isIOS` (`flutter/lib/common.dart`) keeps the new name off the Android raw-key path, where
  `handle_flutter_raw_key_event` would treat `duo_map_key` as a hardware key
  (`ui_session_interface.rs` 936-958). Android therefore sends the base legacy combo. If importing
  `common.dart` into this file causes an import cycle or analyzer issue, use
  `defaultTargetPlatform == TargetPlatform.iOS` from `package:flutter/foundation.dart` instead and say so in
  results.md.
- The combo match (`VK_UP` + Ctrl only) is the Mission row of `kDuoShortcuts` (line 39). No other row matches.
- New imports: `dart:async` (for `unawaited`), `../../consts.dart` (`kPeerPlatformMacOS`, same relative
  style as `duo_resolution.dart` 6), and `../../common.dart` for `isIOS`. Existing import lines stay.
- No local state: the deck's armed modifiers are not read or written (R3).

## 3. Files touched

| File | Change |
|---|---|
| `src/ui_session_interface.rs` | + `send_duo_map_key` (iOS-only, ~14 lines); + 1 line in the iOS stub body |
| `flutter/lib/mobile/duo/duo_shortcuts.dart` | + 2 typedefs, 1 const, `duoPeerAwareSender`, `_sendInOrder`, `_canSendKeys`, new `duoShortcutSender`; base sender's declaration renamed to `_legacySender`; + 3 imports |
| `flutter/test/duo_status_strip_test.dart` | + tests in section 4 (existing tests and the `pump` helper unchanged) |
| `docs/dispatch-loop/mission-button-reaches-mac/results.md` | implement-stage results |

Not touched: `src/flutter_ffi.rs`, generated bridges, `flutter/lib/web/bridge.dart`, `input_model.dart`,
`remote_page.dart`, `duo_status_strip.dart`, `src/server/**`, `libs/**`, `src/lang/**`.

## 4. Tests (Dart only, per spec)

Added to `flutter/test/duo_status_strip_test.dart`, which already covers the shortcut row. A small local helper
pumps `DuoStatusStrip` at `Size(669, 79)` with
`send: duoPeerAwareSender(useMapKeys: () => mac, legacy: <records Sent>, mapKey: <records (code, down)>)`.
No new infrastructure, no test-only hook in production code.

1. **Mission on a Mac peer sends the four map keys in order and no legacy combo.** `mac = true`; the fake
   `mapKey` returns a future the test completes by hand for the first key. Tap `duo-shortcut-mission`, pump:
   expect map log `[(59, true)]` only (the second key waits for the first). Complete it, pump: expect
   `[(59, true), (126, true), (126, false), (59, false)]` and the legacy log empty.
2. **Mission on another peer sends today's legacy Ctrl+Up.** `mac = false`; tap Mission: legacy log
   `[('VK_UP', false, true, false, false)]`, map log empty.
3. **Another button on a Mac peer keeps its legacy combo.** `mac = true`; tap `duo-shortcut-spotlight`:
   legacy log `[('VK_SPACE', false, false, false, true)]`, map log empty.

Each ends with `await tester.pumpWidget(const SizedBox())` like its neighbours. Tests 1 and 2 fail at base
(no `duoPeerAwareSender`), pass with the change. Three tests; keep the test diff under twice the Dart fix.

Rust: no host unit test (spec). The iOS release build is the compile gate.

## 5. Gates

### 5.1 Implementer (Dart, focused and closing)

Prep, once, in the worktree (the copied files are gitignored and must not be staged):

```
cp /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.dart /Users/lucas/rustdesk-duo/flutter/lib/generated_bridge.freezed.dart flutter/lib/
cd flutter && ~/development/flutter/bin/flutter pub get
```

Then, from `flutter/`:

```
~/development/flutter/bin/flutter test test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart test/duo_status_strip_test.dart test/duo_trackpad_test.dart
~/development/flutter/bin/flutter analyze lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart
```

Pass: all tests green (existing strip tests unmodified); analyze reports no issue that base does not report for
these two files (run analyze on the base versions first if any issue shows, and record both counts).
This repo has no `scripts/tests/` lints; none apply. Finally `git status --short` shows only the three
source/test files and the unit's docs dir.

### 5.2 Captain (Rust compile gate, D1) — the implementer does not run it

```
git submodule update --init --recursive   # in the worktree, if libs/hbb_common is empty
CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target VCPKG_ROOT=/Users/lucas/vcpkg cargo +1.75 build --locked --features flutter,hwcodec --release --target aarch64-apple-ios --lib
```

Pass: exit 0, no new warning from `src/ui_session_interface.rs`. Plus inspection: `git diff` of that file shows
only added lines, all under `#[cfg(target_os = "ios")]` or inside the iOS stub. The implementer checks the Rust
by reading only (let-else needs Rust 1.65; the build uses 1.75).

### 5.3 Device (D5, Lucas)

After install on the Duo: Mission opens Mission Control on the M6; Spotlight still works.

## 6. Regression surface

| Existing file / path | Behaviour change | Why unavoidable |
|---|---|---|
| `src/ui_session_interface.rs` iOS `handle_flutter_raw_key_event` | was a no-op for every name; now sends one map key event when `name == "duo_map_key"`, still a no-op otherwise | R1; the only bridged iOS entry that carries a keycode and a down flag without codegen |
| same file, non-iOS builds | none (new code is `cfg(target_os = "ios")`) | — |
| `duoShortcutSender(ffi)` for Mission, iOS client, macOS peer, guards open | four map events instead of one legacy Ctrl+Up | R2, the fix itself |
| `duoShortcutSender(ffi)` for every other button, any non-macOS peer, any blocked guard, Android | the same `bind.sessionInputKey` call as base, now reached through one extra closure | the public name must stay so the out-of-scope strip file is not edited |
| `DuoShortcutSender`, `DuoShortcut`, `kDuoShortcuts`, `DuoShortcutRow`, layout, Quit hold | none | — |
| Server, other clients, web bridge | none | — |

## 7. Known limits (document in results.md, do not fix)

- Two Mission taps within a few milliseconds can interleave their sequences; both still end with Control up.
- If the session closes mid-sequence the remaining awaits fail and Control up is not sent; the server's own
  key-down cleanup (1.4) covers it.
- With `allow_swap_key` on, Mission is Cmd+Up, as at base (1.4).

## 8. Implementer task (one)

Implement sections 2.1 and 2.2 and the three tests of section 4 exactly as shaped, in the worktree, on
`unit/mission-button-reaches-mac`. Follow `AGENTS.md`: additive diff, no unrelated edits, no formatting-only
changes, no new dependency, comments only where shown. Run gate 5.1; do not run cargo. Do a minimization pass
over the final diff and confirm it matches section 3. Write
`docs/dispatch-loop/mission-button-reaches-mac/results.md` with: the regression-surface table as built, gate
commands with exit status, the analyze base/after comparison if needed, which `isIOS` source was used, any
deviation from this plan, and the known limits of section 7. Commit the three files plus results.md with explicit
paths (not the copied generated bridge files); do not push or merge.
