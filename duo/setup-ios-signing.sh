#!/usr/bin/env bash
# Point the iOS app at your own Apple team and a bundle ID of your own, so Xcode can sign it
# for your iPhone. Run once after cloning, from anywhere:
#
#   bash duo/setup-ios-signing.sh <TEAM_ID> <BUNDLE_ID>
#   e.g. bash duo/setup-ios-signing.sh ABCDE12345 com.example.rustdesk-duo
#
# TEAM_ID: Xcode > Settings > Accounts > your Apple ID > the team's ID (a free "Personal Team"
# works). BUNDLE_ID: any reverse-DNS name nobody else uses.
#
# This fork already ships without the push-notification and Wi-Fi-info entitlements (upstream
# uses neither in code, and a free Personal Team cannot sign push).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: bash duo/setup-ios-signing.sh <TEAM_ID> <BUNDLE_ID>" >&2
  exit 2
fi
team="$1"
bundle="$2"
if ! printf '%s' "$team" | grep -Eq '^[A-Z0-9]{10}$'; then
  echo "TEAM_ID should be 10 letters and digits, like ABCDE12345." >&2
  exit 2
fi
if ! printf '%s' "$bundle" | grep -Eq '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$'; then
  echo "BUNDLE_ID should look like com.example.rustdesk-duo." >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
pbx="$root/flutter/ios/Runner.xcodeproj/project.pbxproj"
# perl -pi works the same on macOS and Linux (BSD and GNU sed differ on -i).
perl -pi -e "s/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = $team;/g" "$pbx"
perl -pi -e "s/PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.-]+;/PRODUCT_BUNDLE_IDENTIFIER = $bundle;/g" "$pbx"

echo "Signing set to team $team, bundle ID $bundle:"
grep -nE 'DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER' "$pbx"
echo "Leave these edits uncommitted if the fork is public and you'd rather not publish them."
