.PHONY: project open build dmg install clean

APP_NAME   = YTMBar
BUILD_DIR  = build
DERIVED    = $(BUILD_DIR)/DerivedData
APP_PATH   = $(DERIVED)/Build/Products/Release/$(APP_NAME).app
DMG_PATH   = $(BUILD_DIR)/$(APP_NAME).dmg

project:
	xcodegen generate

open: project
	open $(APP_NAME).xcodeproj

build: project
	xcodebuild \
	  -project $(APP_NAME).xcodeproj \
	  -scheme $(APP_NAME) \
	  -configuration Debug \
	  -derivedDataPath $(DERIVED) \
	  build

# Build Release .app and wrap in a DMG ready for local installation.
# Requires Xcode to be configured with your Apple ID (free account is enough).
dmg: project
	@echo "→ Building Release..."
	xcodebuild \
	  -project $(APP_NAME).xcodeproj \
	  -scheme $(APP_NAME) \
	  -configuration Release \
	  -derivedDataPath $(DERIVED) \
	  build
	@echo "→ Packaging DMG..."
	@mkdir -p $(BUILD_DIR)/dmg_stage
	@cp -R "$(APP_PATH)" $(BUILD_DIR)/dmg_stage/
	@ln -sf /Applications $(BUILD_DIR)/dmg_stage/Applications
	@rm -f $(DMG_PATH)
	hdiutil create \
	  -volname "$(APP_NAME)" \
	  -srcfolder $(BUILD_DIR)/dmg_stage \
	  -ov -format UDZO \
	  $(DMG_PATH)
	@rm -rf $(BUILD_DIR)/dmg_stage
	@echo "✅  Done: $(DMG_PATH)"

# Copy the Release build directly into /Applications (skips DMG).
install: project
	xcodebuild \
	  -project $(APP_NAME).xcodeproj \
	  -scheme $(APP_NAME) \
	  -configuration Release \
	  -derivedDataPath $(DERIVED) \
	  build
	@rm -rf /Applications/$(APP_NAME).app
	@cp -R "$(APP_PATH)" /Applications/
	@echo "✅  Installed to /Applications/$(APP_NAME).app"

clean:
	rm -rf $(APP_NAME).xcodeproj
	rm -rf $(BUILD_DIR)
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(APP_NAME)-*
