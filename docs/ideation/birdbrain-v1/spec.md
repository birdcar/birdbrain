# Implementation Spec: Birdbrain v1

**Contract**: ./contract.md
**Estimated Effort**: M

## Technical Approach

Replace the current bare Neovim config with a full LazyVim setup isolated via `NVIM_APPNAME=birdbrain`. The config ships as lua source files inside the app bundle at `Resources/config/nvim/`. On first Neovim launch, lazy.nvim bootstraps itself and installs all plugins (Catppuccin, render-markdown.nvim, markdown-preview.nvim, Marksman LSP). The `EDITOR` env var is set to `NVIM_APPNAME=birdbrain nvim` so Claude Code's CTRL+G opens our config.

Replace hardcoded Tokyo Night colors in `kitty.conf` with Catppuccin using Kitty's native `.auto.conf` theme file system. Ship `dark-theme.auto.conf` (Mocha) and `light-theme.auto.conf` (Latte) alongside `kitty.conf`. Kitty's automatic OS appearance detection switches between them when macOS toggles dark/light mode — no restart needed.

Harden the launcher script with proper error handling: trap failures, allow retry on re-launch, detect partial installs, and provide clear user-facing messages at every step. The setup flow becomes idempotent — each dependency check is independent, so a failed Neovim install doesn't block Claude Code if it's already installed.

## Feedback Strategy

**Inner-loop command**: `cd ~/Code/birdcar/birdbrain && make build`

**Playground**: Build the app bundle locally, open it, verify Kitty launches with correct theme, test CTRL+G in Claude Code opens Neovim with LazyVim.

**Why this approach**: All changes are config files and shell scripts — the build validates file copying, and manual launch validates runtime behavior.

## File Changes

### New Files

| File Path | Purpose |
| --- | --- |
| `src/config/kitty/dark-theme.auto.conf` | Catppuccin Mocha colors for Kitty dark mode |
| `src/config/kitty/light-theme.auto.conf` | Catppuccin Latte colors for Kitty light mode |
| `src/config/nvim/init.lua` | LazyVim entry point (`require("config.lazy")`) |
| `src/config/nvim/lua/config/lazy.lua` | lazy.nvim bootstrap + LazyVim import |
| `src/config/nvim/lua/config/options.lua` | Neovim options for non-technical users |
| `src/config/nvim/lua/config/keymaps.lua` | Simple keybindings (Ctrl+S, Ctrl+Q, etc.) |
| `src/config/nvim/lua/config/autocmds.lua` | Insert mode for new files, markdown settings |
| `src/config/nvim/lua/plugins/catppuccin.lua` | Catppuccin theme with auto dark/light |
| `src/config/nvim/lua/plugins/markdown.lua` | Enable LazyVim markdown extra + overrides |
| `src/config/nvim/lua/plugins/ui.lua` | Disable noisy LazyVim UI (dashboard, bufferline) |
| `src/scripts/nvim-wrapper.sh` | Wrapper script that sets NVIM_APPNAME and XDG paths |

### Modified Files

| File Path | Changes |
| --- | --- |
| `src/config/kitty.conf` | Remove all color definitions, add `include` for auto theme files, update `macos_titlebar_color` |
| `src/scripts/launcher.sh` | Error handling with traps, idempotent setup, EDITOR pointing to nvim-wrapper, Neovim config deployment to `~/.config/birdbrain/` |
| `src/scripts/birdbrain.sh` | Pass Kitty config dir (not single file) so includes resolve correctly |
| `Makefile` | Copy expanded nvim config tree, kitty theme files, nvim-wrapper script |

### Deleted Files

| File Path | Reason |
| --- | --- |
| *(none)* | Existing files are modified, not deleted |

## Implementation Details

### 1. Kitty Catppuccin Theming

**Overview**: Replace inline Tokyo Night colors with Catppuccin Mocha/Latte using Kitty's native `.auto.conf` system for automatic macOS dark/light switching.

