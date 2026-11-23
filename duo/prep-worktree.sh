#!/usr/bin/env bash
# Make a linked git worktree of this repo ready to test and build: it gets the submodules and
# copies of the generated bridge files, which are gitignored and so not in a new worktree.
#
#   bash duo/prep-worktree.sh <worktree path>
set -euo pipefail

main="$(cd "$(dirname "$0")/.." && pwd)"
wt="$(cd "${1:?usage: bash duo/prep-worktree.sh <worktree path>}" && pwd)"
[ "$wt" != "$main" ] || { echo "error: give a linked worktree, not the main checkout" >&2; exit 1; }

git -C "$wt" submodule update --init --recursive
for f in flutter/lib/generated_bridge.dart flutter/lib/generated_bridge.freezed.dart \
         src/bridge_generated.rs src/bridge_generated.io.rs; do
  if [ -f "$main/$f" ]; then
    cp "$main/$f" "$wt/$f"
  else
    echo "warning: $main/$f is missing; run bash duo/build-ios.sh in the main checkout first" >&2
  fi
done
echo "ready: $wt"
