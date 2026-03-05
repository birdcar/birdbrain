#!/bin/bash
export NVIM_APPNAME=birdbrain
BIRDBRAIN_NVIM="$HOME/.birdbrain/nvim/bin/nvim"
if [ -x "$BIRDBRAIN_NVIM" ]; then
    exec "$BIRDBRAIN_NVIM" "$@"
fi
exec nvim "$@"
