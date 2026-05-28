# FitTracker Makefile
# Primary target: `make tokens` — regenerates DesignTokens.swift from design-tokens/tokens.json
# CI target: `make tokens-check` — fails if DesignTokens.swift is out of sync with tokens.json

.PHONY: tokens tokens-check ui-audit ui-audit-baseline ui-audit-drift integrity-check integrity-diff integrity-snapshot preflight schema-check documentation-debt measurement-adoption framework-status advancement-report test-v7-5-pipeline runtime-smoke install-hooks pre-commit-self-test membrane-status v7-9-snapshot install verify-local verify-web verify-ai verify-ios verify-timing verify-framework verify-evals app-icon app-store-check validate-tier-tags figma-drift snapshot-phase refresh-pr-cache validate-existing-cites daily-checkpoint daily-checkpoint-force ledger install-daily-cron uninstall-daily-cron install-devssd-watcher uninstall-devssd-watcher verify-local-idempotent-check audit-cache audit-imports doctor integrity-snapshot-rotate logs-rotate sessions-compact

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
# v7.8.4: auto-refresh stale PR cache (>24h or empty) before scanning so
# BROKEN_PR_CITATION + PR_NUMBER_UNRESOLVED don't produce false positives.
# Refresh failure logs to stderr but does not abort the run.
integrity-check:
	@python3 scripts/ensure-pr-cache-fresh.py --quiet || true
	python3 scripts/integrity-check.py --findings-only
	@python3 scripts/skills-audit.py --advisory --quiet || true
	@python3 scripts/preflight-fixture-test.py 2>/dev/null || true

# Compare current platform state vs the 2026-05-14 pre-v7.9 baseline anchor.
# Closes the 96h drift window between weekly cron (Mon 05:00 UTC) and 72h
# cycle, per docs/master-plan/data-integrity-and-rollback-2026-05-14.md §2.1+§2.3.
# Override anchor: INTEGRITY_DIFF_BASELINE=<path> make integrity-diff
# CI mode: exits 1 on regression — `make integrity-diff EXIT_ON_REGRESSION=1`.
integrity-diff:
	@python3 scripts/integrity-diff.py $(if $(EXIT_ON_REGRESSION),--exit-on-regression,)

# Rotate / prune daily-checkpoint snapshots under
# ~/Documents/FitTracker2-backups/daily/ (R2 from 2026-05-19 dev-env audit).
# Dry-run by default — re-run with EXECUTE=1 to apply changes.
# Retention: last 30 days uncompressed + first-of-month anchors permanent
# (optionally compressed via COMPRESS_ANCHORS=1).
#   make checkpoint-rotate                              # dry-run, default 30d retention
#   make checkpoint-rotate EXECUTE=1                    # actually rotate
#   make checkpoint-rotate KEEP_DAYS=60 EXECUTE=1       # custom retention
#   make checkpoint-rotate EXECUTE=1 COMPRESS_ANCHORS=1 # also compress older anchors to .tar.zst
checkpoint-rotate:
	@python3 scripts/rotate-checkpoint-snapshots.py \
		$(if $(KEEP_DAYS),--keep-days=$(KEEP_DAYS),) \
		$(if $(EXECUTE),--execute,) \
		$(if $(COMPRESS_ANCHORS),--compress-anchors,)

# Unified preflight entry point — aggregates all pre-work data checks adapted
# by work_type (feature / enhancement / fix / chore). Writes
# .claude/shared/preflight-cache.json that downstream skills (ux, design, dev,
# qa, analytics, cx, ops, release, marketing, research) read instead of
# re-collecting data. Schema: docs/skills/preflight-cache-schema.md.
#
#   make preflight WORK_TYPE=feature FEATURE=my-feature
#   make preflight WORK_TYPE=chore
#   make preflight WORK_TYPE=enhancement FEATURE=parent-feature
#   make preflight WORK_TYPE=fix
preflight:
	@if [ -z "$(WORK_TYPE)" ]; then \
		echo "ERROR: WORK_TYPE required. Usage: make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]"; \
		exit 2; \
	fi
	@python3 scripts/preflight.py --work-type $(WORK_TYPE) $(if $(FEATURE),--feature $(FEATURE),)
	@$(MAKE) --no-print-directory freshness-check

