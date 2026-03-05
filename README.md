# Birdbrain

A macOS app that wraps [Kitty](https://sw.kovidgoyal.net/kitty/) + [Claude Code](https://docs.anthropic.com/en/docs/claude-code) + [Neovim](https://neovim.io/) into a single double-clickable `.app`. Built so non-technical people can use Claude Code without ever opening a terminal.

I work with sales teams and writers who wanted to use Claude Code but kept bouncing off the "open Terminal, install Node, run npm..." onboarding. Birdbrain skips all of that. You open the app, it installs what it needs, and you're talking to Claude. When Claude asks you to edit a file (Ctrl+G), it opens a preconfigured Neovim that's optimized for markdown -- word wrap, spell check, rendered headings, no line numbers cluttering things up.

## Install from a release

1. Download the latest `.zip` from [Releases](https://github.com/birdcar/birdbrain/releases)
2. Extract it
3. Drag `Birdbrain.app` to your Applications folder
4. Right-click the app and choose **Open** (see [Gatekeeper](#gatekeeper) below)

## Build from source

You need `make` and `curl` (both ship with macOS). The Makefile downloads Kitty v0.41.1 automatically.

```bash
git clone https://github.com/birdcar/birdbrain.git
cd birdbrain
make install
```

This builds `Birdbrain.app` and copies it to `/Applications`. To just build without installing, run `make build` -- the app lands in `build/Birdbrain.app`.

To uninstall:

```bash
make uninstall
```

This removes the app from `/Applications`, plus the `~/.birdbrain` state directory and `~/.config/birdbrain` Neovim config.

## First launch

Neovim and its plugins are bundled in the app -- no download needed. The only first-run dependency is **Claude Code**, which is installed automatically via the [official install script](https://claude.ai/install.sh). No Homebrew, no sudo, no password prompts.

Setup takes under a minute. If anything fails, close the app and reopen it -- setup picks up where it left off.

After setup completes, Birdbrain asks you to pick a folder and launches Claude Code there. Every subsequent launch skips setup and goes straight to the folder picker.

## Opening a folder

There are three ways to open a folder in Birdbrain:

1. **Launch from Dock or Applications** -- a native folder picker appears, choose your project folder
2. **Right-click a folder in Finder** -- choose Open With > Birdbrain
3. **From the terminal** -- `open -a Birdbrain ~/path/to/folder`

If you cancel the folder picker, Birdbrain opens in your home directory.

## Keybindings

Birdbrain is intentionally minimal. There are only a few keybindings to know:

| Key | Where | What it does |
|---|---|---|
| Ctrl+G | Claude Code | Opens the current file in Neovim (this is Claude Code's built-in editor shortcut) |
| Cmd+S | Neovim | Save and quit (returns to Claude Code) |
| Esc Esc | Neovim | Save and quit (same as Cmd+S) |
| Cmd+T | Anywhere | Open a new tab with the folder picker |
| Cmd+W | Anywhere | Close the current tab |
| Cmd+Shift+] / Cmd+Shift+[ | Anywhere | Switch between tabs |
| Cmd+O | Anywhere | Open a new window with the folder picker |
| Cmd+Q | Anywhere | Quit Birdbrain |
| Cmd+C / Cmd+V | Anywhere | Copy / Paste |
| Cmd+Plus / Cmd+Minus | Anywhere | Increase / decrease font size |

## How it works

Birdbrain is a standard macOS `.app` bundle. The structure is:

```
Birdbrain.app/Contents/
  MacOS/birdbrain              # Shell script entry point
  Resources/
    kitty/kitty.app/           # Embedded Kitty terminal
    nvim/                      # Embedded Neovim binary
    config/claude/             # Claude Code settings + system prompt
    config/kitty/              # Kitty config + theme files
    config-home/birdbrain/     # Neovim config (LazyVim)
    data-home/birdbrain/lazy/  # Pre-built Neovim plugins
    scripts/
      launcher.sh              # First-run setup, updates, launches Claude
      nvim-wrapper.sh          # Configures env and execs bundled nvim
```

When you launch the app, `birdbrain.sh` starts the embedded Kitty with a custom config and tells it to run `launcher.sh` as its shell. The launcher handles first-run Claude Code setup, deploys user-editable configs to `~/.birdbrain/config/`, starts a background update check, then `exec`s into `claude`.

Neovim, its plugins, and its config are fully vendored in the app bundle -- no downloads, no user-managed config. The Neovim wrapper sets `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to point at the bundle, so everything is self-contained and isolated from any existing Neovim setup.

Claude Code's `EDITOR` environment variable is pointed at this wrapper, so Ctrl+G opens Birdbrain's Neovim rather than whatever editor you use elsewhere.

## Theming

Both Kitty and Neovim use [Catppuccin](https://github.com/catppuccin/catppuccin) -- Mocha for dark mode, Latte for light mode. Kitty switches automatically when you change your macOS appearance (System Settings > Appearance). Neovim picks up the OS appearance on launch through Catppuccin's `flavour = "auto"` setting.

The terminal font is SF Mono at 14pt.

## Updates

Birdbrain runs a background update check once per day. It updates Claude Code via `claude update` and re-downloads the latest stable Neovim release. Update logs are written to `~/.birdbrain/update.log`.

When the app itself is updated (new `.app` version), it automatically re-syncs the bundled Neovim configuration on next launch.

## Troubleshooting

### Gatekeeper

Birdbrain is not signed with an Apple Developer certificate, so macOS will block it the first time you try to open it. This is normal.

To open it:

1. **Right-click** (or Control-click) `Birdbrain.app` in Finder
2. Choose **Open** from the context menu
3. Click **Open** in the dialog that appears

You only need to do this once. After that, the app opens normally.

If right-click > Open doesn't work (some macOS versions are stricter), go to **System Settings > Privacy & Security**, scroll down, and click **Open Anyway** next to the Birdbrain message.

### Setup failed or something is broken

Delete the state directory and reopen the app. This re-triggers first-run setup:

```bash
rm -rf ~/.birdbrain
```

### Claude Code needs updating

Updates happen automatically in the background, but if you need to force it:

```bash
claude update
```

## Requirements

- macOS 13.0 (Ventura) or later
- An internet connection for first-run setup
- A [Claude](https://claude.ai) account with a Claude Code subscription

## License

MIT -- see [LICENSE](LICENSE).

Built by [Nick Cannariato](https://birdcar.dev).
