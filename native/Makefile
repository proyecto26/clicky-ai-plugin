# Clicky — CLI-only build + bundle + sign pipeline.
#
# Requirements:
#   - Xcode Command Line Tools installed (`xcode-select --install`)
#   - `swift` (ships with CLT)
#   - `codesign`, `plutil`, `hdiutil` (all ship with macOS)
#
# Targets:
#   make build        → release build + wrap into Clicky.app + adhoc-sign
#   make run          → build + launch the app
#   make clean        → delete build artifacts
#   make bundle       → wrap the most recent release binary into Clicky.app
#   make dmg          → build + create Clicky-<version>-arm64.dmg + sha256 sidecar
#
# Notarization is done by CI (see .github/workflows/release.yml), not by
# this Makefile — developer builds use adhoc signing only.

APP_NAME := Clicky
EXEC     := clicky
VERSION  := 0.1.0
ARCH     := arm64

BUILD_DIR := .build/release
APP_BUNDLE := $(APP_NAME).app
APP_ROOT := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_ROOT)/MacOS
APP_RES   := $(APP_ROOT)/Resources
DMG_NAME := $(APP_NAME)-$(VERSION)-$(ARCH).dmg

.PHONY: build run clean bundle dmg

build: bundle

bundle:
	@echo "==> swift build (release)"
	swift build -c release --arch $(ARCH)
	@echo "==> wrapping $(APP_BUNDLE)"
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_MACOS) $(APP_RES)
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_MACOS)/$(EXEC)
	cp Info.plist $(APP_ROOT)/Info.plist
	cp Resources/Clicky.icns $(APP_RES)/Clicky.icns
	@echo "==> codesign (adhoc)"
	codesign --force --sign - --entitlements Clicky.entitlements --options runtime --timestamp=none $(APP_BUNDLE)
	@echo "==> built $(APP_BUNDLE)"

run: bundle
	@echo "==> launching $(APP_BUNDLE)"
	open $(APP_BUNDLE)

dmg: bundle
	@echo "==> building $(DMG_NAME)"
	rm -f $(DMG_NAME) $(DMG_NAME).sha256
	hdiutil create -volname $(APP_NAME) -srcfolder $(APP_BUNDLE) -ov -format UDZO $(DMG_NAME)
	shasum -a 256 $(DMG_NAME) | awk '{print $$1}' > $(DMG_NAME).sha256
	@echo "==> $(DMG_NAME) + $(DMG_NAME).sha256"

clean:
	rm -rf .build $(APP_BUNDLE) $(DMG_NAME) $(DMG_NAME).sha256
