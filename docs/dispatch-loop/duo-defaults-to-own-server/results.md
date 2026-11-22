---
name: duo-defaults-to-own-server-results
description: "Implementation results: iOS-only default settings fill the own RustDesk server name, relay and key at Rust init, with docs."
metadata:
  node_type: results
  type: project
  work_type: code
  status: draft
  work_unit: duo-defaults-to-own-server
  modified: 2026-11-22
  resource: src/duo_server.rs
generated:
  by: claude/sonnet
  session: 61eb65e5-a85b-4843-9812-40318c486dea
  at: 2026-11-22T04:09:22-08:00
---

# Results: duo-defaults-to-own-server

## Gate

1. `CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target cargo +stable test --locked --lib duo_server` — exit 0; `test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 232 filtered out`.
2. `CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target cargo +1.75 check --locked --features flutter,hwcodec --release --target aarch64-apple-ios --lib` — exit 0; no warning from `src/duo_server.rs` (existing warnings only).
3. `git status --short` shows only `docs/DUO.md`, `src/duo_server.rs`, the spec and this results dir modified in fix round 1 (`src/lib.rs` and `src/flutter_ffi.rs` untouched this round) — exit 0.

Candidate commit: 8a68d12d4 (fix round 1; review nits fixed by the captain in the next commit, docs only)

## Acceptance → tests

| Criterion | Proven by |
|---|---|
| 1. iOS defaults give server name, relay, key, allow-websocket "Y" and api-server (five entries, WebSocket through the Cloudflare Tunnel per the 2026-11-22 amendment) | `duo_server::tests::fill_defaults_sets_own_server_when_absent` (len 5, all five literal values); hook compiled by gate 2; the end-to-end result is checked on device (inspection, no test) |
| 2. User-set value wins | `duo_server::tests::fill_defaults_keeps_existing_entries` (pre-set `custom-rendezvous-server` unchanged, other four filled); precedence over stored options is hbb_common `get_or`, covered only by the on-device check |
| 3. Unit test pins the function, host-runnable | both `duo_server::tests::*` tests (local maps, no global state) |
| 4. Host and iOS check pass | gate 1 (host compile and tests) and gate 2 (iOS check), both exit 0 |
| 5. `docs/DUO.md` Remote access section | inspection: section replaced with the amendment text (wss via tunnel, check commands); no test |

## Deviations

- docs/DUO.md checks the M4 with `launchctl list | grep -E 'rustdesk|cloudflared'` (covers the tunnel too) plus the spec's `grep rustdesk-ws ~/.cloudflared/config.yml`.
- Review nit kept as is: `generated.by: claude/sonnet` is the launch alias, as the loop's native-producer contract requires; the resolved model claude-sonnet-5-5 is recorded in the dispatch log.

Cleanup: copied bridge files `src/bridge_generated.rs` and `src/bridge_generated.io.rs` left in place, untracked (gitignored).
