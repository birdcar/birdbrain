#!/bin/bash
# Birdbrain Self-Updater
# Runs in background, checks GitHub releases, downloads and installs updates
# Usage: update-app.sh <path-to-Info.plist>

set -euo pipefail

INFO_PLIST="${1:-}"
if [ -z "$INFO_PLIST" ] || [ ! -f "$INFO_PLIST" ]; then
    exit 1
fi

STATE_DIR="$HOME/.birdbrain"
APP_UPDATE_LOG="$STATE_DIR/app-update.log"
LAST_CHECK_FILE="$STATE_DIR/.last-app-update-check"
APP_PATH="/Applications/Birdbrain.app"
GITHUB_API="https://api.github.com/repos/birdcar/birdbrain/releases/latest"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$APP_UPDATE_LOG"
}

get_version() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$1" 2>/dev/null || echo "0.0.0"
}

version_gt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ] && [ "$1" != "$2" ]
}

# Throttle: once per day
now=$(date +%s)
if [ -f "$LAST_CHECK_FILE" ]; then
    last=$(cat "$LAST_CHECK_FILE")
    if [ $((now - last)) -lt 86400 ]; then
        exit 0
    fi
fi
echo "$now" > "$LAST_CHECK_FILE"

# Clean up old backup from previous update
rm -rf "${APP_PATH}.bak" "${APP_PATH}.tmp" 2>/dev/null || true

current=$(get_version "$INFO_PLIST")

response=$(curl -s --max-time 10 "$GITHUB_API" 2>/dev/null) || { log "API unreachable"; exit 1; }

tag=$(echo "$response" | grep -o '"tag_name":"[^"]*' | head -1 | cut -d'"' -f4)
[ -z "$tag" ] && { log "No tag found"; exit 1; }

latest="${tag#v}"
log "Current: $current, Latest: $latest"

if ! version_gt "$latest" "$current"; then
    log "Up to date"
    exit 0
fi

dl_url=$(echo "$response" | grep -o '"browser_download_url":"[^"]*\.zip"' | head -1 | cut -d'"' -f4)
[ -z "$dl_url" ] && { log "No download URL"; exit 1; }

log "Downloading $latest..."
tmp=$(mktemp -d)

if ! curl -fsSL --max-time 120 -o "$tmp/update.zip" "$dl_url" 2>/dev/null; then
    log "Download failed"
    rm -rf "$tmp"
    exit 1
fi

if ! ditto -x -k "$tmp/update.zip" "$tmp/extract" 2>/dev/null; then
    log "Extraction failed"
    rm -rf "$tmp"
    exit 1
fi

if [ ! -x "$tmp/extract/Birdbrain.app/Contents/MacOS/birdbrain" ]; then
    log "Invalid app bundle"
    rm -rf "$tmp"
    exit 1
fi

# Atomic replace
if [ -d "$APP_PATH" ]; then
    if ! mv "$APP_PATH" "${APP_PATH}.bak" 2>/dev/null; then
        log "Cannot move current app (permissions?)"
        rm -rf "$tmp"
        exit 1
    fi
fi

if ! mv "$tmp/extract/Birdbrain.app" "$APP_PATH" 2>/dev/null; then
    # Restore backup
    [ -d "${APP_PATH}.bak" ] && mv "${APP_PATH}.bak" "$APP_PATH"
    log "Cannot install new app (permissions?)"
    rm -rf "$tmp"
    exit 1
fi

rm -rf "$tmp" "${APP_PATH}.bak"
log "Updated to $latest — will take effect on next launch"
