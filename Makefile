APP_NAME = Vinyl
BUNDLE_ID = com.aditya.Vinyl
BUILD_DIR = .build/release
APP_DIR = $(APP_NAME).app
MACOS_DIR = $(APP_DIR)/Contents/MacOS
INFO_PLIST = $(APP_DIR)/Contents/Info.plist
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
ifeq ($(strip $(VERSION)),)
VERSION = 1.0
endif
SIGN_IDENTITY ?= -

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
	
	@sed -e 's/__APP_NAME__/$(APP_NAME)/g' \
	     -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' \
	     -e 's/__VERSION__/$(VERSION)/g' \
	     Info.plist.template > $(INFO_PLIST)
	@codesign --force --deep --sign "$(SIGN_IDENTITY)" $(APP_DIR)
	
	@echo "$(APP_NAME).app successfully built."

run:
	swift run

clean:
	swift package clean
	rm -rf $(APP_DIR)
