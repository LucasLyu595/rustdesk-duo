---
name: duo-defaults-to-own-server-plan
description: "Plan to make the iPhone Duo build fall back to Lucas's own RustDesk server (ID, relay, key) through iOS-only default settings filled at Rust init."
metadata:
  node_type: plan
  type: project
  status: stable
  work_unit: duo-defaults-to-own-server
  modified: 2026-11-22
generated:
  by: claude/claude-fable-5-2
  session: 61eb65e5-a85b-4843-9812-40318c486dea
  at: 2026-11-22T03:58:17-08:00
---

# Plan: Duo defaults to own RustDesk server

Spec: `docs/dispatch-loop/duo-defaults-to-own-server/spec.md` (stable). Scope is unchanged.

## Approach

One new module holds three constants and one function that fills a settings map where a key is
absent. `initialize` in `src/flutter_ffi.rs` calls it on `config::DEFAULT_SETTINGS` inside the
existing iOS block. `Config::get_option` (hbb_common `get_or`: overwrite, then stored options,
then defaults) does the rest, so `get_rendezvous_server`, `get_rendezvous_servers` and the iOS
path of `common::get_key` pick the values up with no other change.

Checked in the tree:

- `base::config::keys` has all three constants: `OPTION_CUSTOM_RENDEZVOUS_SERVER` and
  `OPTION_KEY` are defined in `libs/base/src/config/keys.rs` (lines 76, 78);
  `OPTION_RELAY_SERVER` is defined in hbb_common and re-exported from the same path (line 330).
  Use all three from `base::config::keys`.
- `Config::set_option(k, "")` removes the stored value (`is_option_can_save` is true for an
  empty value unless the default is also empty), so clearing the field in the app falls back to
  the default. A stored value equal to the default is dropped too, which is harmless.
- In `initialize`, the custom-client load is lines 53-57 and is synchronous; the iOS block is
  lines 74-79 and its `test_nat_type()` is the first network use.
- On iOS nothing reads the `relay-server` option for outgoing sessions
  (`src/rendezvous_mediator.rs` is not compiled there; the client takes the relay from the hbbs
  reply). The default is set because the spec asks for it and it shows in the settings page; the
  relay actually used is the one hbbs on the M4 hands out.

## Files touched

| File | Change | Notes |
|---|---|---|
| `src/duo_server.rs` | new | constants, `fill_defaults`, `#[cfg(test)] mod tests` |
| `src/lib.rs` | +2 lines | `#[cfg(any(target_os = "ios", test))]` + `mod duo_server;`, placed after `mod custom_server;` |
| `src/flutter_ffi.rs` | +1 line | hook inside the existing `#[cfg(target_os = "ios")]` block of `initialize` |
| `docs/DUO.md` | +1 section | "Remote access", text below |
| `docs/dispatch-loop/duo-defaults-to-own-server/results.md` | new | implement-stage results |

No other file. Not `libs/hbb_common`, no Dart, no `src/lang`, no workflow file (the Linux CI job's
`cargo test --workspace` already runs the new tests). Do not stage
`flutter/ios/Runner.xcodeproj/project.pbxproj`. Stage explicit paths only.

### `src/duo_server.rs`

```rust
use base::config::keys::{OPTION_CUSTOM_RENDEZVOUS_SERVER, OPTION_KEY, OPTION_RELAY_SERVER};
use std::collections::HashMap;

const SERVER: &str = "rustdesk.lucasagenda.dpdns.org";
const KEY: &str = "OT7S8Kovaw7vaBs6vvW2ZmxN6Mklh0NvNF8dOBE5zpk=";

pub(crate) fn fill_defaults(defaults: &mut HashMap<String, String>) {
    for (k, v) in [
        (OPTION_CUSTOM_RENDEZVOUS_SERVER, SERVER),
        (OPTION_RELAY_SERVER, SERVER),
        (OPTION_KEY, KEY),
    ] {
        defaults.entry(k.to_owned()).or_insert_with(|| v.to_owned());
    }
}
```

At most one comment, above the constants, that says why they may be committed (tailnet address
and public key of the own server on the M4). No logging. No `unwrap`.

### Hook in `src/flutter_ffi.rs`

Inside the existing iOS block, one new line directly above `crate::common::test_nat_type();`
(so: after the custom-client load, before the first network use, no new `cfg` attribute):

```rust
        crate::duo_server::fill_defaults(&mut config::DEFAULT_SETTINGS.write().unwrap());
```

