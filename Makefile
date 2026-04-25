# FitTracker Makefile
# Primary target: `make tokens` — regenerates DesignTokens.swift from design-tokens/tokens.json
# CI target: `make tokens-check` — fails if DesignTokens.swift is out of sync with tokens.json

.PHONY: tokens tokens-check ui-audit ui-audit-baseline ui-audit-drift integrity-check integrity-snapshot schema-check documentation-debt measurement-adoption framework-status advancement-report test-v7-5-pipeline runtime-smoke install-hooks install verify-local verify-web verify-ai verify-ios verify-timing verify-framework verify-evals app-icon app-store-check

# All build artifacts stay on the SSD alongside the project source.
# Override any variable via environment or command line: make verify-ios BUILD_DIR=/other/path
PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR    ?= $(PROJECT_ROOT).build

DEVELOPER_DIR           ?= /Applications/Xcode.app/Contents/Developer
# SIMULATOR_ID is an OPTIONAL override for `make verify-ios` (and other
# simulator-bound targets). When left empty, TEST_DESTINATION below resolves
# to "the newest available iPhone 17 Pro" by name — avoiding the hardcoded-UUID
# drift problem where Xcode refreshes invalidate the UUID. Pass a specific
# UUID with `make verify-ios SIMULATOR_ID=<uuid>` to target a specific device.
SIMULATOR_ID            ?=
ifneq ($(SIMULATOR_ID),)
TEST_DESTINATION        ?= platform=iOS Simulator,id=$(SIMULATOR_ID)
else
TEST_DESTINATION        ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
endif
AI_VENV                 ?= $(BUILD_DIR)/ai-venv
ASTRO_TELEMETRY_DISABLED ?= 1
SPM_CACHE               ?= $(BUILD_DIR)/spm-cache
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

# Design-system compliance scan across every SwiftUI view + component.
# Walks FitTracker/Views and FitTracker/DesignSystem, flags raw colors,
# animations, fonts, magic spacing/frame numbers, and missing
# accessibility annotations on icon-only buttons.
# Exits 1 if any P0 violations exist. Use `make ui-audit-baseline` to
# regenerate docs/design-system/ui-audit-baseline.md without failing.
ui-audit:
	python3 scripts/ui-audit.py

# Regenerate the compliance baseline doc without failing the build.
# Commit the resulting ui-audit-baseline.md alongside any new DS fixes.
ui-audit-baseline:
	python3 scripts/ui-audit.py --baseline --no-fail

# Drift check: fails if the committed ui-audit-baseline.md doesn't match
# what the scanner would regenerate today. Backs up + restores the file so
# the working tree is never left polluted (safe inside verify-local).
# If this fails: run `make ui-audit-baseline` and commit the resulting diff.
ui-audit-drift:
	@_baseline=docs/design-system/ui-audit-baseline.md; \
	 _tmp=$$(mktemp); cp $$_baseline $$_tmp; \
	 python3 scripts/ui-audit.py --baseline --no-fail > /dev/null; \
	 if diff -q $$_tmp $$_baseline > /dev/null 2>&1; then \
	   rm -f $$_tmp; \
	 else \
	   cp $$_tmp $$_baseline; rm -f $$_tmp; \
	   echo "ERROR: ui-audit-baseline.md is stale. Run 'make ui-audit-baseline' and commit."; \
	   exit 1; \
	 fi

# State.json integrity audit — findings-only (no file writes).
# Also runs as a 72h GitHub Actions cycle (.github/workflows/integrity-cycle.yml).
# See .claude/integrity/README.md for the full cycle design.
integrity-check:
	python3 scripts/integrity-check.py --findings-only

