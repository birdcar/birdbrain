#!/bin/bash
# Neovim wrapper for Birdbrain — uses bundled binary, config, and plugins.
# All read-only from the app bundle, no user customization.

RESOURCES="${BIRDBRAIN_RESOURCES:-$(cd "$(dirname "$0")/../.." && pwd)/Resources}"

# NVIM_APPNAME=birdbrain makes stdpath("config") = $XDG_CONFIG_HOME/birdbrain
# and stdpath("data") = $XDG_DATA_HOME/birdbrain
export NVIM_APPNAME=birdbrain
export XDG_CONFIG_HOME="$RESOURCES/config-home"
export XDG_DATA_HOME="$RESOURCES/data-home"
export XDG_STATE_HOME="$HOME/.birdbrain/nvim-state"
export XDG_CACHE_HOME="$HOME/.birdbrain/nvim-cache"

BIRDBRAIN_NVIM="$RESOURCES/nvim/bin/nvim"
if [ -x "$BIRDBRAIN_NVIM" ]; then
    exec "$BIRDBRAIN_NVIM" "$@"
fi
exec nvim "$@"
