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
| 7 | Fit the Mac's display mode to the picture when a session starts (`duo_resolution.dart`) | switch done: at session start the M6's 32-inch main display went from 2560x1440 to 800x600, and its menu bar text was readable on the Duo (2026-11-21). After disconnect it was back at 2560x1440 (confirmed on the M6) |
| 8 | Picture fills its width down to the deck (`duo_split.dart`, `duo_resolution.dart`) | first version checked on the Duo (2026-11-22): laptop pose, 4:3 picture 669x501 over the crease, no side bars; flat pose, 669x501 at full width with the deck below. Lucas then asked for step 9 in the laptop pose; the flat layout stays |
| 9 | Laptop pose: control row in the crease, 16:9 picture on it, status line above (`duo_split.dart`, `duo_deck.dart`, `duo_resolution.dart`, `duo_status_strip.dart`) | layout checked on the Duo (2026-11-22): status line "lucas-mm6.local · 7 ms · 00:57", 16:9 picture on the crease at full width, control row in the crease, keyboard below. The first build's auto-fit asked for 800x450, which macOS refused; fixed in step 10 |
| 10 | Auto-fit skips Mac modes macOS cannot set; status line in the flat pose too (`duo_resolution.dart`, `duo_split.dart`) | done on the Duo (2026-11-22): half folded, the M6 switched to 960x540 and its text was readable; open flat, the Duo reports the crease, so the layout matched the laptop pose (status line, 16:9 picture on the crease, control row in the crease) and the M6 was set to 960x540 again after the reconnect |
| 11 | No F1-F12 row: esc moves to the control row, the trackpad takes the freed height, keys keep their size (`duo_keyboard.dart`, `duo_deck.dart`) | built and installed on the Duo (2026-11-22, `de2c972fb`); confirmed on the Duo by screenshot (2026-11-22): esc in the control row, no F1-F12 row |
| 12 | Mac shortcut buttons in the top strip (`duo_shortcuts.dart`, `duo_status_strip.dart`) | on the Duo (2026-11-22): Spotlight worked, Mission did nothing on the M6; fixed in step 13 |
| 13 | Mission reaches a Mac: for a macOS peer it sends Control and Up as map-mode key events, since a legacy Ctrl+Up arrives without the arrow's flags and misses the Mission Control hotkey (`duo_shortcuts.dart`, `src/ui_session_interface.rs`) | built and installed on the Duo (2026-11-22, `b9706196c`); confirmed by Lucas on the Duo (2026-11-22): Mission Control opens, Spotlight still works |
| 14 | Desktop reaches a Mac as map-mode F11 (the legacy F11 missed Show Desktop); Shot becomes Window, Cmd+Shift+5 (`duo_shortcuts.dart`) | built and installed on the Duo (2026-11-22, `f7bfc711f`); confirmed by Lucas on the Duo (2026-11-23): Window capture works; Desktop worked and step 19 added the Dock |
| 15 | Keyboard: no right command or option (wider space bar, arrows unchanged); control and caps lock swap places (`duo_keyboard.dart`) | built and installed on the Duo (2026-11-22, `6d7fc5186`); confirmed on the Duo by screenshot (2026-11-22, 23:44) |
| 16 | Auto-fit runs again when the picture area changes (cover to inner screen, pose, rotation, also upside down), 1 s after it settles; before, the M6 kept the cover screen's 4:3 mode, so the picture was 4:3 with side gaps and no status line (`duo_resolution.dart`) | on the Duo (2026-11-22): after the cover-to-inner switch and rotation the picture was 16:9 at full width with no side gaps; upside down the strip was still missing, fixed in step 17 |
| 17 | Upside-down portrait: the iPhone orientation list gains UIInterfaceOrientationPortraitUpsideDown; without it iOS kept the status bar shown upside down and its padding pushed out the strip (`ios/Runner/Info.plist`) | checked on the Duo held upside down (2026-11-22, 23:44): strip "lucas-mm6.local · 37 ms · 23:44" with all eight buttons, no iOS status bar, 16:9 picture on the crease, control row and keyboard as in portrait |
| 18 | The window-capture button is labelled Win Shot with a screenshot icon (`duo_shortcuts.dart`); `install-ios.sh` now finds a network-connected iPhone; `duo/prep-worktree.sh` readies a linked worktree | installed on the Duo (2026-11-23, `c126ce221`); confirmed by Lucas on the Duo (2026-11-26): reads as a screenshot, window pick works |
| 19 | Desktop on a Mac also brings up the Dock: after the map-mode F11 it waits 200 ms and sends map-mode Ctrl+F3, the default "Move focus to the Dock" (`duo_shortcuts.dart`) | installed on the Duo (2026-11-23, `a8ac249d3`); confirmed by Lucas on the Duo (2026-11-26): desktop and Dock shown |
| 20 | Map-mode taps do not overlap: while Mission or Desktop (with its Dock step) runs, further Mission or Desktop taps are ignored; the guard is released in a finally (`duo_shortcuts.dart`) | installed on the Duo (2026-11-26, `3e87857c5`); covered by tests, no tap check needed |

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
   the cover screen. The Mac's screen sits on top and the keyboard and trackpad below it.
   - Half folded (laptop pose): the deck's control row sits in the crease, and the keyboard
     and trackpad start right below it. The Mac picture rests on the crease at full width. At
     the top, where the screen's corners are rounded, a thin line shows the Mac's name, the
     delay and the time. Below it is a row of Mac shortcut buttons: Mission (Ctrl+Up),
     Spotlight (Cmd+Space), Desktop (F11 for Show Desktop, then Ctrl+F3 to bring up the
     hidden Dock), Switch (Cmd+Tab), Win Shot (Cmd+Shift+5; on the M6 Shottr then lets you pick
     a window to capture), Copy (Cmd+C), Paste (Cmd+V) and Hold Quit (Cmd+Q; hold it, a tap
     does nothing). The buttons only send keys; armed deck modifiers stay as they are.
   - Open flat: the same thin line and buttons sit at the top, clear of the rounded corners, and the
     picture sits below it at full width. The Duo reports the crease when flat, so the layout is
     the same as half folded (control row in the crease). Without a reported crease the line
     would take the top 60 pt and the deck would start right below the picture.
   - Cover screen: the picture takes the top 45%.
   Turn the Duo sideways (landscape) for RustDesk's normal full-screen layout.
