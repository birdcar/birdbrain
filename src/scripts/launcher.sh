#!/bin/bash
# Birdbrain launcher — runs inside Kitty as the shell
# Handles first-run Claude Code setup, user config deployment,
# background updates, and launches Claude Code.

RESOURCES="${BIRDBRAIN_RESOURCES:-$(cd "$(dirname "$0")/../.." && pwd)/Resources}"
STATE_DIR="$HOME/.birdbrain"
BIN_DIR="$STATE_DIR/bin"
USER_CONFIG_DIR="$STATE_DIR/config"
UPDATE_LOG="$STATE_DIR/update.log"

mkdir -p "$STATE_DIR" "$BIN_DIR"

# ─── Helpers ───

print_banner() {
    printf '\033[1;35m'
    cat << 'BANNER'

    ____  _         _ _               _
   | __ )(_)_ __ __| | |__  _ __ __ _(_)_ __
   |  _ \| | '__/ _` | '_ \| '__/ _` | | '_ \
   | |_) | | | | (_| | |_) | | | (_| | | | | |
   |____/|_|_|  \__,_|_.__/|_|  \__,_|_|_| |_|

BANNER
    printf '\033[0m\n'
}

info() {
    printf '\033[1;34m→\033[0m %s\n' "$1"
}

success() {
    printf '\033[1;32m✓\033[0m %s\n' "$1"
}

warn() {
    printf '\033[1;33m!\033[0m %s\n' "$1"
}

error() {
    printf '\033[1;31m✗\033[0m %s\n' "$1"
}

wait_for_key() {
    printf '\n  Press any key to continue...'
    read -rsn1
    printf '\n'
}

# ─── PATH setup ───

export PATH="$BIN_DIR:$HOME/.local/bin:$HOME/.claude/local/bin:$PATH"
export EDITOR="$BIN_DIR/nvim-birdbrain"
export VISUAL="$EDITOR"

# ─── Neovim Wrapper ───

install_nvim_wrapper() {
    cp "$RESOURCES/scripts/nvim-wrapper.sh" "$BIN_DIR/nvim-birdbrain"
    chmod +x "$BIN_DIR/nvim-birdbrain"
}

# ─── User Config Deployment ───
# Deploy bundled configs to ~/.birdbrain/config/ on first run only.
# Users can edit these files to customize Claude and Kitty. App updates
# will NOT overwrite user modifications.

deploy_user_configs() {
    # Claude Code config
    if [ ! -f "$USER_CONFIG_DIR/claude/settings.json" ]; then
        mkdir -p "$USER_CONFIG_DIR/claude"
        cp "$RESOURCES/config/claude/settings.json" "$USER_CONFIG_DIR/claude/"
        cp "$RESOURCES/config/claude/system-prompt.txt" "$USER_CONFIG_DIR/claude/"
    fi

    # Kitty config
    if [ ! -f "$USER_CONFIG_DIR/kitty/kitty.conf" ]; then
        mkdir -p "$USER_CONFIG_DIR/kitty"
        cp "$RESOURCES/config/kitty/kitty.conf" "$USER_CONFIG_DIR/kitty/"
        cp "$RESOURCES/config/kitty/dark-theme.auto.conf" "$USER_CONFIG_DIR/kitty/"
        cp "$RESOURCES/config/kitty/light-theme.auto.conf" "$USER_CONFIG_DIR/kitty/"
    fi
}

# ─── First Run Setup ───

needs_setup() {
    ! command -v claude &>/dev/null || \
    [ ! -f "$BIN_DIR/nvim-birdbrain" ]
}

run_setup() {
    local had_errors=false

    print_banner
    info "Welcome to Birdbrain! Let's get you set up."
    echo ""

    # Claude Code via official install script (blocking)
    if ! command -v claude &>/dev/null; then
        info "Installing Claude Code..."
        if bash -c "$(curl -fsSL https://claude.ai/install.sh)"; then
            export PATH="$HOME/.local/bin:$HOME/.claude/local/bin:$PATH"
            if command -v claude &>/dev/null; then
                success "Claude Code installed."
            else
                error "Claude Code installed but not found in PATH."
                error "Try closing and reopening Birdbrain."
                had_errors=true
            fi
        else
            error "Claude Code installation failed."
            error "Check your internet connection and try reopening Birdbrain."
            error ""
            error "To install manually, run in a terminal:"
            error "  curl -fsSL https://claude.ai/install.sh | bash"
            had_errors=true
        fi
    else
        success "Claude Code found."
    fi

    # Neovim wrapper + user configs
    install_nvim_wrapper
    deploy_user_configs

    echo ""
    if [ "$had_errors" = true ]; then
        error "Setup completed with errors. See messages above."
        wait_for_key
    else
        success "Setup complete!"
        echo ""
        sleep 1
    fi
}

if needs_setup; then
    run_setup
fi

# Always ensure wrapper and configs are current
install_nvim_wrapper
deploy_user_configs

# ─── Background Update Check ───

run_update_check() {
    local last_update_file="$STATE_DIR/.last-update-check"
    local now
    now=$(date +%s)

    if [ -f "$last_update_file" ]; then
        local last_check
        last_check=$(cat "$last_update_file")
        local elapsed=$((now - last_check))
        if [ "$elapsed" -lt 86400 ]; then
            return 0
        fi
    fi

    {
        echo "--- Update check: $(date) ---"
        if command -v claude &>/dev/null; then
            claude update 2>&1 || true
        fi
        echo "$now" > "$last_update_file"
        echo "--- Update complete ---"
    } >> "$UPDATE_LOG" 2>&1 &
}

run_update_check

# ─── App Self-Update ───

"$RESOURCES/scripts/update-app.sh" "$RESOURCES/../Info.plist" > /dev/null 2>&1 &

# ─── Choose Working Directory ───

choose_directory() {
    if [ -n "${BIRDBRAIN_OPEN_DIR:-}" ] && [ -d "$BIRDBRAIN_OPEN_DIR" ]; then
        echo "$BIRDBRAIN_OPEN_DIR"
        return
    fi

    local picked
    picked=$(osascript -e 'try
        set chosenFolder to POSIX path of (choose folder with prompt "Choose a folder to open in Birdbrain:")
        return chosenFolder
    on error
        return ""
    end try' 2>/dev/null) || true

    if [ -n "$picked" ] && [ -d "$picked" ]; then
        echo "$picked"
        return
    fi

    echo "$HOME"
}

WORK_DIR=$(choose_directory)

# ─── Launch Claude Code ───

if command -v claude &>/dev/null; then
    cd "$WORK_DIR"
    CLAUDE_ARGS=(
        --settings "$USER_CONFIG_DIR/claude/settings.json"
        --setting-sources "project,local"
        --append-system-prompt "$(cat "$USER_CONFIG_DIR/claude/system-prompt.txt")"
    )
    exec claude "${CLAUDE_ARGS[@]}"
else
    echo ""
    error "Claude Code is not installed."
    error "Please check your internet connection and reopen Birdbrain."
    echo ""
    wait_for_key
    exit 1
fi
