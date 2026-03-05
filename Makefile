SHELL := /bin/bash
.PHONY: build clean install uninstall download-kitty download-nvim build-nvim-plugins dist

APP_NAME := Birdbrain
BUNDLE := build/$(APP_NAME).app
KITTY_VERSION := 0.41.1
KITTY_DMG := build/kitty-$(KITTY_VERSION).dmg
KITTY_URL := https://github.com/kovidgoyal/kitty/releases/download/v$(KITTY_VERSION)/kitty-$(KITTY_VERSION).dmg
NVIM_TAR := build/nvim-macos-arm64.tar.gz
NVIM_URL := https://github.com/neovim/neovim/releases/download/stable/nvim-macos-arm64.tar.gz
NVIM_DIR := build/nvim
NVIM_PLUGINS := build/nvim-plugins

build: download-kitty download-nvim build-nvim-plugins
	@echo "→ Building $(APP_NAME).app..."
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS"
	@mkdir -p "$(BUNDLE)/Contents/Resources/config/claude"
	@mkdir -p "$(BUNDLE)/Contents/Resources/config/kitty"
	@mkdir -p "$(BUNDLE)/Contents/Resources/config-home/birdbrain"
	@mkdir -p "$(BUNDLE)/Contents/Resources/data-home/birdbrain"
	@mkdir -p "$(BUNDLE)/Contents/Resources/kitty"
	@mkdir -p "$(BUNDLE)/Contents/Resources/scripts"

	# Info.plist
	@cp src/Info.plist "$(BUNDLE)/Contents/"

	# Icon (use placeholder if no .icns exists)
	@if [ -f assets/AppIcon.icns ]; then \
		cp assets/AppIcon.icns "$(BUNDLE)/Contents/Resources/"; \
	fi

	# Main executable
	@cp src/scripts/birdbrain.sh "$(BUNDLE)/Contents/MacOS/birdbrain"
	@chmod +x "$(BUNDLE)/Contents/MacOS/birdbrain"

	# Scripts
	@cp src/scripts/launcher.sh "$(BUNDLE)/Contents/Resources/scripts/"
	@cp src/scripts/nvim-wrapper.sh "$(BUNDLE)/Contents/Resources/scripts/"
	@cp src/scripts/update-app.sh "$(BUNDLE)/Contents/Resources/scripts/"
	@cp src/scripts/folder-picker.py "$(BUNDLE)/Contents/Resources/scripts/"
	@chmod +x "$(BUNDLE)/Contents/Resources/scripts/launcher.sh"
	@chmod +x "$(BUNDLE)/Contents/Resources/scripts/nvim-wrapper.sh"
	@chmod +x "$(BUNDLE)/Contents/Resources/scripts/update-app.sh"

	# Claude Code config (vendored, isolated from ~/.claude/)
	@cp src/config/claude/settings.json "$(BUNDLE)/Contents/Resources/config/claude/"
	@cp src/config/claude/system-prompt.txt "$(BUNDLE)/Contents/Resources/config/claude/"

	# Kitty config + Catppuccin theme files
	@cp src/config/kitty/kitty.conf "$(BUNDLE)/Contents/Resources/config/kitty/"
	@cp src/config/kitty/dark-theme.auto.conf "$(BUNDLE)/Contents/Resources/config/kitty/"
	@cp src/config/kitty/light-theme.auto.conf "$(BUNDLE)/Contents/Resources/config/kitty/"

	# Neovim config (stdpath("config") = config-home/birdbrain)
	@cp -R src/config/nvim/ "$(BUNDLE)/Contents/Resources/config-home/birdbrain/"

	# Embedded Neovim binary
	@cp -R "$(NVIM_DIR)" "$(BUNDLE)/Contents/Resources/nvim"

	# Pre-built Neovim plugins (stdpath("data") = data-home/birdbrain)
	@cp -R "$(NVIM_PLUGINS)/lazy" "$(BUNDLE)/Contents/Resources/data-home/birdbrain/"

	# Extract and embed Kitty
	@echo "→ Extracting Kitty from DMG..."
	@hdiutil attach "$(KITTY_DMG)" -nobrowse -quiet -mountpoint build/kitty-mount
	@cp -R build/kitty-mount/kitty.app "$(BUNDLE)/Contents/Resources/kitty/"
	@hdiutil detach build/kitty-mount -quiet

	@echo "✓ Built $(BUNDLE)"

download-kitty:
	@mkdir -p build
	@if [ ! -f "$(KITTY_DMG)" ]; then \
		echo "→ Downloading Kitty v$(KITTY_VERSION)..."; \
		curl -L -o "$(KITTY_DMG)" "$(KITTY_URL)"; \
		echo "✓ Downloaded Kitty"; \
	fi

download-nvim:
	@mkdir -p build
	@if [ ! -d "$(NVIM_DIR)/bin" ]; then \
		echo "→ Downloading Neovim stable..."; \
		curl -fsSL -o "$(NVIM_TAR)" "$(NVIM_URL)"; \
		mkdir -p "$(NVIM_DIR)"; \
		tar xzf "$(NVIM_TAR)" -C "$(NVIM_DIR)" --strip-components=1; \
		rm -f "$(NVIM_TAR)"; \
		echo "✓ Downloaded Neovim"; \
	fi

build-nvim-plugins: download-nvim
	@if [ ! -d "$(NVIM_PLUGINS)/lazy" ]; then \
		echo "→ Building Neovim plugins..."; \
		mkdir -p "$(CURDIR)/build/config-home/birdbrain"; \
		cp -R "$(CURDIR)/src/config/nvim/" "$(CURDIR)/build/config-home/birdbrain/"; \
		XDG_CONFIG_HOME="$(CURDIR)/build/config-home" \
		XDG_DATA_HOME="$(CURDIR)/build/data-home" \
		XDG_STATE_HOME="$(CURDIR)/build/nvim-state" \
		XDG_CACHE_HOME="$(CURDIR)/build/nvim-cache" \
		NVIM_APPNAME=birdbrain \
		"$(NVIM_DIR)/bin/nvim" --headless "+Lazy! sync" +qa 2>/dev/null || true; \
		mkdir -p "$(NVIM_PLUGINS)"; \
		cp -R "$(CURDIR)/build/data-home/birdbrain/lazy" "$(NVIM_PLUGINS)/"; \
		echo "✓ Built Neovim plugins"; \
	fi

dist: build
	@echo "→ Creating distributable zip..."
	@cd build && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME).app" "$(APP_NAME)-v$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ../src/Info.plist)-macos.zip"
	@echo "✓ Created distributable zip"

install: build
	@echo "→ Installing to /Applications..."
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(BUNDLE)" "/Applications/"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$(APP_NAME).app"
	@echo "✓ Installed $(APP_NAME).app"

uninstall:
	@echo "→ Removing from /Applications..."
	@rm -rf "/Applications/$(APP_NAME).app"
	@rm -rf "$$HOME/.birdbrain"
	@echo "✓ Uninstalled $(APP_NAME)"

clean:
	@rm -rf build
	@echo "✓ Cleaned build directory"
