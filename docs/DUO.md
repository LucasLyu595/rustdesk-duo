# RustDesk for iPhone Duo (personal fork)

A fork of [RustDesk](https://github.com/rustdesk/rustdesk) that adds an iPhone Duo mode to the
iPhone app: half-folded like a laptop, the Mac's screen above the fold and a keyboard and
trackpad below it. The Mac side is stock RustDesk; nothing changes there.

Licence: AGPL-3.0, like upstream. Keeping the app to yourself asks nothing more; giving anyone
the built app means offering them this fork's source too.

## Status

| Step | What | State |
| --- | --- | --- |
| 1 | Build with Flutter 3.44 and Xcode 27.1, so the app fills the Duo's inner screen | done, untested on a device |
| 2 | Detect the fold (`flutter/lib/mobile/duo/`, via the MIT [duo_display](https://github.com/Geekles007/duo_display) plugin) | done, debug overlay only |
| 3 | Split the remote page at the fold | next |
| 4 | Keyboard and trackpad deck below the fold | after 3 |

Why the rebuild matters: on the iPhone Duo, apps built with an SDK older than iOS 27.1 run in a
smaller compatibility window on the inner display and get no fold information. Upstream's iOS
job builds with Flutter 3.24.5.

## One-time setup on the Mac

1. Xcode 27.1 or later, opened once to install its components. Sign in under
   Xcode > Settings > Accounts with your Apple ID (a free account works; see Signing below).
2. Homebrew packages: `brew install nasm yasm cmake pkg-config`
3. Flutter 3.44.x on `PATH` (`flutter --version` should say 3.44).
4. rustup (https://rustup.rs). The build script installs Rust 1.75, which upstream uses for iOS.
5. vcpkg: `git clone https://github.com/microsoft/vcpkg ~/vcpkg && ~/vcpkg/bootstrap-vcpkg.sh`,
   then `export VCPKG_ROOT=~/vcpkg` (add it to your shell profile).
6. Your signing details: `bash duo/setup-ios-signing.sh <TEAM_ID> <BUNDLE_ID>`
   (team ID from Xcode > Settings > Accounts; bundle ID any unused name such as
   `com.yourname.rustdesk-duo`). Leave that change uncommitted if the fork is public.
7. On the iPhone Duo: connect it by USB, trust the Mac, and turn on
   Settings > Privacy & Security > Developer Mode.

## Build and install

```sh
bash duo/build-ios.sh
```

The first run is slow: it builds ffmpeg and the other native libraries through vcpkg and the
Rust core. Later, after changing only Dart code: `bash duo/build-ios.sh --app-only`.

Then install: open `flutter/ios/Runner.xcworkspace` in Xcode, pick the iPhone Duo as the run
destination and press Run, or run `cd flutter && flutter install --release`.

## Checking the fold detection (step 2)

Builds include a debug overlay for now (turn it off with `DUO_DEBUG=0`). Connect to the Mac,
then fold the Duo halfway and hold it upright like a laptop. Expected: an orange band across
the crease and a line at the bottom left ending in `laptop yes`. Open flat it should say
`open … laptop no`; closed, `outer … laptop no`. The plugin has only been tested in the iOS
simulator, so what a real Duo shows here is the first thing to report back.

## Signing

- Free Apple account: the app expires after 7 days; rebuild and Run again from Xcode to renew.
  A free account can't sign push notifications, so this fork drops upstream's push and Wi-Fi
  info entitlements (upstream's code uses neither).
- Paid Apple Developer Program ($99 a year): each install lasts a year.

## The Mac side

Stock RustDesk on the Mac: give it Screen Recording and Accessibility in System Settings, and
for Tailscale, enable direct IP access in RustDesk's settings and connect from the phone to the
Mac's Tailscale address.
