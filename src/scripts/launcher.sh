#!/bin/bash
# Birdbrain launcher — runs inside Kitty as the shell
# Handles first-run setup, updates, and launches Claude Code

RESOURCES="${BIRDBRAIN_RESOURCES:-$(cd "$(dirname "$0")/../.." && pwd)/Resources}"
STATE_DIR="$HOME/.birdbrain"
BIN_DIR="$STATE_DIR/bin"
NVIM_CONFIG_DIR="$HOME/.config/birdbrain"
UPDATE_LOG="$STATE_DIR/update.log"
VERSION_FILE="$STATE_DIR/.app-version"

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

# Run a command under native ARM architecture to avoid Rosetta issues
# Kitty's embedded binary may run under x86_64, but Homebrew on Apple
# Silicon is at /opt/homebrew and requires ARM execution
run_native() {
    if [ "$(uname -m)" = "arm64" ] || [ -d /opt/homebrew ]; then
        arch -arm64 "$@"
    else
        "$@"
    fi
}

# ─── Homebrew PATH ───

setup_brew_env() {
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

setup_brew_env

# ─── Editor setup ───

export PATH="$HOME/.claude/local/bin:$BIN_DIR:$PATH"
export EDITOR="$BIN_DIR/nvim-birdbrain"
export VISUAL="$EDITOR"

# ─── Neovim Wrapper ───

install_nvim_wrapper() {
    cp "$RESOURCES/scripts/nvim-wrapper.sh" "$BIN_DIR/nvim-birdbrain"
    chmod +x "$BIN_DIR/nvim-birdbrain"
}

# ─── Neovim Config Deployment ───

deploy_nvim_config() {
    local app_version=""
    local deployed_version=""

    if [ -f "$RESOURCES/../Info.plist" ]; then
        app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$RESOURCES/../Info.plist" 2>/dev/null || echo "unknown")
    fi

    if [ -f "$VERSION_FILE" ]; then
        deployed_version=$(cat "$VERSION_FILE")
    fi

    if [ "$app_version" != "$deployed_version" ] || [ ! -d "$NVIM_CONFIG_DIR/lua" ]; then
        info "Syncing Neovim configuration..."
        mkdir -p "$NVIM_CONFIG_DIR"
        if command -v rsync &>/dev/null; then
            rsync -a --delete "$RESOURCES/config/nvim/" "$NVIM_CONFIG_DIR/"
        else
            rm -rf "$NVIM_CONFIG_DIR"
            cp -R "$RESOURCES/config/nvim" "$NVIM_CONFIG_DIR"
        fi
        echo "$app_version" > "$VERSION_FILE"
        success "Neovim configuration updated."
    fi
}

# ─── First Run Setup ───

needs_setup() {
    ! command -v brew &>/dev/null || \
    ! command -v nvim &>/dev/null || \
    ! command -v claude &>/dev/null || \
    [ ! -f "$BIN_DIR/nvim-birdbrain" ]
}

run_setup() {
    local had_errors=false

    print_banner
    info "Welcome to Birdbrain! Let's get you set up."
    echo ""

    # 1. Homebrew (needed for Neovim)
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew (macOS package manager)..."
        info "You may be asked for your password."
        echo ""
        if run_native /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            setup_brew_env
            if command -v brew &>/dev/null; then
                success "Homebrew installed."
            else
                error "Homebrew installed but not found in PATH."
                error "Try closing and reopening Birdbrain."
                had_errors=true
            fi
        else
            error "Homebrew installation failed."
            error "Check your internet connection and try reopening Birdbrain."
            had_errors=true
        fi
    else
        success "Homebrew found."
    fi

    # 2. Neovim via Homebrew (non-blocking — Claude Code works without it)
    if command -v brew &>/dev/null && ! command -v nvim &>/dev/null; then
        info "Installing Neovim (text editor for Ctrl+G)..."
        if run_native brew install neovim; then
            success "Neovim installed."
        else
            warn "Neovim installation failed — Ctrl+G editing won't work."
            warn "You can install it later: brew install neovim"
        fi
    elif command -v nvim &>/dev/null; then
        success "Neovim found."
    fi

    # 3. Claude Code via official install script (blocking)
    if ! command -v claude &>/dev/null; then
        info "Installing Claude Code..."
        if run_native bash -c "$(curl -fsSL https://claude.ai/install.sh)"; then
            # The installer puts claude in ~/.claude/local/bin
            export PATH="$HOME/.claude/local/bin:$PATH"
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

    # 4. Neovim wrapper
    install_nvim_wrapper

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

# Always sync config and wrapper (handles app updates)
deploy_nvim_config
install_nvim_wrapper

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
        # Update Claude Code via its own updater if available
        if command -v claude &>/dev/null; then
            claude update 2>&1 || true
        fi
        # Update Neovim via Homebrew
        setup_brew_env
        if command -v brew &>/dev/null; then
            run_native brew upgrade neovim 2>&1 || true
        fi
        echo "$now" > "$last_update_file"
        echo "--- Update complete ---"
    } >> "$UPDATE_LOG" 2>&1 &
}

run_update_check

# ─── Choose Working Directory ───

choose_directory() {
    # 1. If a folder was passed (Finder "Open With" or open --args), use it
    if [ -n "${BIRDBRAIN_OPEN_DIR:-}" ] && [ -d "$BIRDBRAIN_OPEN_DIR" ]; then
        echo "$BIRDBRAIN_OPEN_DIR"
        return
    fi

    # 2. Otherwise, show a native macOS folder picker
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

    # 3. Fallback to home directory if picker was cancelled
    echo "$HOME"
}

WORK_DIR=$(choose_directory)

# ─── Launch Claude Code ───

if command -v claude &>/dev/null; then
    cd "$WORK_DIR"
    exec claude
else
    echo ""
    error "Claude Code is not installed."
    error "Please check your internet connection and reopen Birdbrain."
    echo ""
    wait_for_key
    exit 1
fi
