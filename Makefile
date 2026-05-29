APP_NAME = Vinyl
BUNDLE_ID = com.aditya.Vinyl
BUILD_DIR = .build/release
APP_DIR = $(APP_NAME).app
MACOS_DIR = $(APP_DIR)/Contents/MacOS
INFO_PLIST = $(APP_DIR)/Contents/Info.plist

.PHONY: all build app clean run

all: app

build:
	swift build -c release

app: build
	@echo "Bundling $(APP_NAME).app..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(APP_DIR)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/
	@if [ -d $(BUILD_DIR)/Vinyl_Vinyl.bundle ]; then cp -R $(BUILD_DIR)/Vinyl_Vinyl.bundle $(APP_DIR)/Contents/Resources/; fi
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns $(APP_DIR)/Contents/Resources/; fi
	
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(INFO_PLIST)
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(INFO_PLIST)
	@echo '<plist version="1.0">' >> $(INFO_PLIST)
	@echo '<dict>' >> $(INFO_PLIST)
	@echo '    <key>CFBundleIconFile</key>' >> $(INFO_PLIST)
	@echo '    <string>AppIcon</string>' >> $(INFO_PLIST)
	@echo '    <key>CFBundleExecutable</key>' >> $(INFO_PLIST)
	@echo '    <string>$(APP_NAME)</string>' >> $(INFO_PLIST)
	@echo '    <key>CFBundleIdentifier</key>' >> $(INFO_PLIST)
	@echo '    <string>$(BUNDLE_ID)</string>' >> $(INFO_PLIST)
	@echo '    <key>CFBundleName</key>' >> $(INFO_PLIST)
	@echo '    <string>$(APP_NAME)</string>' >> $(INFO_PLIST)
	@echo '    <key>CFBundlePackageType</key>' >> $(INFO_PLIST)
	@echo '    <string>APPL</string>' >> $(INFO_PLIST)
	@echo '    <key>CFBundleShortVersionString</key>' >> $(INFO_PLIST)
	@echo '    <string>1.0</string>' >> $(INFO_PLIST)
	@echo '    <key>LSUIElement</key>' >> $(INFO_PLIST)
	@echo '    <true/>' >> $(INFO_PLIST)
	@echo '    <key>NSAppleEventsUsageDescription</key>' >> $(INFO_PLIST)
	@echo '    <string>$(APP_NAME) requires AppleScript to read currently playing track details from Apple Music and Spotify.</string>' >> $(INFO_PLIST)
	@echo '</dict>' >> $(INFO_PLIST)
	@echo '</plist>' >> $(INFO_PLIST)
	
	@echo "$(APP_NAME).app successfully built."

run:
	swift run

clean:
	swift package clean
	rm -rf $(APP_DIR)
