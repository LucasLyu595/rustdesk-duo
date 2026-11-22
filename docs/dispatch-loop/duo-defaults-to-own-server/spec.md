---
name: duo-defaults-to-own-server-spec
description: "The iPhone Duo build uses Lucas's own RustDesk server (ID, relay, key) by default instead of RustDesk's public servers."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-defaults-to-own-server
  modified: 2026-11-22
generated:
  by: claude/claude-opus-5-5
  session: 61eb65e5-a85b-4843-9812-40318c486dea
  at: 2026-11-22T03:55:28-08:00
---

# Duo defaults to own RustDesk server

## Intent

Lucas runs his own RustDesk server (`hbbs` + `hbbr`) on his M4, reachable only on his tailnet
at `100.116.70.51`, with the DNS name `rustdesk.lucasagenda.dpdns.org` (an A record to that address, DNS only). The iPhone Duo app (this fork, branch `duo-mode`) must use that server for
the ID server, the relay and the key without Lucas typing anything into the app.

## Decided approach

`hbb_common` has no compile-time env for the server (its `RENDEZVOUS_SERVERS` and `RS_PUB_KEY`
are plain consts, and it is a submodule we must not change). It does have
`config::DEFAULT_SETTINGS`: a map that `Config::get_option` falls back to when the user has not
set an option, and that `get_rendezvous_server`, `get_rendezvous_servers` and
`common::get_key` (iOS path: `Config::get_option("key")`) all read through. So:

- On iOS only (`#[cfg(target_os = "ios")]`), at Rust init (`src/flutter_ffi.rs` `initialize`),
  put these three entries into `config::DEFAULT_SETTINGS` **only where the key is absent**
  (a custom-client config loaded before it keeps precedence):
  - `custom-rendezvous-server` = `rustdesk.lucasagenda.dpdns.org`
  - `relay-server` = `rustdesk.lucasagenda.dpdns.org`
  - `key` = `OT7S8Kovaw7vaBs6vvW2ZmxN6Mklh0NvNF8dOBE5zpk=` (the M4 server's `id_ed25519.pub`)
- It must run before the first network use in `initialize` (the iOS block calls
  `test_nat_type()`, which talks to the rendezvous server) and after the custom-client load.
- New logic lives in a self-contained function in a new or Duo-specific module; the call site in
  `initialize` is a one-line, `cfg`-gated hook. Use the option-key constants from
  `base::config::keys` if they exist there; otherwise the string literals, as nearby code does.
- The values are constants in that module. They are public: a tailnet IP and a public key.
  Nothing secret is committed.

Because these are defaults, not stored options: a value Lucas sets in the app's ID/relay server
settings still wins, and clearing it falls back to his own server, not to RustDesk's.

## Hard constraints

- Do not touch `libs/hbb_common` (submodule).
- No change on non-iOS targets: Android, desktop and web behave exactly as before.
- No change to Dart/Flutter code and no FFI signature change.
- Follow AGENTS.md: no `unwrap()` beyond lock acquisition, one `use` per crate, minimal comments,
  minimal diff, thin hook in shared code.
- Do not stage `flutter/ios/Runner.xcodeproj/project.pbxproj` (Lucas's local signing edit).

## Done looks like

1. On iOS, with no user-set options, `Config::get_rendezvous_server()` returns
   `rustdesk.lucasagenda.dpdns.org:21116`, `Config::get_option("relay-server")` returns `rustdesk.lucasagenda.dpdns.org`, and
   `common::get_key(true)` returns the server key.
2. A user-set `custom-rendezvous-server` still wins over the default.
3. A Rust unit test pins (1) and (2) for the new function. Because CI does not run iOS tests,
   the function that fills the map is not itself iOS-gated (or is `#[cfg(any(target_os = "ios",
   test))]`), so its test runs on the host with `cargo test`; only the hook in `initialize` is
   iOS-gated. The test must not leak defaults into other tests' global state (clean up the
   entries it added, or assert on a local map passed in).
4. `cargo check` for the host passes, and `cargo check --target aarch64-apple-ios --lib`
   (with the features `duo/build-ios.sh` uses) passes, or the iOS Rust build via
   `duo/build-ios.sh` passes.
5. `docs/DUO.md` gets a short "Remote access" section: the Duo and the M6 go through Lucas's own
   RustDesk server on the M4 over Tailscale only; keep Tailscale on (on the Duo when away from home);
   how to check the server is up (`nc -vz rustdesk.lucasagenda.dpdns.org 21116` / `21117`, and
   `launchctl list | grep rustdesk` on the M4); the server is not exposed to the internet. The
   captain writes or approves the exact text.

## Out of scope

- The M4 server setup and the M6 settings (done by the captain outside this unit).
- Any UI to show or edit the default.

## Amendment 2026-11-22: WebSocket through the Cloudflare Tunnel (supersedes the values above)

Lucas does not want to rely on Tailscale on the Duo. The server is now reached over WebSocket
through the M4's Cloudflare Tunnel: `wss://rustdesk-ws.lucasagenda.dpdns.org/ws/id` goes to `hbbs`
(127.0.0.1:21118) and `/ws/relay` to `hbbr` (127.0.0.1:21119). Source facts (hbb_common):
`allow-websocket` turns WebSocket on (`config.rs:2938`, off unless `Y`); for a domain the client
builds `ws(s)://host/ws/id` or `/ws/relay`, and uses `wss` (port 443) only when the `api-server`
option starts with `https` (`websocket.rs:513-531`).

The defaults are now five entries, each filled only where absent:

- `custom-rendezvous-server` = `rustdesk-ws.lucasagenda.dpdns.org`
- `relay-server` = `rustdesk-ws.lucasagenda.dpdns.org`
- `key` = `OT7S8Kovaw7vaBs6vvW2ZmxN6Mklh0NvNF8dOBE5zpk=`
- `allow-websocket` = `Y`
- `api-server` = `https://rustdesk-ws.lucasagenda.dpdns.org` (needed for `wss`; the tunnel answers
  404 for `/api/*`, so account and address-book calls fail cleanly)

Done items 1-3 apply to these five entries. Done item 5 (docs) now describes: WebSocket through
the Cloudflare Tunnel, no Tailscale needed on the Duo, the M6 uses the same settings, how to check
(`curl` WebSocket upgrade on both paths answers `101`; `launchctl list | grep rustdesk` and
`grep rustdesk-ws ~/.cloudflared/config.yml` on the M4), and that the server is now reachable from
the internet, protected by the key and the M6 password. No IP allow list.
