---
name: mission-button-reaches-mac-spec
description: "The Duo strip's Mission button sends map-mode macOS keycodes (Control, Up) to a Mac peer, through the iOS raw-key entry point that is a stub today, so the Mac's Ctrl+Up Mission Control hotkey fires."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: mission-button-reaches-mac
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-22T19:45:58-08:00
---

# Spec: the Mission button reaches the Mac

Base: `duo-mode` at `5850aceaf` (unit `top-strip-sends-mac-shortcuts` merged as `26c3681b2`).
Worktree: `/Users/lucas/rustdesk-duo/.dispatch-workspaces/mission-button-reaches-mac` (branch
`unit/mission-button-reaches-mac`). Work type: `code`.

## Intent

Lucas tested the strip on 2026-11-22: Spotlight works, Mission does nothing on the M6. Make the
Mission button open Mission Control on a Mac peer. Ship and install it on the Duo.

## Facts (captain, read at base)

- Mission sends `bind.sessionInputKey('VK_UP', ctrl: true, press: true)`
  (`flutter/lib/mobile/duo/duo_shortcuts.dart`): a legacy `ControlKey::UpArrow` with a Control
  modifier.
- The M6 runs stock RustDesk 1.5.3 with the default Mission Control hotkey (Ctrl+Up, symbolic hotkey
  32 not overridden). The legacy macOS path posts keys with flags forced to the enigo flag set
  (`libs/enigo/src/macos/macos_impl.rs` 146-170; only F11 is excepted), so the arrow key loses the
  SecondaryFn/NumericPad flags macOS needs to match the Ctrl+Up hotkey. (Parent session's
  diagnosis; consistent with the code.)
- Map mode on the server: `handle_key_` → `KeyboardMode::Map` → `map_keyboard_mode` →
  `sim_rdev_rawkey_position(evt.chr(), evt.down)` with `RawKey::MacVirtualKeycode(code)` on macOS
  (`src/server/input_service.rs` 1621-1640, 1723-1735, 2530). So `chr` is the macOS virtual keycode:
  `kVK_Control` = 59 (0x3B), `kVK_UpArrow` = 126 (0x7E). rdev posts it as a real key event, so a
  held Control applies to the following Up, with the system's own arrow-key flags.
- `connection.rs` 3380-3435: a map-mode event with `press == false` goes to `input_key(me, false)`;
  a map-mode modifier (`keycode_to_rdev_key(chr)` is a modifier) is tracked in `pressed_modifiers`,
  which the server releases when the connection ends.
- Client: `Session::handle_flutter_raw_key_event` under `cfg(target_os = "ios")` is an empty stub
  (`src/ui_session_interface.rs` ~922-932). `session_handle_flutter_raw_key_event`
  (`src/flutter_ffi.rs` 640) is already bridged, so `bind.sessionHandleFlutterRawKeyEvent(sessionId,
  name, platformCode, positionCode, lockModes, downOrUp)` exists in Dart with no codegen.
  `Session::send_key_event(&KeyEvent)` (774) sends a prepared event; `swap_modifier_key` only
  touches `ControlKey` unions and modifiers.
- On a macOS server, a non-legacy `Chr` event goes through `LockModesHandler::new_handler`, which
  syncs Caps Lock to the event's `modifiers` (input_service.rs ~2510-2525, ~202-210). The planner
  checks what the legacy iOS path puts in `modifiers` (`_input_key`) and makes the map events match
  it, so the change does not alter the Mac's Caps Lock any differently than today's buttons.
- No host Rust test build exists (`target/debug/deps` absent); a host `cargo test` would build every
  dependency. The Rust gate is the iOS release build that the install needs anyway.

## Required behavior

R1. **iOS entry point.** In the iOS `handle_flutter_raw_key_event`, a call whose `name` is the one
Duo name `duo_map_key` sends one `KeyEvent` with `mode = Map`, `chr = platform_code`,
`down = down_or_up`, `press = false`, through `send_key_event`. Every other name does nothing, as
today. The logic lives in a small new function; the stub gets a one-line hook. Non-iOS code is not
changed.

R2. **Mission on a Mac peer.** When the peer platform is macOS, the Mission button sends, in order:
Control down (59), Up down (126), Up up (126), Control up (59), each through
`bind.sessionHandleFlutterRawKeyEvent(name: 'duo_map_key', ...)`, under the same send guards as
today (`keyboardInputAllowed`, `keyboardPerm`, not `isViewCamera`).

R3. **Everything else unchanged.** Mission on a non-macOS peer, and all other buttons on every peer,
send exactly what they send at base. No local state changes (armed deck modifiers untouched). The
button table, labels, layout and Quit guard are as at base.

R4. **Scope.** `src/ui_session_interface.rs` (iOS stub + one new iOS-only function),
`flutter/lib/mobile/duo/duo_shortcuts.dart`, and its test. No change to `flutter_ffi.rs`, the
generated bridge, `input_model.dart`, `remote_page.dart`, the server path or other platforms.

## Tests

- Dart: Mission on a macOS peer emits the four map events in order (code, down) and no legacy combo;
  on a non-macOS peer it emits today's legacy Ctrl+Up; another button (for example Spotlight) emits
  its legacy combo on a macOS peer. Through a fake sender; no new test infrastructure.
- Rust: no host unit test (impractical, see facts). The iOS release build is the compile gate.

## Done when

D1. R1: the iOS release library builds (`cargo +1.75 build --locked --features flutter,hwcodec
--release --target aarch64-apple-ios --lib`, exit 0) with the new function; inspection shows
non-iOS paths unchanged.
D2. R2/R3: the Dart tests pass; the existing strip tests stay green.
D3. R4: the diff touches only the files named in R4 (plus the unit's docs).
D4. Focused gate: `flutter test` on all `flutter/test/duo_*_test.dart`; `flutter analyze` on the
changed Dart files; no new issue.
D5. On the Duo (Lucas taps): Mission opens Mission Control on the M6; Spotlight still works.
