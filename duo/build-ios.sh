#!/usr/bin/env bash
# Build the RustDesk iPhone app (with the iPhone Duo changes) on a Mac, the way upstream CI does,
# but with Flutter 3.44 and Xcode 27.1 or later. See docs/DUO.md for setup and installing.
#
#   bash duo/build-ios.sh            # full build: bridge, vcpkg deps, Rust library, Flutter app
#   bash duo/build-ios.sh --app-only # reuse the bridge and Rust library from an earlier run
#   DUO_DEBUG=0 bash duo/build-ios.sh # without the fold-detection overlay
#
# Needs: Xcode 27.1+, Flutter 3.44.x on PATH, rustup, VCPKG_ROOT pointing at a vcpkg checkout,
# and `brew install nasm yasm cmake pkg-config`.
set -euo pipefail

RUST_VERSION="1.75"                     # matches upstream's iOS and bridge jobs
FRB_VERSION="1.80.1"                    # flutter_rust_bridge_codegen, as bridge.yml
CARGO_EXPAND_VERSION="1.0.95"
VCPKG_TRIPLET="arm64-ios"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
app_only=0
[ "${1:-}" = "--app-only" ] && app_only=1

say() { printf '\n== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

say "Checking tools"
[ "$(uname)" = "Darwin" ] || die "build on a Mac: iOS apps need Xcode."
xcode_ver="$(xcodebuild -version | awk '/^Xcode/ {print $2}')"
xcode_major="${xcode_ver%%.*}"
xcode_minor="$(printf '%s' "$xcode_ver" | awk -F. '{print ($2 == "" ? 0 : $2)}')"
if [ "$xcode_major" -lt 27 ] || { [ "$xcode_major" -eq 27 ] && [ "$xcode_minor" -lt 1 ]; }; then
  die "Xcode $xcode_ver found; the iPhone Duo needs an app built with Xcode 27.1 or later."
fi
command -v flutter >/dev/null || die "flutter not on PATH (install Flutter 3.44.x)."
flutter_ver="$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
case "$flutter_ver" in 3.44.*) ;; *) die "Flutter $flutter_ver found; this fork expects 3.44.x." ;; esac
echo "Xcode $xcode_ver, Flutter $flutter_ver"

# Upstream keeps CocoaPods; 3.44 would otherwise migrate Runner.xcodeproj to SwiftPM.
flutter config --no-enable-swift-package-manager >/dev/null

if [ "$app_only" -eq 0 ]; then
  command -v rustup >/dev/null || die "rustup not found (https://rustup.rs)."
  [ -n "${VCPKG_ROOT:-}" ] || die "set VCPKG_ROOT to your vcpkg checkout."

  say "Fetching submodules"
  git submodule update --init --recursive

  say "Rust $RUST_VERSION toolchain"
  rustup toolchain install "$RUST_VERSION" --profile minimal
  rustup target add aarch64-apple-ios --toolchain "$RUST_VERSION"

  say "Flutter packages"
  (cd flutter && flutter pub get)

  say "Generating the Rust/Dart bridge"
  if ! command -v flutter_rust_bridge_codegen >/dev/null ||
     ! flutter_rust_bridge_codegen --version 2>/dev/null | grep -q "$FRB_VERSION"; then
    cargo +"$RUST_VERSION" install cargo-expand --version "$CARGO_EXPAND_VERSION" --locked
    cargo +"$RUST_VERSION" install flutter_rust_bridge_codegen --version "$FRB_VERSION" --features uuid --locked
  fi
  RUSTUP_TOOLCHAIN="$RUST_VERSION" flutter_rust_bridge_codegen \
    --rust-input ./src/flutter_ffi.rs \
    --dart-output ./flutter/lib/generated_bridge.dart \
    --c-output ./flutter/macos/Runner/bridge_generated.h
  cp ./flutter/macos/Runner/bridge_generated.h ./flutter/ios/Runner/bridge_generated.h

  say "vcpkg dependencies for $VCPKG_TRIPLET (slow the first time)"
  "$VCPKG_ROOT/vcpkg" install --triplet "$VCPKG_TRIPLET" --x-install-root="$VCPKG_ROOT/installed"

  say "Rust library (slow the first time)"
  cargo +"$RUST_VERSION" build --locked --features flutter,hwcodec --release \
    --target aarch64-apple-ios --lib
fi

[ -f target/aarch64-apple-ios/release/liblibrustdesk.a ] ||
  die "Rust library missing: run without --app-only first."

# Until the split layout lands, builds show the fold-detection overlay by default so you can
# check it on the Duo. DUO_DEBUG=0 turns it off.
defines=""
[ "${DUO_DEBUG:-1}" = "1" ] && defines="--dart-define=DUO_DEBUG=true"

say "Flutter iOS app"
(cd flutter && flutter build ios --release $defines)
echo
echo "Built flutter/build/ios/iphoneos/Runner.app."
echo "Install it from Xcode (open flutter/ios/Runner.xcworkspace, pick your iPhone, Run),"
echo "or: cd flutter && flutter install --release"