# 2026-05-28: cross-layer freshness check. Closes the 4-layer gap that
# `make preflight` doesn't cover: (1) recent merged PRs both repos, (2)
# worktree-vs-main divergence per worktree, (3) memory-vs-feature-state
# drift, (4) Linear sync (optional, requires LINEAR_API_KEY).
#
# Triggered:
#   - `make freshness-check`       (standalone)
#   - `make preflight`             (auto-chained above)
#   - SessionStart hook            (surfaces top-line summary)
#
# Read-only advisory. Exit 0 always.
freshness-check:
	@python3 scripts/cross-layer-freshness.py $(if $(DAYS),--days $(DAYS),)

# v7.8.5: P0.4 from docs/skills/skills-review-2026-05-13.md — mechanical
# conformance check for .claude/skills/*/SKILL.md (frontmatter present,
# trigger-rich descriptions, observed-patterns reference, adapter + script
# refs resolve on disk). Ships --advisory inside integrity-check during the
# v7.8.5 → v7.9 window; flip to enforced once 7+ days of clean runs accumulate.
skills-audit:
	python3 scripts/skills-audit.py

# v7.8.5: P1.3 from docs/skills/skills-review-2026-05-13.md — self-test
# fixtures for /ux preflight + /design preflight. Walks
# .claude/skills/{ux,design}/fixtures/{valid,invalid}-*.md and asserts each
# fixture's outcome matches its filename prefix (valid- → 0 P0, invalid- → ≥1 P0).
# Catches preflight prompt-drift regressions.
preflight-fixture-test:
	python3 scripts/preflight-fixture-test.py

# v7.8.5: print the Observed Patterns catalog — manifest of gate-firing
# patterns operators must recognize before debugging. Append-only-by-default.
# Established 2026-05-13. Used as preflight by /pm-workflow.
observed-patterns:
	@if [ -f .claude/integrity/observed-patterns.md ]; then \
		cat .claude/integrity/observed-patterns.md | less -R; \
	else \
		echo "ERROR: .claude/integrity/observed-patterns.md not found. Run from repo root."; \
		exit 1; \
	fi

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

# v7.7 M3 heuristic tier-tag correctness checker (advisory).
# Extracts T1-tagged quantitative claims from case studies and cross-references
# against measurement-adoption.json + documentation-debt.json within 5% tolerance.
# T2/T3 claims pass through. Pre-2026-04-21 case studies exempt.
# Advisory: exits 0 even when findings are emitted. Promotion to gate at +7d review (T20).
validate-tier-tags:
	@python3 scripts/validate-tier-tags.py --all

# Validate state.json schema across all features (pass if every file uses the
# canonical `current_phase` key instead of the legacy `phase` key).
schema-check:
	python3 scripts/check-state-schema.py

# Generate the baseline documentation-debt report used by the control room.
documentation-debt:
	python3 scripts/documentation-debt-report.py --output .claude/shared/documentation-debt.json

# T22 (framework-v7-8-branch-isolation): system-wide branch-isolation status
# readout. Lists every active feature with declared branch + worktree path +
# actual git/launchd state. Per PRD §6.1.
verify-isolation:
	@python3 scripts/verify-isolation.py

# T23 (framework-v7-8-branch-isolation): system-wide phase-appropriate
# completeness audit. Replaces the manual reconcile pass. Per PRD §6.2.
feature-completeness-audit:
	@python3 scripts/feature-completeness-audit.py

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
# Also installs custom merge drivers (v7.8 Mechanism E) so append-only
# ledger conflicts auto-resolve via union-dedup-by-key.
# Idempotent — run after clone to activate both layers.
install-hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks installed (core.hooksPath = .githooks)."
	@echo "Pre-commit will reject state.json files with legacy \`phase\` key."
	@echo "Emergency bypass: git commit --no-verify"
	@bash scripts/install-merge-drivers.sh

# Mechanism D (v7.8 §4.4) — assert that every gate listed in the
# .githooks/pre-commit header is implemented in scripts/check-state-schema.py
# or scripts/check-case-study-preflight.py. Catches header-vs-code drift.
pre-commit-self-test:
	python3 scripts/pre-commit-self-test.py

