# FitTracker Makefile
# Primary target: `make tokens` — regenerates DesignTokens.swift from design-tokens/tokens.json
# CI target: `make tokens-check` — fails if DesignTokens.swift is out of sync with tokens.json

.PHONY: tokens tokens-check install verify-local verify-web verify-ai verify-ios app-icon app-store-check

# All build artifacts stay on the SSD alongside the project source.
# Override any variable via environment or command line: make verify-ios BUILD_DIR=/other/path
PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR    ?= $(PROJECT_ROOT).build

DEVELOPER_DIR           ?= /Applications/Xcode.app/Contents/Developer
SIMULATOR_ID            ?= 87E96E30-350E-46AC-AB34-B87AF8D1AB1E
AI_VENV                 ?= $(BUILD_DIR)/ai-venv
ASTRO_TELEMETRY_DISABLED ?= 1
SPM_CACHE               ?= $(BUILD_DIR)/spm-cache
BUILD_HOME              ?= $(BUILD_DIR)/xcode-home
CLANG_MODULE_CACHE_PATH ?= $(BUILD_DIR)/clang-cache
DERIVED_DATA            ?= $(BUILD_DIR)/DerivedData
TEST_DERIVED_DATA       ?= $(BUILD_DIR)/TestDerivedData

# Regenerate DesignTokens.swift from tokens.json via Style Dictionary
# Uses node to run sd.config.js directly (not CLI) because custom transforms
# and formats are registered in the config file itself.
tokens: node_modules
	node -e "const sd = require('style-dictionary').extend(require('./sd.config.js')); sd.buildAllPlatforms();"
	@echo "✅  DesignTokens.swift regenerated"

# CI gate: verify committed DesignTokens.swift matches what make tokens would produce
tokens-check: node_modules
	node scripts/check-tokens.js

# Install npm dependencies (style-dictionary)
install:
	npm install

verify-local: tokens-check verify-web verify-ai verify-ios

verify-web:
	cd dashboard && npm test
	cd dashboard && ASTRO_TELEMETRY_DISABLED=$(ASTRO_TELEMETRY_DISABLED) npm run build
	cd website && ASTRO_TELEMETRY_DISABLED=$(ASTRO_TELEMETRY_DISABLED) npm run build

verify-ai:
	cd ai-engine && . $(AI_VENV)/bin/activate && pytest -q

verify-ios:
	mkdir -p $(BUILD_HOME)/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading
	mkdir -p $(CLANG_MODULE_CACHE_PATH)
	HOME=$(BUILD_HOME) CFFIXED_USER_HOME=$(BUILD_HOME) CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild build \
		-project FitTracker.xcodeproj \
		-scheme FitTracker \
		-destination 'generic/platform=iOS' \
		-clonedSourcePackagesDirPath $(SPM_CACHE) \
		-disableAutomaticPackageResolution \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO
	HOME=$(BUILD_HOME) CFFIXED_USER_HOME=$(BUILD_HOME) CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild test \
		-project FitTracker.xcodeproj \
		-scheme FitTracker \
		-destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' \
		-clonedSourcePackagesDirPath $(SPM_CACHE) \
		-disableAutomaticPackageResolution \
		-only-testing:FitTrackerTests/FitTrackerCoreTests \
		-only-testing:FitTrackerTests/SyncMergeTests \
		-derivedDataPath $(TEST_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO

# ── App Store Assets ──────────────────────────────
app-icon:
	@echo "Generating app icon sizes from 1024x1024 master..."
	@mkdir -p FitTracker/Assets.xcassets/AppIcon.appiconset
	@sips -z 180 180 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png 2>/dev/null || echo "  icon-1024.png not found — export from Figma first"
	@sips -z 120 120 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-60@2x.png 2>/dev/null
	@sips -z 87 87 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-29@3x.png 2>/dev/null
	@sips -z 80 80 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-40@2x.png 2>/dev/null
	@sips -z 60 60 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-20@3x.png 2>/dev/null
	@sips -z 58 58 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-29@2x.png 2>/dev/null
	@sips -z 40 40 FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-20@2x.png 2>/dev/null
	@echo "Done. Verify in Xcode Assets catalog."

app-store-check:
	@echo "=== App Store Submission Checklist ==="
	@echo "Icon:"
	@test -f FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png && echo "  ✓ 1024x1024 master exists" || echo "  ✗ 1024x1024 master MISSING"
	@test -f FitTracker/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png && echo "  ✓ 60@3x exists" || echo "  ✗ 60@3x MISSING — run make app-icon"
	@echo "Metadata:"
	@test -f docs/product/app-store-metadata.md && echo "  ✓ Metadata doc exists" || echo "  ✗ Metadata MISSING"
	@echo "Build:"
	@xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tail -1
	@echo "Screenshots: (manual — capture from simulator)"
	@echo "Done."

# Auto-install on first run
node_modules:
	npm install --silent