**Key decisions**:
- Use `.auto.conf` file naming — Kitty's built-in mechanism watches these files and switches based on OS appearance
- Keep non-color config in `kitty.conf`, theme colors in separate files
- Kitty config dir in the bundle needs all three files colocated for `include` to resolve

**Implementation steps**:

1. Create `src/config/kitty/` directory, move `kitty.conf` into it
2. Create `dark-theme.auto.conf` with full Catppuccin Mocha palette (all 16 ANSI colors + UI elements)
3. Create `light-theme.auto.conf` with full Catppuccin Latte palette
4. Strip all `color*`, `background`, `foreground`, `cursor`, `selection_*` lines from `kitty.conf`
5. Update `kitty.conf` to set `macos_titlebar_color background` (works dynamically with theme switching)
6. Update `birdbrain.sh` to pass `--config` pointing to the kitty dir's `kitty.conf` — Kitty resolves `.auto.conf` files relative to the config file's directory

`dark-theme.auto.conf` (Catppuccin Mocha):
```conf
foreground              #cdd6f4
background              #1e1e2e
selection_foreground    #1e1e2e
selection_background    #f5e0dc
cursor                  #f5e0dc
cursor_text_color       #1e1e2e
url_color               #f5e0dc
active_border_color     #b4befe
inactive_border_color   #6c7086
bell_border_color       #f9e2af
active_tab_foreground   #11111b
active_tab_background   #cba6f7
inactive_tab_foreground #cdd6f4
inactive_tab_background #181825
tab_bar_background      #11111b

color0  #45475a
color1  #f38ba8
color2  #a6e3a1
color3  #f9e2af
color4  #89b4fa
color5  #f5c2e7
color6  #94e2d5
color7  #bac2de
color8  #585b70
color9  #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #f5c2e7
color14 #94e2d5
color15 #a6adc8
```

`light-theme.auto.conf` (Catppuccin Latte):
```conf
foreground              #4c4f69
background              #eff1f5
selection_foreground    #eff1f5
selection_background    #dc8a78
cursor                  #dc8a78
cursor_text_color       #eff1f5
url_color               #dc8a78
active_border_color     #7287fd
inactive_border_color   #9ca0b0
bell_border_color       #df8e1d
active_tab_foreground   #eff1f5
active_tab_background   #8839ef
inactive_tab_foreground #4c4f69
inactive_tab_background #9ca0b0
tab_bar_background      #bcc0cc

color0  #5c5f77
color1  #d20f39
color2  #40a02b
color3  #df8e1d
color4  #1e66f5
color5  #ea76cb
color6  #179299
color7  #acb0be
color8  #6c6f85
color9  #d20f39
color10 #40a02b
color11 #df8e1d
color12 #1e66f5
color13 #ea76cb
color14 #179299
color15 #bcc0cc
```

### 2. LazyVim Neovim Configuration

**Overview**: Full LazyVim setup with markdown focus, Catppuccin theming, and non-technical-user-friendly defaults. Deployed to `~/.config/birdbrain/` via `NVIM_APPNAME=birdbrain`.

**Key decisions**:
- Use `NVIM_APPNAME=birdbrain` to isolate from any existing user Neovim config
- Ship lua source files in the app bundle; launcher copies them to `~/.config/birdbrain/` on first run (and updates on app version change)
- LazyVim bootstraps plugins on first Neovim open — requires internet but is standard behavior
- Disable noisy LazyVim defaults: dashboard (Alpha), bufferline, notify toasts — keep it clean and focused
- Enable LazyVim markdown extra via `lazyvim.plugins.extras.lang.markdown` import

**File structure** (under `src/config/nvim/`):
```
init.lua
lua/
  config/
    lazy.lua
    options.lua
    keymaps.lua
    autocmds.lua
  plugins/
    catppuccin.lua
    markdown.lua
    ui.lua
```

**`init.lua`**:
```lua
require("config.lazy")
```