# Mechanism F (v7.8 §4.6) — read-only smartlog of in-flight feature work.
# Joins .claude/features/*/state.json + .claude/shared/agent-leases.json +
# `git for-each-ref refs/heads/feature/*` into one ASCII table (default)
# or JSON (--format=json) for the UCC dashboard.
membrane-status:
	python3 scripts/membrane-status.py

# v7.9 measurement-window snapshot (spec §7.2) — read the v7.8 advisory
# ledgers (gate-coverage.jsonl, _session-*.events.jsonl, reducer-misses.json)
# and produce the +7d / +14d / +21d decision-input report. Run any time;
# meaningful from first commit forward, design-actionable at +7d (2026-05-11).
# Pass OUTPUT=path.md to write Markdown to a file.
OUTPUT ?=
v7-9-snapshot:
	python3 scripts/v7-9-measurement-snapshot.py $(if $(OUTPUT),--output $(OUTPUT),)

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

# R10 (FIT-176): defensive check that `make verify-local` does NOT mutate
# tracked repo state. Captures git porcelain before + after; asserts
# byte-identical. Use as pre-merge sanity or as a standing guard against
# future regressions where a new verify-local subtarget might quietly
# write to a tracked file. See docs/setup/verify-local-idempotency-audit.md.
verify-local-idempotent-check:
	@echo "=== verify-local idempotency check ==="
	@_before=$$(mktemp); _after=$$(mktemp); \
	 git status --porcelain | sort > $$_before; \
	 echo "→ pre-state: $$(wc -l < $$_before | tr -d ' ') file(s) in porcelain"; \
	 $(MAKE) --no-print-directory verify-local || { rm -f $$_before $$_after; exit 1; }; \
	 git status --porcelain | sort > $$_after; \
	 echo "→ post-state: $$(wc -l < $$_after | tr -d ' ') file(s) in porcelain"; \
	 if diff -q $$_before $$_after >/dev/null 2>&1; then \
	   echo "✓ verify-local is idempotent — no tracked-file mutations detected"; \
	   rm -f $$_before $$_after; \
	 else \
	   echo "✗ verify-local mutated tracked state — review diff:"; \
	   diff $$_before $$_after || true; \
	   rm -f $$_before $$_after; \
	   exit 1; \
	 fi

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

# ─── figma-drift (fitme-story-website-design-system Bucket D) ──────────────
# Cross-checks the fitme-story design-system manifest (src/lib/design-system.ts)
# against the .figma.tsx mapping files in src/components/**. Optional: appends
# a dated snapshot to docs/design-system/figma-code-sync-status.md.
#
# Requires the fitme-story checkout to live next to FitTracker2 at
# /Volumes/DevSSD/fitme-story (or an isolated worktree under /Volumes/DevSSD/).
# If not found, the target prints a hint and exits 0.
figma-drift:
	@FITME_STORY_DIR=$$(ls -d /Volumes/DevSSD/fitme-story 2>/dev/null | head -1); \
	if [ -z "$$FITME_STORY_DIR" ]; then \
		echo "make figma-drift: fitme-story checkout not found at /Volumes/DevSSD/fitme-story"; \
		echo "  → clone Regevba/fitme-story alongside FitTracker2, then re-run."; \
		exit 0; \
	fi; \
	echo "Running figma-drift in $$FITME_STORY_DIR..."; \
	cd "$$FITME_STORY_DIR" && npm run figma-drift -- $(FIGMA_DRIFT_FLAGS)

# Per-phase snapshot of feature artifacts to off-SSD backup (~/Documents/FitTracker2-backups/).
# Spec §10; addresses SanDisk Extreme hardware risk.
# Usage: make snapshot-phase PHASE=<id> [FEATURE=<name>]
# Example: make snapshot-phase PHASE=phase-0-complete
snapshot-phase:
	@if [ -z "$(PHASE)" ]; then echo "Usage: make snapshot-phase PHASE=<id> [FEATURE=<name>]"; exit 1; fi
	./scripts/snapshot-phase-completion.sh $(PHASE) $${FEATURE:-cross-repo-state-sync-impl}