3. While the deck shows, RustDesk's bottom toolbar is hidden. Its buttons are on the slim row at
   the top of the deck: × disconnects; the screen button opens display settings, including
   Resolution; the keyboard button opens the iPhone keyboard (other languages, emoji,
   dictation); the mouse button shows touch and mouse help with the touch-mode switch; the chat
   and ⋮ buttons work as before.
4. When a session to a Mac starts with the deck showing, the app asks the Mac for the display
   mode whose shape is closest to the picture area and, of those, the lowest (largest text).
   Half folded, or flat with the crease reported, it picks the lowest mode wide enough to fill
   the width (16:9: 960x540 on the M6's display); Mac text then shows about 92% as large as at
   800x600. It skips modes under 540 pt tall: macOS lists them but refuses to set them. The fit
   runs once, in the pose the session starts in.
   The Mac returns to its own mode when the last session to it closes. Pick another mode under
   the screen button > Resolution.
5. Trackpad: slide one finger to move the pointer; tap to click; tap with two fingers to
   right-click; slide two fingers up or down to scroll; tap, then touch again and slide, to drag
   (select text, move windows).
6. Keyboard: laid out like a MacBook (no fn key; the arrows sit at the bottom right), with three
   changes: control sits where caps lock is on a Mac (left end of the A row), caps lock sits at
   the bottom left, and there is no right command or option, so the space bar runs up to the
   arrows. Tap shift, control, option or command, then the key (command then C is Cmd+C). The
   modifier lights up and lets go after the next key; tap it again to cancel. caps lock stays lit
   and types capitals until you tap it again. There is no F1-F12 row; esc is the first button of
   the control row. Option with a letter types the plain letter on a Mac; Option with arrows and
   Option-click work.

## Remote access

The Duo app uses your own RustDesk server by default. The server runs on the M4. The app
reaches it over WebSocket (`wss`, port 443) through the M4's Cloudflare Tunnel, at
`rustdesk-ws.lucasagenda.dpdns.org`. You do not need Tailscale on the Duo. The app has the
server name, the server key and the WebSocket setting built in, so you do not type them.

The M6 (the Mac you control) does NOT use WebSocket. The open-source server cannot register a
device over WebSocket: it answers `RegisterPk` with `NOT_SUPPORT`, and the Mac's log then shows
`unknown RegisterPkResponse`. So the M6 registers over the home network: its ID server and relay
server are the M4's LAN address `10.0.0.49`, with no API server and WebSocket off. `hbbs` runs with
`--mask 10.0.0.0/24` and the environment variable `LOCAL_IP=10.0.0.49`. When the M6 offers the LAN
relay to a Duo that comes in through the tunnel, `hbbs` replaces it with the public relay
(`-r rustdesk-ws.lucasagenda.dpdns.org:21117`), so the Duo reaches the same `hbbr` over `wss`.

Set the M6 options with `sudo /Applications/RustDesk.app/Contents/MacOS/RustDesk --option <key>
<value>`. Do not edit `RustDesk2.toml` directly: the root service syncs its own copy back. `sudo`
keeps your home folder, so afterwards give the file back to your user with `chown`. To check
that the M6 is registered, run this on the M4; it must list the M6's ID:

    sqlite3 ~/rustdesk-server/db_v2.sqlite3 'select id from peer'

- Connect from the Duo with the Mac's RustDesk ID and its password.
- The server can be reached from the internet. The server key and the Mac's password protect the
  Mac, so keep a strong permanent password on the Mac.
- All Duo sessions go through the relay on the M4, also at home. There is no direct connection.
- WebSocket stays on in this build; the app's "Use WebSocket" switch cannot turn it off. If you
  set another ID server in the app's settings, also set that server's key, and that server must
  offer WebSocket over HTTPS on port 443. Clear the fields to go back to your own server.

To check that the server is up, run this on any Mac:

    curl -si --http1.1 -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
      -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
      https://rustdesk-ws.lucasagenda.dpdns.org/ws/id | head -1

Do it again with `/ws/relay`. Both must show `101 Switching Protocols`. `/ws/id` is the ID
server (`hbbs`) and `/ws/relay` is the relay (`hbbr`). If one fails, run this on the M4:

    launchctl list | grep -E 'rustdesk|cloudflared'

It must show `com.lucas.rustdesk-hbbs`, `com.lucas.rustdesk-hbbr` and
`local.cloudflared.actuals`. The server files are in `~/rustdesk-server/` on the M4. The tunnel
rules are in `~/.cloudflared/config.yml`; `grep rustdesk-ws ~/.cloudflared/config.yml` must show
the two `/ws/id` and `/ws/relay` rules.

## Debug overlay

`DUO_DEBUG=1 bash duo/install-ios.sh` draws the fold band in orange and prints what the Duo
reports (`inner, book, 114°, … laptop yes`). Normal builds leave it out.

## Signing

- Free Apple account: the app expires 7 days after its provisioning profile was made. A reinstall
  alone does not renew it, because Xcode reuses a profile that is still valid. To renew, move the
  profile aside (`~/Library/Developer/Xcode/UserData/Provisioning Profiles/`, the one for
  `com.lucaslyu595.rustdesk-duo`), then run `bash duo/install-ios.sh`; Xcode makes a new 7-day
  profile. Last renewal: 2026-11-26, expires 2026-12-03 02:44 PST.
  A free account can't sign push notifications, so this fork drops upstream's push and Wi-Fi
  info entitlements (upstream's code uses neither).
- Paid Apple Developer Program ($99 a year): each install lasts a year.

## The Mac side

Stock RustDesk on the Mac: give it Screen Recording and Accessibility in System Settings, and
for Tailscale, enable direct IP access in RustDesk's settings and connect from the phone to the
Mac's Tailscale address.
