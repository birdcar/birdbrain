# Contract: Birdbrain v1 — Bulletproof Build

## Problem

The initial Birdbrain scaffold works but has gaps: hardcoded Tokyo Night theme, bare Neovim config (no plugin manager, no markdown tooling), fragile setup scripts with no error recovery, and no dark/light mode support. A non-technical user hitting any rough edge (failed brew install, Neovim opening in normal mode with no UI cues, no visual polish) would be stuck.

## Goals

1. **Catppuccin theming throughout** — Kitty uses native dark/light theme files (Mocha dark, Latte light) that auto-switch with macOS appearance. Neovim uses Catppuccin with `flavour = "auto"` to match.
2. **LazyVim-based Neovim config** — Proper plugin manager, markdown extras (render-markdown.nvim, markdown-preview.nvim, Marksman LSP), extensible for future updates. Lives in a custom config dir via `NVIM_APPNAME=birdbrain`.
3. **CTRL+G just works** — `EDITOR` env var points to `nvim` with `NVIM_APPNAME=birdbrain`, so Claude Code's built-in CTRL+G opens our themed, markdown-optimized Neovim.
4. **Bulletproof first-run setup** — Graceful error handling at every step (Homebrew, Neovim, Claude Code install). Clear user-facing messages. Recovery from partial installs. No silent failures.
5. **Self-updating** — Background daily update check for Claude Code and Neovim via `brew upgrade`. Logged but non-blocking.

## Success Criteria

- [ ] `make install` produces a working Birdbrain.app in /Applications
- [ ] First launch installs Homebrew → Neovim → Claude Code with clear progress messages and error recovery
- [ ] Subsequent launches boot directly into Claude Code in <2 seconds
- [ ] Kitty auto-switches between Catppuccin Mocha (dark) and Latte (light) when macOS appearance changes
- [ ] CTRL+G in Claude Code opens Neovim with LazyVim, Catppuccin theme matching Kitty, markdown rendering, and spell check
- [ ] Neovim is usable by non-vim users: mouse works, Ctrl+S saves, Ctrl+Q quits, insert mode for new files
- [ ] Daily background updates run silently and log to `~/.birdbrain/update.log`
- [ ] If any install step fails, user sees a clear error message and can re-launch to retry

## Scope

### In Scope
- Kitty config with Catppuccin Mocha/Latte `.auto.conf` theme files
- LazyVim Neovim config with `NVIM_APPNAME=birdbrain` isolation
- Catppuccin Neovim plugin with auto dark/light switching
- LazyVim markdown extra (render-markdown.nvim, markdown-preview.nvim, Marksman)
- Non-vim-user keybindings (Ctrl+S, Ctrl+Q, mouse, clipboard)
- Robust launcher.sh with error handling, retry logic, partial install recovery
- Updated Makefile to copy the expanded Neovim config structure
- EDITOR env var setup for Claude Code's CTRL+G

### Out of Scope
- App icon (`.icns`) — placeholder for now
- Code signing / notarization — future work
- DMG installer packaging — future work
- Windows/Linux support — macOS only
- Non-markdown Neovim plugins — markdown focus only
- Custom Claude Code configuration — just launch it

## Execution Plan

### Dependency Graph

```
[Single Spec] — no dependencies, all components in one phase
```

### Execution Steps

This is a single-spec project. Execute sequentially in one session:

1. **Implement spec**: Start a new Claude Code session and run:
   ```
   /execute-spec ./docs/ideation/birdbrain-v1/spec.md
   ```
   Or manually implement following the spec's component order (1→6).

2. **Validate**: Run `make clean && make build && make install`, then open Birdbrain.app and walk through the manual testing checklist in the spec.