# Daily full-platform integrity checkpoint. Captures the same telemetry surface
# as the 2026-05-14 platform baseline (6 make outputs + all shared ledgers + all
# 70 state.json files + Mechanism A summary + git context for both repos).
# Writes to BOTH local-internal (~/Documents/FitTracker2-backups/daily/) AND
# SSD-sibling (/Volumes/DevSSD/FitTracker2-snapshots/) and appends one row to
# .claude/shared/integrity-checkpoint-ledger.jsonl with regression detection
# vs the previous row. Idempotent — re-fires same day are no-ops.
daily-checkpoint:
	python3 scripts/daily-integrity-checkpoint.py

# Force-overwrite today's checkpoint (use to re-snapshot after fixing a
# regression flagged in the ledger, or after a state-mutating operation).
daily-checkpoint-force:
	python3 scripts/daily-integrity-checkpoint.py --force

# Display the human-readable ledger.
ledger:
	@if [ -f .claude/shared/integrity-checkpoint-ledger.md ]; then \
		less -R .claude/shared/integrity-checkpoint-ledger.md; \
	else \
		echo "No ledger yet. Run: make daily-checkpoint"; \
	fi

# Install daily-checkpoint launchd cron (fires at 06:00 local time daily).
# Operator-driven install: requires user authorization before modifying ~/Library/LaunchAgents/.
install-daily-cron:
	@PLIST_DEST=$$HOME/Library/LaunchAgents/com.fittracker.daily-integrity-checkpoint.plist; \
	if [ -f "$$PLIST_DEST" ]; then \
		echo "Already installed: $$PLIST_DEST"; \
		echo "To reinstall: make uninstall-daily-cron && make install-daily-cron"; \
		exit 0; \
	fi; \
	cp infrastructure/launchd/com.fittracker.daily-integrity-checkpoint.plist.template "$$PLIST_DEST"; \
	launchctl load "$$PLIST_DEST"; \
	echo "Installed launchd cron: $$PLIST_DEST"; \
	echo "Will fire daily at 06:00 local time."; \
	echo "Verify with: launchctl list | grep fittracker"; \
	echo "Logs at:    ~/Library/Logs/fittracker-daily-checkpoint.{log,err}"

uninstall-daily-cron:
	@PLIST_DEST=$$HOME/Library/LaunchAgents/com.fittracker.daily-integrity-checkpoint.plist; \
	if [ ! -f "$$PLIST_DEST" ]; then \
		echo "Not installed: $$PLIST_DEST"; \
		exit 0; \
	fi; \
	launchctl unload "$$PLIST_DEST" 2>/dev/null || true; \
	rm "$$PLIST_DEST"; \
	echo "Uninstalled: $$PLIST_DEST"

# R4 (FIT-170): replug-detection watcher. Fires every 5 min; loud warning when
# /Volumes/DevSSD's volume UUID changes vs R3's baseline. Idempotent install.
install-devssd-watcher:
	@PLIST_DEST=$$HOME/Library/LaunchAgents/com.fittracker.devssd-uuid-watcher.plist; \
	if [ -f "$$PLIST_DEST" ]; then \
		echo "Already installed: $$PLIST_DEST"; \
		echo "To reinstall: make uninstall-devssd-watcher && make install-devssd-watcher"; \
		exit 0; \
	fi; \
	cp infrastructure/launchd/com.fittracker.devssd-uuid-watcher.plist.template "$$PLIST_DEST"; \
	launchctl load "$$PLIST_DEST"; \
	echo "Installed launchd watcher: $$PLIST_DEST"; \
	echo "Polls /Volumes/DevSSD volume UUID every 5 min vs R3 baseline."; \
	echo "Verify with: launchctl list | grep devssd-uuid"; \
	echo "Audit log:   .claude/logs/devssd-uuid-watcher.log"; \
	echo "stdout/err:  ~/Library/Logs/fittracker-devssd-uuid-watcher.{log,err}"

uninstall-devssd-watcher:
	@PLIST_DEST=$$HOME/Library/LaunchAgents/com.fittracker.devssd-uuid-watcher.plist; \
	if [ ! -f "$$PLIST_DEST" ]; then \
		echo "Not installed: $$PLIST_DEST"; \
		exit 0; \
	fi; \
	launchctl unload "$$PLIST_DEST" 2>/dev/null || true; \
	rm "$$PLIST_DEST"; \
	echo "Uninstalled: $$PLIST_DEST"

