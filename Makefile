# FitTracker Makefile
# Primary target: `make tokens` — regenerates DesignTokens.swift from design-tokens/tokens.json
# CI target: `make tokens-check` — fails if DesignTokens.swift is out of sync with tokens.json

.PHONY: tokens tokens-check install verify-local verify-web verify-ai verify-ios

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

# Auto-install on first run
node_modules:
	npm install --silent