`config` is already in scope there (line 50 uses `config::APP_DIR`). The `unwrap` is lock
acquisition, which AGENTS.md permits. The guard is a temporary and drops at the end of the
statement, before `test_nat_type()`. No import block changes.

## Tests

Two tests in `duo_server::tests`, both on a local `HashMap`, no global state:

1. `fill_defaults_sets_own_server_when_absent`: empty map in; asserts
   `custom-rendezvous-server` and `relay-server` are `rustdesk.lucasagenda.dpdns.org`, `key` is the M4 key, and
   the map has exactly three entries. The test spells the option names and values as literals,
   so a changed constant fails it.
2. `fill_defaults_keeps_existing_entries`: map with `custom-rendezvous-server = "example.com"`
   (as a custom-client config would leave it); after the call that entry is unchanged and the
   other two are filled.

No test goes through `Config::get_rendezvous_server()`. Reason: it reads the process-wide
`DEFAULT_SETTINGS` (other tests read it in parallel: `trusted_devices`, `hbbs_http::sync`) and
`CONFIG2`, which on the host loads the real `RustDesk2.toml`. On the M6 that file already points
at this server, so such a test could neither stay isolated nor tell the default from the stored
value. See fork 1.

## Gates (implementer, in this order)

All from the worktree, with `export PATH="$HOME/.cargo/bin:$PATH"`. `VCPKG_ROOT=/Users/lucas/vcpkg`
(has `arm64-osx` and `arm64-ios`). Times are estimates; nothing was built at plan time.

Target dir: use `CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target` for both. This is sound:
cargo locks the directory per build, and artifact hashes include the rustc version and the
package path, so stable and 1.75 output and the two checkouts do not overwrite each other. It
only saves the registry crates and build scripts that match; the worktree's workspace crates
rebuild. Two limits: (a) run `cargo check`, never `cargo build`, for iOS from the worktree,
because a build would replace `target/aarch64-apple-ios/release/liblibrustdesk.a` that
`duo/build-ios.sh --app-only` in the main checkout installs; (b) a build in the main checkout at
the same time waits on the lock.

1. Host tests. Toolchain `stable` (1.100.0; 1.75 cannot build the macOS root crate, CI uses
   1.81 there). No `flutter` feature, so the gitignored bridge files are not needed. There is no
   host debug build in the shared target dir, so the first run is a full dev build: about
   5-10 min, then seconds.

   ```
   CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target cargo +stable test --locked --lib duo_server
   ```

   Pass: `2 passed`. A filter that matches nothing also exits 0, so read the count.
   This run is also the host compile check of Done item 4 for the default feature set; the
   hook line itself is not compiled on the host (it is in an iOS-only block).