# R16 (FIT-182): read-only cache hit-rate audit. Surfaces per-entry
# mtime + cross-references against Mechanism C session reads to flag
# cold candidates. Output to stdout only; operator decides eviction.
audit-cache:
	@python3 scripts/audit-cache-hit-rate.py

# R23 (FIT-189): scripts/ third-party import survey. Categorizes each
# .py file as CORE (stdlib + local) or RESEARCH (third-party). Helps
# decide whether vendor/ is needed (today's answer: no — all
# operational scripts are stdlib-only).
audit-imports:
	@python3 scripts/audit-script-imports.py

# R11 (FIT-177): one-shot dev-env sanity readout. Read-only — integrates
# every preflight signal (SSH, gh auth, hooks, tool versions, PR cache,
# SSD health, R3 hardware baseline, R4 watcher, integrity, doc-debt) into
# a single colored table. Use when something feels off.
doctor:
	@bash scripts/doctor.sh

# R20 (FIT-186): rotate / prune integrity-check snapshots under
# .claude/integrity/snapshots/<TIMESTAMP>.json. Companion to R2 (checkpoint
# rotation) — same retention policy, different target dir.
# Dry-run by default — re-run with EXECUTE=1 to apply.
#   make integrity-snapshot-rotate                      # dry-run, default keep-30
#   make integrity-snapshot-rotate EXECUTE=1            # apply
#   make integrity-snapshot-rotate KEEP_COUNT=60 EXECUTE=1
integrity-snapshot-rotate:
	@python3 scripts/rotate-integrity-snapshots.py \
		$(if $(KEEP_COUNT),--keep-count=$(KEEP_COUNT),) \
		$(if $(EXECUTE),--execute,)

# R8 (FIT-174): rotate .claude/logs/<feature>.log.json files when they
# exceed 5MB. Tier 2.2 lineage preserved — rotation MOVES into
# .claude/logs/_archive/, never deletes.
# Dry-run by default; EXECUTE=1 applies. Override THRESHOLD_MB.
#   make logs-rotate                          # dry-run, default 5MB threshold
#   make logs-rotate EXECUTE=1                # apply
#   make logs-rotate THRESHOLD_MB=10 EXECUTE=1
logs-rotate:
	@python3 scripts/rotate-feature-logs.py \
		$(if $(THRESHOLD_MB),--threshold-mb=$(THRESHOLD_MB),) \
		$(if $(EXECUTE),--execute,)

# R9 (FIT-175): archive Mechanism C session ledgers older than 30 days.
# Sessions MOVED to .claude/logs/_archive/sessions/, never deleted.
# Default min-age 30d is conservative — Mechanism C lookup is days, not weeks.
#   make sessions-compact                          # dry-run
#   make sessions-compact EXECUTE=1                # apply
#   make sessions-compact MIN_AGE_DAYS=60 EXECUTE=1
sessions-compact:
	@python3 scripts/compact-session-ledgers.py \
		$(if $(MIN_AGE_DAYS),--min-age-days=$(MIN_AGE_DAYS),) \
		$(if $(EXECUTE),--execute,)

# Auto-install on first run
node_modules:
	npm install --silent

# v7.8.3 D-3: unified cross-repo PR cite cache (per spec §5)
refresh-pr-cache:
	python3 scripts/refresh-pr-cache.py

validate-existing-cites: refresh-pr-cache
	@echo "Validating PR cites in all docs/case-studies/*.md against unified cache…"
	@python3 scripts/check-case-study-preflight.py docs/case-studies/*.md

# ─────────────────────────────────────────────────────────────
# Impartial Audit Substrate
# ─────────────────────────────────────────────────────────────

.PHONY: audit-bundle audit-prompts-self-check

audit-bundle:
	@if [ -z "$(if $(filter command line environment,$(origin PROFILE)),$(PROFILE),)" ]; then \
		echo "Usage: make audit-bundle PROFILE=<name>"; \
		echo "Available profiles: base v7-9-promotion v7-9-1-f16-plus-hadf v8-0-gates-plus-hadf-closure freshness"; \
		exit 1; \
	fi
	python3 scripts/audit/build_bundle.py --profile=$(PROFILE) $(if $(RUN_LABEL),--run-label=$(RUN_LABEL))

audit-prompts-self-check:
	python3 scripts/audit/check_prompts.py

memory-check:
	@python3 scripts/check-memory-staleness.py
