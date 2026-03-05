#!/bin/bash
# Birdbrain — main entry point
# This is the executable inside Birdbrain.app/Contents/MacOS/

set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$BUNDLE_DIR/Resources"
KITTY_BIN="$RESOURCES/kitty/kitty.app/Contents/MacOS/kitty"

export BIRDBRAIN_RESOURCES="$RESOURCES"

exec "$KITTY_BIN" \
    --config="$RESOURCES/config/kitty/kitty.conf" \
    --override="shell=$RESOURCES/scripts/launcher.sh" \
    --single-instance \
    --instance-group=birdbrain \
    -T "Birdbrain" \
    -o "macos_custom_beam_cursor=yes"