2. iOS check. Toolchain `1.75` with the `aarch64-apple-ios` target (installed), features and
   profile as `duo/build-ios.sh`. First copy the two gitignored bridge files, which `mod
   bridge_generated` needs on iOS (no FFI change, so the main checkout's copies are valid):

   ```
   cp /Users/lucas/rustdesk-duo/src/bridge_generated.rs /Users/lucas/rustdesk-duo/src/bridge_generated.io.rs src/
   CARGO_TARGET_DIR=/Users/lucas/rustdesk-duo/target cargo +1.75 check --locked --features flutter,hwcodec --release --target aarch64-apple-ios --lib
   ```

   About 3-6 min (metadata only; build scripts are reused from the earlier iOS build). Pass: exit 0
   and no new warning from `src/duo_server.rs` or the hook line. This is the gate that compiles
   the hook.

3. `git status --short` shows only the files in the table (bridge files stay ignored);
   `git diff --stat` on `src/lib.rs` and `src/flutter_ffi.rs` shows additions only.

No `scripts/tests/` lint applies (this repo has none and the plan touches none). No full
`cargo test --workspace` and no `flutter build` in this unit. The device build
(`bash duo/build-ios.sh` in the main checkout after merge) and the on-device check of Done
item 1 and 2 are the captain's.

If gate 1 fails on stable for a reason outside this diff (old dependency against rustc 1.100),
stop and report it; do not patch dependencies. Fork 2 is the fallback.

## `docs/DUO.md` text

New section between "## Using it" and "## Debug overlay". Exact text:

```markdown
## Remote access

The Duo app uses your own RustDesk server by default. The server is on the M4, at the Tailscale
name `rustdesk.lucasagenda.dpdns.org`, which points at its Tailscale address `100.116.70.51`. The app has this name and the server key built in, so you do not
type them. The M6 uses the same server.

- Keep Tailscale on. The server is only on the tailnet; it is not open to the internet. When
  you are away from home, turn Tailscale on on the Duo before you connect.
- Connect from the Duo with the Mac's RustDesk ID and its password.
- The M6 accepts connections only from `100.64.0.0/10` (Tailscale) and `10.0.0.0/24` (home
  network).
- If you set an ID or relay server in the app's settings, the app uses that one. Clear the field
  to go back to your own server.

To check that the server is up, run this on a Mac that has Tailscale on:

    nc -vz rustdesk.lucasagenda.dpdns.org 21116
    nc -vz rustdesk.lucasagenda.dpdns.org 21117

Both must say `succeeded`. Port 21116 is the ID server (`hbbs`) and 21117 is the relay (`hbbr`).
If one fails, run this on the M4:

    launchctl list | grep rustdesk

It must show `com.lucas.rustdesk-hbbs` and `com.lucas.rustdesk-hbbr`. Their files are in
`~/rustdesk-server/` on the M4.
```

The last section, "The Mac side", still describes direct IP access. It stays as it is (it still
works on the tailnet); the captain may ask to reword it.

## Forks for the captain

1. Test of "a user-set value wins" (Done item 2). That precedence is hbb_common's `get_or`, not
   new code, and it cannot be tested from this crate without global and on-disk state. The plan
   pins what the new function owns (values, absent-only) and leaves precedence to the on-device
   check. Recommended: accept. Alternative: a third test that writes `DEFAULT_SETTINGS` and
   stored options and restores them; it would be host-state dependent and can race other tests.
2. Module location. The plan uses `src/duo_server.rs` (the hook's crate, as the spec and the
   task brief describe). If gate 1 cannot build the root crate on stable, the same function
   and tests can move to `libs/base/src/duo_server.rs` (`pub mod`, ungated, client-only crate,
   as AGENTS.md prefers) with the gate `cargo +stable test --locked -p base duo_server`, which
   builds only `hbb_common` and `base`. Do this only on the captain's ruling.

## Regression surface

| Existing file / path | What changes | Why it is needed |
|---|---|---|
| `src/flutter_ffi.rs` `initialize`, iOS block | one added call before `test_nat_type()` | the defaults must be in place before the first rendezvous use and after the custom-client load |
| `src/lib.rs` | module declaration, compiled only for iOS or `test` | the module must be in the crate; the gate keeps it out of every non-iOS product build |
| iOS runtime: every reader of options `custom-rendezvous-server`, `relay-server`, `key` with no stored value | returns the own-server value instead of empty | this is the requested behavior: `get_rendezvous_server(s)`, `get_key`, NAT test, the settings page (shows the three values), and the API server address derived from the ID server (`http://rustdesk.lucasagenda.dpdns.org:21114`; the M4 runs no API server, so account and address-book calls fail as they do for any self-hosted OSS server typed in by hand) |
| `docs/DUO.md` | one new section | Done item 5 |

Unchanged: Android, desktop and web builds (the module is not compiled, the hook is in an
iOS-only block), Dart code, FFI signatures, `libs/hbb_common`, and existing lines in both Rust
files (the diff only adds lines). An iOS build that loads a custom-client config with any of the
three defaults keeps that config's value.

## Captain amendments (2026-11-22)

- Server name: Lucas added the DNS name `rustdesk.lucasagenda.dpdns.org` (A record to
  `100.116.70.51`, DNS only) after this plan was written. The spec and this plan now use the name
  for `custom-rendezvous-server` and `relay-server`; the tests spell the name as the literal. The
  relay that `hbbs` hands out stays `100.116.70.51:21117` (set on the M4, not in this unit).
- Fork 1: accepted. No test through `Config::get_rendezvous_server()`; precedence is checked on
  the device.
- Fork 2: accepted as written. If gate 1 cannot build the root crate on stable for a reason
  outside this diff, the implementer may move `fill_defaults` and its tests to
  `libs/base/src/duo_server.rs` (`pub mod duo_server;` in `libs/base/src/lib.rs`, ungated), the
  hook calls `base::duo_server::fill_defaults`, `src/lib.rs` is then not touched, and gate 1
  becomes `cargo +stable test --locked -p base duo_server`. Record this in Deviations.