**`lua/config/lazy.lua`** — bootstrap lazy.nvim + load LazyVim:
```lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    lazyrepo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
```

**`lua/config/options.lua`** — non-technical user defaults:
```lua
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.scrolloff = 8
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.conceallevel = 2
vim.opt.spell = true
vim.opt.spelllang = { "en_us" }
```

**`lua/config/keymaps.lua`** — simple keybindings:
```lua
-- Save with Ctrl+S
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<Cmd>w<CR>", { desc = "Save" })

-- Save and quit with Ctrl+Q (back to Claude Code)
vim.keymap.set({ "n", "i", "v" }, "<C-q>", "<Cmd>wq<CR>", { desc = "Save and quit" })

-- Double-Escape saves and quits (fast exit back to Claude)
vim.keymap.set("n", "<Esc><Esc>", "<Cmd>wq<CR>", { desc = "Save and quit" })
```

**`lua/config/autocmds.lua`**:
```lua
-- Start in insert mode for new files
vim.api.nvim_create_autocmd("BufNewFile", {
  callback = function()
    vim.cmd("startinsert")
  end,
})
```

**`lua/plugins/catppuccin.lua`**:
```lua
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "auto",
      background = { light = "latte", dark = "mocha" },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
```

**`lua/plugins/markdown.lua`** — markdown extra overrides:
```lua
return {
  -- render-markdown.nvim is included via the LazyVim markdown extra
  -- Override defaults for cleaner non-technical-user experience
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      heading = {
        enabled = true,
        sign = false,
      },
      code = {
        sign = false,
      },
    },
  },
}
```

**`lua/plugins/ui.lua`** — disable noisy defaults:
```lua
return {
  -- Disable dashboard — Birdbrain opens directly to files via Claude
  { "nvimdev/dashboard-nvim", enabled = false },
  -- Disable bufferline — single-file editing, no tabs needed
  { "akinsho/bufferline.nvim", enabled = false },
  -- Disable indent guides — cleaner for markdown
  { "lukas-reineke/indent-blankline.nvim", enabled = false },
  -- Disable mini.indentscope
  { "echasnern/mini.indentscope", enabled = false },
  -- Disable noice.nvim command line popups — keep it simple
  { "folke/noice.nvim", enabled = false },
}
```

### 3. Neovim Wrapper Script

**Overview**: A shell script that sets `NVIM_APPNAME` and launches Neovim. This is what `EDITOR` points to.

**`src/scripts/nvim-wrapper.sh`**:
```bash
#!/bin/bash
export NVIM_APPNAME=birdbrain
exec nvim "$@"
```

**Key decisions**:
- Separate wrapper script rather than inline `EDITOR` value — avoids quoting issues with `EDITOR="NVIM_APPNAME=birdbrain nvim"` which breaks in some contexts
- The wrapper is installed to `~/.birdbrain/bin/nvim-birdbrain` by the launcher

### 4. Launcher Script Hardening

**Overview**: Rewrite `launcher.sh` with proper error handling, idempotent setup, and the Neovim config deployment step.

**Key decisions**:
- Each install step is independent — a failed Neovim install doesn't prevent Claude Code from working
- Partial install state is tracked per-dependency, not with a single marker
- Config sync: compare app bundle version with deployed version, update if different
- `set -euo pipefail` with explicit `|| handle_error` rather than relying on global trap for user-facing messages

**Implementation steps**:

1. Replace single `FIRST_RUN_MARKER` with per-dependency markers: `.brew-ok`, `.nvim-ok`, `.claude-ok`
2. Add `deploy_nvim_config()` function that syncs `Resources/config/nvim/` to `~/.config/birdbrain/`
3. Add `install_nvim_wrapper()` that copies wrapper script to `~/.birdbrain/bin/` and makes it executable
4. Set `EDITOR="$HOME/.birdbrain/bin/nvim-birdbrain"` and `VISUAL="$EDITOR"`
5. Add `PATH="$HOME/.birdbrain/bin:$PATH"` so the wrapper is findable
6. Each install step: try, on failure show error message with retry instructions, continue to next step
7. Only `exec claude` if claude is installed; otherwise show error and wait for keypress