# Write a snapshot + diff vs the previous one. Used locally when you want to
# review what a cycle run would record before the next scheduled cycle fires.
integrity-snapshot:
	@mkdir -p .claude/integrity/snapshots
	@ts=$$(date -u +%Y-%m-%dT%H-%M-%SZ); \
	new=".claude/integrity/snapshots/$${ts}.json"; \
	prev=$$(ls -1 .claude/integrity/snapshots/*.json 2>/dev/null | grep -v "$${ts}" | tail -1 || true); \
	if [ -n "$${prev}" ]; then \
		python3 scripts/integrity-check.py --snapshot "$${new}" --compare-to "$${prev}"; \
	else \
		python3 scripts/integrity-check.py --snapshot "$${new}"; \
	fi; \
	echo "Snapshot: $${new}"

# Validate state.json schema across all features (pass if every file uses the
# canonical `current_phase` key instead of the legacy `phase` key).
schema-check:
	python3 scripts/check-state-schema.py

# Generate the baseline documentation-debt report used by the control room.
documentation-debt:
	python3 scripts/documentation-debt-report.py --output .claude/shared/documentation-debt.json

# Gemini audit Tier 1.1 — inventory which features have v6.0 measurement
# fields populated in their state.json. Produces a machine-readable report
# at .claude/shared/measurement-adoption.json and prints a summary.
measurement-adoption:
	python3 scripts/measurement-adoption-report.py

# v7.5/v7.6 Data Integrity Framework — one-command health snapshot.
# Reads all existing ledgers + runs integrity-check, prints a single summary
# of framework version, open tier items, findings, coverage, and logs.
framework-status:
	@bash scripts/framework-status.sh

# v7.5 advancement report — consolidates before/after state + remediation
# commit timeline into a single JSON + markdown artifact. Every number is
# tagged with its T1/T2/T3 data-quality tier.
advancement-report:
	python3 scripts/v7-5-advancement-report.py

# v7.5/v7.6 pipeline regression test — verifies the 8-defense baseline plus
# v7.6 mechanical-enforcement assertions.
# against synthetic bad inputs. Run this locally before any change to the
# integrity-check.py, check-state-schema.py, append-feature-log.py,
# measurement-adoption-report.py, documentation-debt-report.py, or
# runtime-smoke-gate.py scripts.
test-v7-5-pipeline:
	@bash scripts/test-v7-5-pipeline.sh

# Run a local runtime smoke-gate profile built on the shipped XCUITest harness.
# Examples:
#   make runtime-smoke PROFILE=app_launch DRY_RUN=1
#   make runtime-smoke PROFILE=authenticated_home MODE=local
PROFILE ?= app_launch
MODE ?= local
DRY_RUN ?= 1
XCODE_CONFIGURATION ?=
runtime-smoke:
	python3 scripts/runtime-smoke-gate.py --profile "$(PROFILE)" --mode "$(MODE)" $(if $(XCODE_CONFIGURATION),--configuration "$(XCODE_CONFIGURATION)",) $(if $(filter 1,$(DRY_RUN)),--dry-run,)

# Install git hooks into .git/hooks/ by pointing core.hooksPath at .githooks/.
# Idempotent — run after clone to activate the pre-commit schema check.
install-hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks installed (core.hooksPath = .githooks)."
	@echo "Pre-commit will reject state.json files with legacy \`phase\` key."
	@echo "Emergency bypass: git commit --no-verify"

# Install npm dependencies (style-dictionary)
install:
	npm install

# ui-audit is a hard gate as of 2026-04-21 (baseline P0 driven from 27 → 0).
# It runs right after tokens-check because both are fast source-level checks —
# either failing should abort before the heavier verify-ios build cost.
# schema-check is likewise a fast gate (Gemini audit Tier 1.3 — enforces
# canonical `current_phase` on every state.json write).
# Any new P0 (raw Color literal, raw animation, raw font, missing colorset)
# or any SCHEMA_DRIFT introduced by a PR fails the local + CI verify pass.
verify-local: tokens-check schema-check ui-audit ui-audit-drift verify-web verify-ai verify-evals verify-ios verify-timing verify-framework

verify-web:
	cd dashboard && npm test
	cd dashboard && ASTRO_TELEMETRY_DISABLED=$(ASTRO_TELEMETRY_DISABLED) npm run build
	cd website && ASTRO_TELEMETRY_DISABLED=$(ASTRO_TELEMETRY_DISABLED) npm run build

verify-ai:
	cd ai-engine && . $(AI_VENV)/bin/activate && pytest -q

verify-ios:
	mkdir -p $(CLANG_MODULE_CACHE_PATH)
	# Keep SwiftPM/module artifacts on the SSD, but let Xcode use the real
	# user-home CoreSimulator device set. Asset catalogs and preview linking
	# fail when HOME/CFFIXED_USER_HOME are redirected into `.build/xcode-home`.
	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild build \
		-project FitTracker.xcodeproj \
		-scheme FitTracker \
		-destination 'generic/platform=iOS' \
		-clonedSourcePackagesDirPath $(SPM_CACHE) \
		-disableAutomaticPackageResolution \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO
	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild test \
		-project FitTracker.xcodeproj \
		-scheme FitTracker \
		-destination '$(TEST_DESTINATION)' \
		-clonedSourcePackagesDirPath $(SPM_CACHE) \
		-disableAutomaticPackageResolution \
		-only-testing:FitTrackerTests/FitTrackerCoreTests \
		-only-testing:FitTrackerTests/SyncMergeTests \
		-derivedDataPath $(TEST_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO

# ── Framework Measurement v6.0 Verification ──────
# Soft gates: warn but don't block. These become hard gates after validation.

verify-timing:
	@echo "=== Timing Instrumentation Check ==="
	@for dir in .claude/features/*/; do \
		state="$$dir/state.json"; \
		if [ -f "$$state" ]; then \
			phase=$$(python3 -c "import json; print(json.load(open('$$state')).get('current_phase',''))" 2>/dev/null); \
			if [ "$$phase" = "complete" ]; then \
				has_timing=$$(python3 -c "import json; d=json.load(open('$$state')); print('yes' if d.get('timing',{}).get('time_source')=='measured' else 'no')" 2>/dev/null); \
				feature=$$(basename "$$dir"); \
				if [ "$$has_timing" = "no" ]; then \
					echo "  ⚠  $$feature: complete but timing.time_source != measured (estimated)"; \
				else \
					echo "  ✓  $$feature: timing instrumented"; \
				fi; \
			fi; \
		fi; \
	done
	@echo "Done."

verify-framework:
	@echo "=== Framework Integrity Check ==="
	@echo "Cache metrics:"
	@test -f .claude/shared/cache-metrics.json && echo "  ✓ cache-metrics.json exists" || echo "  ⚠ cache-metrics.json MISSING"
	@python3 -c "import json; json.load(open('.claude/shared/cache-metrics.json'))" 2>/dev/null && echo "  ✓ cache-metrics.json valid JSON" || echo "  ⚠ cache-metrics.json invalid JSON"
	@echo "Per-feature cache tracking:"
	@for dir in .claude/features/*/; do \
		state="$$dir/state.json"; \
		cache="$$dir/cache-hits.json"; \
		if [ -f "$$state" ]; then \
			phase=$$(python3 -c "import json; print(json.load(open('$$state')).get('current_phase',''))" 2>/dev/null); \
			feature=$$(basename "$$dir"); \
			if [ "$$phase" = "complete" ]; then \
				if [ -f "$$cache" ]; then \
					echo "  ✓  $$feature: cache-hits.json present"; \
				else \
					echo "  ⚠  $$feature: complete but no cache-hits.json"; \
				fi; \
			fi; \
		fi; \
	done
	@echo "Cache index consistency:"
	@test -f .claude/cache/_index.json && echo "  ✓ _index.json exists" || echo "  ⚠ _index.json MISSING"
	@echo "Token budget:"
	@if [ -f .claude/shared/token-budget.json ]; then \
		age=$$(python3 -c "import json,datetime as dt; t=json.load(open('.claude/shared/token-budget.json'))['measured_at']; d=dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(t.replace('Z','+00:00')); print(d.days)"); \
		if [ "$$age" -gt 7 ]; then \
			echo "  ⚠ token-budget.json is $$age days old — run: bash scripts/count-framework-tokens.sh"; \
		else \
			tokens=$$(python3 -c "import json; print(json.load(open('.claude/shared/token-budget.json'))['total_tokens'])"); \
			echo "  ✓ token-budget.json current ($$tokens tokens)"; \
		fi; \
	else \
		echo "  ⚠ token-budget.json not found — run: bash scripts/count-framework-tokens.sh"; \
	fi
	@echo "Done."

verify-evals:
	@echo "=== AI Eval Suite ==="
	@if [ -d "ai-engine/evals" ]; then \
		cd ai-engine && . $(AI_VENV)/bin/activate && pytest evals/ -v --tb=short; \
	else \
		echo "  ⚠ ai-engine/evals/ directory not found — skipping"; \
	fi

# ── App Store Assets ──────────────────────────────
app-icon:
	@echo "Generating opaque app icon master and Xcode sizes from checked-in FitMe PDF source..."
	@mkdir -p FitTracker/Assets.xcassets/AppIcon.appiconset
	@mkdir -p AppStore
	@test -f FitTracker/Assets.xcassets/Images/FitMeAppIcon.imageset/FitmeIcon.pdf || (echo "  FitmeIcon.pdf missing — restore the source asset first" && exit 1)
	@swift scripts/render_app_icon.swift \
		--input FitTracker/Assets.xcassets/Images/FitMeAppIcon.imageset/FitmeIcon.pdf \
		--output AppStore/AppIcon-1024.png
	@cp AppStore/AppIcon-1024.png FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png
	@for spec in \
		"icon-20@2x.png:40" \
		"icon-20@3x.png:60" \
		"icon-29@2x.png:58" \
		"icon-29@3x.png:87" \
		"icon-40@2x.png:80" \
		"icon-40@3x.png:120" \
		"icon-60@2x.png:120" \
		"icon-60@3x.png:180" \
		"icon-20-ipad@1x.png:20" \
		"icon-20-ipad@2x.png:40" \
		"icon-29-ipad@1x.png:29" \
		"icon-29-ipad@2x.png:58" \
		"icon-40-ipad@1x.png:40" \
		"icon-40-ipad@2x.png:80" \
		"icon-76@1x.png:76" \
		"icon-76@2x.png:152" \
		"icon-83.5@2x.png:167"; do \
		name=$${spec%%:*}; \
		size=$${spec##*:}; \
		sips -z "$$size" "$$size" AppStore/AppIcon-1024.png --out "FitTracker/Assets.xcassets/AppIcon.appiconset/$$name" >/dev/null; \
	done
	@echo "Done. Verify in Xcode Assets catalog."

app-store-check:
	@echo "=== App Store Submission Checklist ==="
	@echo "Icon:"
	@test -f AppStore/AppIcon-1024.png && echo "  ✓ App Store master exists" || echo "  ✗ App Store master MISSING — run make app-icon"
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
