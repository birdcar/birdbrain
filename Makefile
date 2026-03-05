SHELL := /bin/bash
.PHONY: build clean install uninstall download-kitty dist

APP_NAME := Birdbrain
BUNDLE := build/$(APP_NAME).app
KITTY_VERSION := 0.41.1
KITTY_DMG := build/kitty-$(KITTY_VERSION).dmg
KITTY_URL := https://github.com/kovidgoyal/kitty/releases/download/v$(KITTY_VERSION)/kitty-$(KITTY_VERSION).dmg

build: download-kitty
	@echo "→ Building $(APP_NAME).app..."
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS"
	@mkdir -p "$(BUNDLE)/Contents/Resources/config/kitty"
	@mkdir -p "$(BUNDLE)/Contents/Resources/config/nvim"
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
	@chmod +x "$(BUNDLE)/Contents/Resources/scripts/launcher.sh"
	@chmod +x "$(BUNDLE)/Contents/Resources/scripts/nvim-wrapper.sh"
	@chmod +x "$(BUNDLE)/Contents/Resources/scripts/update-app.sh"

	# Kitty config + Catppuccin theme files
	@cp src/config/kitty/kitty.conf "$(BUNDLE)/Contents/Resources/config/kitty/"
	@cp src/config/kitty/dark-theme.auto.conf "$(BUNDLE)/Contents/Resources/config/kitty/"
	@cp src/config/kitty/light-theme.auto.conf "$(BUNDLE)/Contents/Resources/config/kitty/"

	# Neovim config (full LazyVim tree)
	@cp -R src/config/nvim/ "$(BUNDLE)/Contents/Resources/config/nvim/"

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

dist: build
	@echo "→ Creating distributable zip..."
	@cd build && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME).app" "$(APP_NAME)-v$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ../src/Info.plist)-macos.zip"
	@echo "✓ Created distributable zip"

install: build
	@echo "→ Installing to /Applications..."
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(BUNDLE)" "/Applications/"
	@echo "✓ Installed $(APP_NAME).app"

uninstall:
	@echo "→ Removing from /Applications..."
	@rm -rf "/Applications/$(APP_NAME).app"
	@rm -rf "$$HOME/.birdbrain"
	@rm -rf "$$HOME/.config/birdbrain"
	@echo "✓ Uninstalled $(APP_NAME)"

clean:
	@rm -rf build
	@echo "✓ Cleaned build directory"
