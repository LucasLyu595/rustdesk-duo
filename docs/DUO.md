# RustDesk for iPhone Duo (personal fork)

A fork of [RustDesk](https://github.com/rustdesk/rustdesk) that adds an iPhone Duo mode to the
iPhone app: held upright, the Mac's screen on top and a Mac keyboard and trackpad below it (at
the fold when half-folded like a laptop). The Mac side is stock RustDesk; nothing changes there.

Licence: AGPL-3.0, like upstream. Keeping the app to yourself asks nothing more; giving anyone
the built app means offering them this fork's source too.

## Status

| Step | What | State |
| --- | --- | --- |
| 1 | Build with Flutter 3.44 and Xcode 27.1, so the app fills the Duo's inner screen | done; runs full-screen on the Duo (2026-11-21) |
| 2 | Detect the fold (`flutter/lib/mobile/duo/`, via the MIT [duo_display](https://github.com/Geekles007/duo_display) plugin) | done; on the Duo the debug overlay read inner, book, 114°, laptop yes, band across the middle (2026-11-21) |
| 3 | Split the remote page at the fold (`flutter/lib/mobile/duo/duo_split.dart`) | done; on the Duo in the laptop pose (book, 144°) the Mac picture sat above the fold, the band stayed empty, and the area below showed the placeholder (2026-11-21) |
| 4 | Keyboard and trackpad deck below the fold (`flutter/lib/mobile/duo/duo_deck.dart`) | done; on the Duo the trackpad moved the Mac pointer and Cmd, Space then typing reached Spotlight (2026-11-21) |
| 5 | Deck in every portrait pose, toolbar hidden, its buttons on the deck (`duo_split.dart`, `duo_deck.dart`) | done on the inner screen: the Mac picture sat above the fold, the deck below it, RustDesk's toolbar was gone and the session row showed (2026-11-21). The cover screen and the flat pose were not captured |
| 6 | MacBook keyboard layout (`duo_keyboard.dart`) | done: the MacBook layout showed on the inner screen and Lucas typed into the Mac through it (2026-11-21). caps lock was not captured |
| 7 | Fit the Mac's display mode to the picture when a session starts (`duo_resolution.dart`) | switch done: at session start the M6's 32-inch main display went from 2560x1440 to 800x600, and its menu bar text was readable on the Duo (2026-11-21). The return to 2560x1440 at disconnect was not yet seen |

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
Rust core. Then connect the iPhone Duo by USB and, in Terminal on the Mac itself (not over SSH:
Xcode cannot reach your Apple account there), install it:

```sh
bash duo/install-ios.sh
```

It builds the app, signs it with your account and installs it on the one iPhone connected by USB
(with more than one connected, set `DUO_DEVICE=<udid>` from `xcrun devicectl list devices`). After
changing only Dart code, `bash duo/install-ios.sh` alone is enough.

## Reinstall after 7 days

With a free Apple account the installed app stops opening after 7 days. Connect the Duo by USB,
unlock it, and run `bash duo/install-ios.sh` again in Terminal. Your RustDesk settings and peers
stay. A paid developer account makes each install last a year.

## Using it

1. Open RustDesk on the Duo and connect to your Mac as usual (ID or IP, then its password).
2. Hold the Duo upright (portrait) in any pose: half folded like a laptop, open flat, or shut on
   the cover screen. The Mac's screen sits on top and the keyboard and trackpad below it. Half
   folded or flat, the split is at the fold; on the cover screen the picture takes the top 45%.
   Turn the Duo sideways (landscape) for RustDesk's normal full-screen layout.
3. While the deck shows, RustDesk's bottom toolbar is hidden. Its buttons are on the slim row at
   the top of the deck: × disconnects; the screen button opens display settings, including
   Resolution; the keyboard button opens the iPhone keyboard (other languages, emoji,
   dictation); the mouse button shows touch and mouse help with the touch-mode switch; the chat
   and ⋮ buttons work as before.
4. When a session to a Mac starts with the deck showing, the app asks the Mac for the display
   mode whose shape is closest to the picture area and, of those, the lowest (largest text).
   The Mac returns to its own mode when the last session to it closes. Pick another mode under
   the screen button > Resolution.
5. Trackpad: slide one finger to move the pointer; tap to click; tap with two fingers to
   right-click; slide two fingers up or down to scroll; tap, then touch again and slide, to drag
   (select text, move windows).
6. Keyboard: laid out like a MacBook (no fn key; the arrows sit at the bottom right). Tap shift,
   control, option or command, then the key (command then C is Cmd+C). The modifier lights up
   and lets go after the next key; tap it again to cancel. caps lock stays lit and types
   capitals until you tap it again. esc and F1-F12 are in the thin top row. Option with a
   letter types the plain letter on a Mac; Option with arrows and Option-click work.

## Debug overlay

`DUO_DEBUG=1 bash duo/install-ios.sh` draws the fold band in orange and prints what the Duo
reports (`inner, book, 114°, … laptop yes`). Normal builds leave it out.

## Signing

- Free Apple account: the app expires after 7 days; run `bash duo/install-ios.sh` again to renew.
  A free account can't sign push notifications, so this fork drops upstream's push and Wi-Fi
  info entitlements (upstream's code uses neither).
- Paid Apple Developer Program ($99 a year): each install lasts a year.

## The Mac side

Stock RustDesk on the Mac: give it Screen Recording and Accessibility in System Settings, and
for Tailscale, enable direct IP access in RustDesk's settings and connect from the phone to the
Mac's Tailscale address.
