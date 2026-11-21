#!/usr/bin/env bash
# Build the app for a connected iPhone and install it, signed with your Apple account.
# Run it again to renew the install when a free account's 7-day signing runs out.
#
#   bash duo/install-ios.sh                    # the one iPhone connected by USB
#   DUO_DEVICE=<udid> bash duo/install-ios.sh  # pick the iPhone when more are connected
#   DUO_DEBUG=1 bash duo/install-ios.sh        # with the fold-detection overlay
#
# Needs a full `bash duo/build-ios.sh` once first (the Rust library) and the signing setup from
# docs/DUO.md. Run it in Terminal on the Mac itself: over SSH, Xcode cannot reach your account.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
logs="${DUO_LOGS:-$HOME/rustdesk-duo-logs}"
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -f "$root/target/aarch64-apple-ios/release/liblibrustdesk.a" ] ||
  die "Rust library missing: run bash duo/build-ios.sh first."

device="${DUO_DEVICE:-}"
if [ -z "$device" ]; then
  list="$(mktemp)"
  xcrun devicectl list devices --json-output "$list" >/dev/null
  device="$(python3 - "$list" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
wired = [d["hardwareProperties"]["udid"] for d in devices
         if d["hardwareProperties"].get("platform") == "iOS"
         and d["connectionProperties"].get("transportType") == "wired"]
print(wired[0] if len(wired) == 1 else "")
EOF
)"
  rm -f "$list"
  [ -n "$device" ] || die "connect exactly one iPhone by USB, or set DUO_DEVICE (xcrun devicectl list devices)."
fi

defines=""
[ "${DUO_DEBUG:-0}" = "1" ] && defines="--dart-define=DUO_DEBUG=true"

mkdir -p "$logs"
echo "== Flutter settings (DUO_DEBUG=${DUO_DEBUG:-0})"
(cd "$root/flutter" && flutter build ios --config-only --release $defines)

echo "== Build and sign for $device"
(cd "$root/flutter/ios" && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination "id=$device" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -derivedDataPath "$logs/dd" build)

echo "== Install"
xcrun devicectl device install app --device "$device" \
  "$logs/dd/Build/Products/Release-iphoneos/Runner.app"
echo "Installed. Open RustDesk on the iPhone."
