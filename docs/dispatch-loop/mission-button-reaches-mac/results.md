---
name: mission-button-reaches-mac-results
description: "Implements the Mission button's four map-mode macOS key events (Control, Up) through an iOS-only Rust hook and a peer-aware Dart sender; Dart gate green, iOS build left to the captain."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: mission-button-reaches-mac
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: ac74d2f297599e5a0
  at: 2026-11-22T19:53:30-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-22T19:57:15-08:00
---

# Results: the Mission button reaches the Mac

Candidate commit: 70771617b (unit/mission-button-reaches-mac, base 5850aceaf; captain commit of the implementer's working tree; results doc committed after)

Built as planned: `send_duo_map_key` (iOS-only) plus a one-line hook in the iOS `handle_flutter_raw_key_event` stub; `duoPeerAwareSender` wrapping the renamed base sender `_legacySender`; three tests. `isIOS` comes from `common.dart` (`import '../../common.dart' show isIOS;`); no import cycle or analyzer issue.

## Acceptance → tests

| Done-when | Proven by |
|---|---|
| D1 iOS release build | MISSING: captain's iOS release build (Rust checked by reading only; inspection: the diff to `src/ui_session_interface.rs` is added lines only, all `cfg(target_os = "ios")` or inside the iOS stub) |
| D2 Mission sends four map keys on a Mac peer; other peer and other buttons unchanged | `flutter/test/duo_status_strip_test.dart`: "Mission on a Mac peer sends the four map keys in order and no legacy combo", "Mission on another peer sends today's legacy Ctrl+Up", "another button on a Mac peer keeps its legacy combo"; existing strip tests unmodified and green |
| D3 diff touches only R4 files | Inspection: `git status --short` shows only `src/ui_session_interface.rs`, `flutter/lib/mobile/duo/duo_shortcuts.dart`, `flutter/test/duo_status_strip_test.dart` plus this docs dir |
| D4 focused gate | See Gate: all `duo_*_test.dart` green, analyze clean |
| D5 Duo tap | MISSING: Lucas's tap on the Duo (manual) |

## Gate

Prep: copied `generated_bridge.dart` and `generated_bridge.freezed.dart` from the main checkout, `flutter pub get`; no tracked file changed by it. Red-first: the new tests against the base `duo_shortcuts.dart` fail to load (no `duoPeerAwareSender`), then the new file was restored.

| Command | Exit status | Result |
|---|---|---|
| `flutter test test/duo_status_strip_test.dart` (base `duo_shortcuts.dart`, red run) | non-zero | "Some tests failed": test file does not compile against base |
| `flutter test test/duo_deck_test.dart test/duo_fold_test.dart test/duo_keyboard_test.dart test/duo_resolution_test.dart test/duo_split_test.dart test/duo_status_strip_test.dart test/duo_trackpad_test.dart` | exit 0 (reporter: "All tests passed!") | 66 passed, 0 failed |
| `flutter analyze lib/mobile/duo/duo_shortcuts.dart test/duo_status_strip_test.dart` | exit 0 (reporter: "No issues found!") | 0 issues |

## Deviations

None.

Known limits (plan section 7, not fixed): two Mission taps within milliseconds can interleave (both still end with Control up); a session closing mid-sequence skips Control up; the server's key-down cleanup (`fix_key_down_timeout`, `src/server/input_service.rs` 1020-1033) releases it only after 360 s, so the Mac can hold Control for up to 6 minutes; with `allow_swap_key` on, Mission is Cmd+Up, as at base.

Cleanup: copied untracked/gitignored `flutter/lib/generated_bridge.dart` and `flutter/lib/generated_bridge.freezed.dart` remain in the worktree (not staged); `flutter/.dart_tool` and pub outputs are ignored.

## Regression surface

| Existing file / path | Behaviour change | Why unavoidable |
|---|---|---|
| `src/ui_session_interface.rs` iOS `handle_flutter_raw_key_event` | was a no-op for every name; now sends one map key event when `name == "duo_map_key"`, still a no-op otherwise | R1; the only bridged iOS entry carrying a keycode and a down flag without codegen |
| same file, non-iOS builds | none (new code is `cfg(target_os = "ios")`) | n/a |
| `duoShortcutSender(ffi)` for Mission, iOS client, macOS peer, guards open | four awaited map events instead of one legacy Ctrl+Up | R2, the fix itself |
| `duoShortcutSender(ffi)` for every other button, any non-macOS peer, any blocked guard, Android | same `bind.sessionInputKey` call as base, reached through one extra closure (declaration renamed `_legacySender`, body unchanged) | the public name must stay so `duo_status_strip.dart` is not edited |
| `DuoShortcutSender`, `DuoShortcut`, `kDuoShortcuts`, `DuoShortcutRow`, layout, Quit hold | none | n/a |
| Server, other clients, web bridge | none | n/a |

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no blocking findings.

| Nit | Disposition |
|---|---|
| Stuck-Control cleanup overstated (360 s, not 10 s) | fixed: Known limits text corrected |
| A throwing bridge call skips Control up | fixed: `_sendInOrder` catches per key, logs with `debugPrint`, and continues, so the releases are still attempted |
| Real wiring (`isIOS`, guards, platform, bridge args) untested | accepted: spec allows a fake sender; D5 (Lucas's tap) covers it |
| Ordering test holds only the first key | accepted: every key goes through the same awaited loop; one held key proves the await |

## Verify

- D1, captain, in the worktree (gitignored `src/bridge_generated*.rs` copied from the main checkout, never staged): `CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target VCPKG_ROOT=/Users/lucas/vcpkg cargo +1.75 build --locked --features flutter,hwcodec --release --target aarch64-apple-ios --lib`: exit 0, `Finished release` in 1m 40s; the only `ui_session_interface.rs` warnings are pre-existing import lines 16 and 42.
- Captain Dart gate after the review fix, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 77 passed; `flutter analyze` on `duo_shortcuts.dart` and the strip test: exit 0, no issues.
