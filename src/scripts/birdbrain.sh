#!/bin/bash
# Birdbrain — main entry point
# This is the executable inside Birdbrain.app/Contents/MacOS/

set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$BUNDLE_DIR/Resources"
KITTY_BIN="$RESOURCES/kitty/kitty.app/Contents/MacOS/kitty"
USER_KITTY_CONF="$HOME/.birdbrain/config/kitty/kitty.conf"

export BIRDBRAIN_RESOURCES="$RESOURCES"

# Pass folder path if provided (from Finder "Open With" or open --args)
if [ -n "${1:-}" ] && [ -d "$1" ]; then
    export BIRDBRAIN_OPEN_DIR="$1"
fi

# Use user config if it exists (deployed by launcher.sh on first run),
# otherwise fall back to bundled config
if [ -f "$USER_KITTY_CONF" ]; then
    KITTY_CONF="$USER_KITTY_CONF"
else
    KITTY_CONF="$RESOURCES/config/kitty/kitty.conf"
fi

exec arch -arm64 "$KITTY_BIN" \
    --config="$KITTY_CONF" \
    --override="shell=$RESOURCES/scripts/launcher.sh" \
    --single-instance \
    --instance-group=birdbrain \
    -T "Birdbrain" \
    -o "macos_custom_beam_cursor=yes"