**Error handling table**:

| Error Scenario | Handling Strategy |
| --- | --- |
| No internet during Homebrew install | Show message: "Birdbrain needs internet for first-time setup. Please connect and relaunch." |
| `brew install neovim` fails | Mark as failed, log error, continue — Claude Code still works, just no CTRL+G editor |
| `brew install claude` fails | Show clear error with manual install instructions, wait for keypress |
| Neovim config sync fails (disk full, permissions) | Log warning, continue with stale config if one exists |
| Claude Code auth fails | Let Claude handle it — its own auth UX is fine |
| Background update fails | Already handled — logged to update.log, non-blocking |

### 5. Makefile Updates

**Overview**: Update the build to handle the expanded directory structure.

**Implementation steps**:

1. Change Kitty config from single file copy to directory copy (`src/config/kitty/` → `Resources/config/kitty/`)
2. Copy full Neovim config tree (`src/config/nvim/` → `Resources/config/nvim/`) preserving directory structure
3. Copy `nvim-wrapper.sh` to `Resources/scripts/`
4. Update `birdbrain.sh` `--config` path to point to `Resources/config/kitty/kitty.conf`

### 6. birdbrain.sh Updates

**Overview**: Update the main entry point to pass the Kitty config directory correctly.

**Key change**: `--config="$RESOURCES/config/kitty/kitty.conf"` (was `$RESOURCES/config/kitty.conf`). This ensures Kitty's `include` directives resolve the `.auto.conf` files relative to the config file's directory.

## Testing Requirements

### Manual Testing

- [ ] `make build` completes without errors
- [ ] `make install` copies app to /Applications
- [ ] First launch: Homebrew install prompt appears (test on clean system or by removing markers)
- [ ] First launch: Neovim and Claude Code install via brew
- [ ] Subsequent launch: boots to Claude Code in <2s
- [ ] macOS dark mode → Kitty shows Catppuccin Mocha colors
- [ ] macOS light mode → Kitty shows Catppuccin Latte colors
- [ ] macOS appearance toggle → Kitty switches live without restart
- [ ] CTRL+G in Claude Code → Neovim opens with Catppuccin theme matching Kitty
- [ ] Neovim: mouse scrolling and clicking works
- [ ] Neovim: Ctrl+S saves file
- [ ] Neovim: Ctrl+Q saves and quits back to Claude
- [ ] Neovim: markdown headings render with render-markdown.nvim
- [ ] Neovim: spell checking active on markdown files
- [ ] New file in Neovim starts in insert mode
- [ ] Kill brew mid-install → relaunch → setup resumes from where it left off
- [ ] No internet on first launch → clear error message
- [ ] Background update log written to `~/.birdbrain/update.log`

## Validation Commands

```bash
# Build the app bundle
make clean && make build

# Verify bundle structure
ls -la build/Birdbrain.app/Contents/Resources/config/kitty/
ls -la build/Birdbrain.app/Contents/Resources/config/nvim/lua/plugins/
ls -la build/Birdbrain.app/Contents/Resources/scripts/

# Verify theme files have correct Catppuccin colors
grep -c "^color" build/Birdbrain.app/Contents/Resources/config/kitty/dark-theme.auto.conf
# Expected: 16

grep -c "^color" build/Birdbrain.app/Contents/Resources/config/kitty/light-theme.auto.conf
# Expected: 16

# Install and launch
make install
open /Applications/Birdbrain.app
```

## Open Items

- [ ] App icon (`.icns`) — needs design work, placeholder for now
- [ ] Code signing for distribution — requires Apple Developer account
- [ ] Consider `no-preference-theme.auto.conf` — currently defaults to dark if OS has no preference

---

_This spec is ready for implementation. Follow the patterns and validate at each step._
