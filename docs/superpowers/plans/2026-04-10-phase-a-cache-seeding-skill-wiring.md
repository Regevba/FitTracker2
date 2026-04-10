# Phase A: Cache Seeding + SKILL.md Wiring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Populate the L1/L2/L3 learning cache with real patterns from 6 completed v2 refactors, wire all 11 SKILL.md files with cache protocol + adapter + research scope sections, codify the validation gate in skill-routing.json, and introduce the framework self-health system as an organic part of the hub — advancing the ecosystem to **v4.2**.

**Architecture:** Top-down extraction from the case study (§3). Cache entries follow `.claude/cache/_index.json` schema. SKILL.md files get 4 new sections (cache protocol, adapters, research scope, health check). The health check is native to the hub — not a bolt-on. It runs as Phase 0 of the Skill Internal Lifecycle (before Cache Check), making the lifecycle 5 phases: Health → Cache → Research → Execute → Learn. This is the v4.2 advancement.

**Framework version:** v4.1 → **v4.2** (self-healing hub with integrity verification)

**Tech Stack:** JSON (cache entries, config), Markdown (SKILL.md wiring)

**Rollback:** `git reset --hard phase-a-pre-seeding` restores pre-Phase-A state.

---

## Task 1: Seed 5 L1 Cache Entries

**Files:**
- Create: `.claude/cache/ux/v2-screen-audit-playbook.json`
- Create: `.claude/cache/design/token-compliance-checker.json`
- Create: `.claude/cache/analytics/screen-prefix-convention.json`
- Create: `.claude/cache/dev/v2-implementation-recipe.json`
- Create: `.claude/cache/qa/analytics-test-patterns.json`

Each file follows the exact schema from `.claude/cache/_index.json` (entry_schema section). Use existing entries like `.claude/cache/_shared/ux-foundations-map.json` as the format reference.

- [ ] **Step 1: Create `/ux` L1 cache entry**

Write `.claude/cache/ux/v2-screen-audit-playbook.json` with:
- `cache_key`: `"ux:v2_screen_audit:audit_methodology"`
- `skill`: `"ux"`
- `level`: `"L1"`
- `created`/`last_hit`: `"2026-04-10T00:00:00Z"`
- `hit_count`: 5 (used on Home, Training, Nutrition, Stats, Settings)
- `ttl_strategy`: `"until_invalidated"`
- `invalidated_by`: `["docs/design-system/ux-foundations.md"]`
- `task_signature.type`: `"v2_screen_audit"`
- `task_signature.inputs`: `["screen_name", "v1_file_path", "ux_foundations_path"]`
- `task_signature.context`: `"Audit a v1 Swift screen against 13 UX Foundations principles. Produce v2-audit-report.md with P0/P1/P2 severity."`
- `learned_patterns[]`: 4 entries — (1) principle-to-pattern mapping with all 13 principles listed, (2) severity calibration (P0=token+analytics+a11y, P1=UX behavior+states, P2=copy+deferred), (3) diminishing returns awareness (later screens have fewer findings — not degradation), (4) front-load anti-patterns (check known violations first)
- `anti_patterns[]`: 2 entries — (1) re-deriving principle mappings (source: Home v2 2h vs Nutrition 30min), (2) auditing already-fixed patterns
- `speedup_instructions`: `"Load L2 ux-foundations-map.json for principle mapping. Check anti-pattern library first. Only investigate novel patterns not covered by cache."`

- [ ] **Step 2: Create `/design` L1 cache entry**

Write `.claude/cache/design/token-compliance-checker.json` with:
- `cache_key`: `"design:token_compliance:audit_and_evolve"`
- `skill`: `"design"`, `level`: `"L1"`, `hit_count`: 5
- `invalidated_by`: `["FitTracker/Services/AppTheme.swift", "FitTracker/DesignSystem/AppComponents.swift"]`
- `task_signature.type`: `"token_compliance_audit"`
- `learned_patterns[]`: 3 entries — (1) token categories that fail first (Color > spacing > fonts), (2) DS evolution rate (0 tokens in v2.0, 2-4 per refactor in v4.0+, propose new token when pattern repeats 2+ times), (3) compound reuse tracking (ProgressBar from Nutrition available for Stats, AppLayout from Stats available for Settings)
- `anti_patterns[]`: 2 entries — (1) over-tokenizing one-off values, (2) missing pbxproj update (Onboarding had 3 fix commits)
- `speedup_instructions`: `"Load L2 design-system-decisions.json for token inventory. Grep for Color.white, .black, hex values, hardcoded padding. Fix with existing tokens first; new tokens only for 2+ occurrence patterns."`

- [ ] **Step 3: Create `/analytics` L1 cache entry**

Write `.claude/cache/analytics/screen-prefix-convention.json` with:
- `cache_key`: `"analytics:event_spec:screen_prefix_convention"`
- `skill`: `"analytics"`, `level`: `"L1"`, `hit_count`: 4 (Training, Nutrition, Stats, Settings)
- `invalidated_by`: `["CLAUDE.md", "docs/product/analytics-taxonomy.csv"]`
- `task_signature.type`: `"analytics_event_spec"`
- `learned_patterns[]`: 3 entries — (1) screen-prefix naming rule with full prefix table (home_, training_, nutrition_, stats_, settings_, onboarding_, auth_), (2) event template per screen type ({screen}_action_tap, {screen}_metric_viewed, {screen}_empty_state_shown, {screen}_error_shown), (3) test pattern per event (1-3 tests: fires on action, correct params, optional no-fire in wrong state, target 1.3-2.7x density)
- `anti_patterns[]`: 2 entries — (1) ad hoc naming pre-convention, (2) over-testing events (Home 5.25x was wasteful)
- `speedup_instructions`: `"Apply screen-prefix rule mechanically. For each action, generate {screen}_{action}. Cross-ref analytics-taxonomy.csv. Generate 2 tests per event (fires + params)."`

- [ ] **Step 4: Create `/dev` L1 cache entry**

Write `.claude/cache/dev/v2-implementation-recipe.json` with:
- `cache_key`: `"dev:v2_implementation:directory_convention_recipe"`
- `skill`: `"dev"`, `level`: `"L1"`, `hit_count`: 5
- `invalidated_by`: `["CLAUDE.md", "FitTracker.xcodeproj/project.pbxproj"]`
- `task_signature.type`: `"v2_screen_implementation"`
- `learned_patterns[]`: 3 entries — (1) v2/ directory recipe (4-step: create dir, create file with same type name, pbxproj swap — add v2 PBXGroup+FileRef+BuildFile, remove v1 from Sources, keep v1 as FileRef — add HISTORICAL header to v1), (2) extracted view pattern (>400 lines → extract sub-views into same v2/ dir, Training extracted 6), (3) commit strategy (one commit for v2+pbxproj, separate for analytics, tests, docs)
- `anti_patterns[]`: 3 entries — (1) patching v1 in place (Onboarding: 20 patches, harder to diff), (2) forgetting pbxproj (3 fix commits), (3) building top-down from v1 (should build bottom-up from design system)
- `speedup_instructions`: `"Follow the 4-step v2/ recipe. If v1 > 400 lines, plan extracted views. Update pbxproj in same commit. Build bottom-up from AppTheme + AppComponents."`

- [ ] **Step 5: Create `/qa` L1 cache entry**

Write `.claude/cache/qa/analytics-test-patterns.json` with:
- `cache_key`: `"qa:analytics_testing:right_sized_patterns"`
- `skill`: `"qa"`, `level`: `"L1"`, `hit_count`: 5
- `invalidated_by`: `["FitTracker/Services/Analytics/AnalyticsService.swift"]`
- `task_signature.type`: `"analytics_test_planning"`
- `learned_patterns[]`: 3 entries — (1) right-sized test density (1.3-2.7 tests/event — below 1.0 under-tested, above 3.0 over-tested), (2) test template (test fires on action, test params correct, optional no-fire test), (3) test file naming ({Screen}AnalyticsTests.swift, one file per screen)
- `anti_patterns[]`: 2 entries — (1) over-testing (Home 5.25x was one-time learning cost), (2) testing implementation details (test event fires, not analytics internals)
- `speedup_instructions`: `"For each event, generate 2 tests (fires + params). Add 3rd only for plausible false-positive. Target 1.3-2.7x density. File: {Screen}AnalyticsTests.swift."`

- [ ] **Step 6: Commit**

```bash
git add .claude/cache/ux/v2-screen-audit-playbook.json .claude/cache/design/token-compliance-checker.json .claude/cache/analytics/screen-prefix-convention.json .claude/cache/dev/v2-implementation-recipe.json .claude/cache/qa/analytics-test-patterns.json
git commit -m "feat(cache): seed 5 L1 cache entries from v2 refactor patterns"
```

---

## Task 2: Update L2 + L3 Cache Entries

**Files:**
- Modify: `.claude/cache/_shared/ux-foundations-map.json`
- Modify: `.claude/cache/_shared/screen-refactor-playbook.json`
- Modify: `.claude/cache/_shared/design-system-decisions.json`
- Modify: `.claude/cache/_project/architecture-patterns.json`
- Modify: `.claude/cache/_project/anti-patterns.json`

- [ ] **Step 1: Update L2 `ux-foundations-map.json`**

Read the file, then update:
- `hit_count`: 6 (was 1)
- `last_hit`: `"2026-04-10T22:00:00Z"`
- Add all 6 refactors to `source_executions` arrays on each learned_pattern: `"onboarding-v2 (PR #59)"`, `"home-today-screen (PR #61)"`, `"training-plan-v2 (PR #74)"`, `"nutrition-v2 (PR #75)"`, `"stats-v2 (PR #76)"`, `"settings-v2 (PR #77)"`
- Ensure all 13 principles have confidence: `"high"` (validated across 6 screens)

- [ ] **Step 2: Update L2 `screen-refactor-playbook.json`**

Read the file, then update:
- `hit_count`: 6 (was 1)
- `last_hit`: `"2026-04-10T22:00:00Z"`
- Add Nutrition, Stats, Settings to `source_executions` on each learned_pattern (currently only has Home and Training)
- Add new learned_pattern: `"Cache-accelerated refactors (v4.1)"` — decision: "v4.1 refactors (Nutrition, Stats, Settings) completed in 1-2h each vs 5-36h for earlier screens. L2 cache hits on ux-foundations-map and design-system-decisions eliminated research phase re-derivation." confidence: high, sources: all 3 v4.1 state.json files.

- [ ] **Step 3: Update L2 `design-system-decisions.json`**

Read the file, then update:
- `hit_count`: 6 (was 1)
- `last_hit`: `"2026-04-10T22:00:00Z"`
- Add to the "When to add new tokens" learned_pattern source_executions: `"nutrition-v2: 4 tokens + AppOpacity enum"`, `"stats-v2: 3 tokens + AppLayout enum"`, `"settings-v2: 0 tokens (all existing covered)"`, `"PR #78: 4 raw color literals fixed for 100% compliance"`
- Add to the "Component promotion" learned_pattern promoted_components: `"ProgressBar": "Reusable progress indicator. Added Nutrition v2. Used in Stats v2."`, `"AppLayout": "Layout constants enum (chartHeight, emptyStateMinHeight, chipMin/Ideal/Max, dotSize). Added Stats v2. Used in Settings v2."`

- [ ] **Step 4: Update L3 `architecture-patterns.json`**

Read the file, then update:
- `hit_count`: 6 (was 1)
- `last_hit`: `"2026-04-10T22:00:00Z"`
- Add new learned_pattern: `"v2_subdirectory_convention"` — decision: "The v2/ subdirectory convention is a validated architectural pattern with 5 successful applications (Home, Training, Nutrition, Stats, Settings). Onboarding was the pilot pre-convention (patched v1 in place). The convention scales to multi-file decomposition (Training: 7 files in v2/)." confidence: high, sources: all 5 post-Onboarding PRs.

- [ ] **Step 5: Update L3 `anti-patterns.json`**

Read the file, then add 4 new anti_patterns:
1. `"patching_v1_in_place"` — Onboarding v2 used 20 inline patches instead of creating fresh v2 file. Made diffing harder, missed structural improvements. Source: Onboarding PR #59.
2. `"forgetting_pbxproj_update"` — Onboarding had 3 fix commits for pbxproj target membership. Fix: always update pbxproj in same commit as v2 file creation. Source: Onboarding PR #59.
3. `"over_testing_analytics_events"` — Home v2 had 5.25 tests/event (21 tests, 4 events). Right-sized is 1.3-2.7x. Over-testing wastes time without improving signal. Source: Home PR #61.
4. `"re_deriving_cached_patterns"` — Home v2 spent 2h deriving UX principle mappings from scratch. By Nutrition v2, L2 cache had the full mapping (30min). Never re-derive what's cached. Source: Home vs Nutrition comparison.

- [ ] **Step 6: Commit**

```bash
git add .claude/cache/_shared/ .claude/cache/_project/
git commit -m "feat(cache): update L2/L3 entries with data from all 6 refactors"
```

---

## Task 3: Wire 5 Core SKILL.md Files (ux, design, analytics, dev, qa)

**Files:**
- Modify: `.claude/skills/ux/SKILL.md`
- Modify: `.claude/skills/design/SKILL.md`
- Modify: `.claude/skills/analytics/SKILL.md`
- Modify: `.claude/skills/dev/SKILL.md`
- Modify: `.claude/skills/qa/SKILL.md`

Append 3 sections to the END of each SKILL.md. Read each file first to find the append point.

- [ ] **Step 1: Wire `/ux` SKILL.md**

Append to `.claude/skills/ux/SKILL.md`:

```markdown
---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/ux/_index.json` for L1 entries
2. Match current task against `task_signature.type` (e.g., `v2_screen_audit`)
3. Check L2 `.claude/cache/_shared/ux-foundations-map.json` for cross-skill patterns
4. If hit: load `learned_patterns`, `anti_patterns`, `speedup_instructions`
5. Apply — skip principle derivation steps covered by cache
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns (e.g., new principle→pattern mapping discovered)
2. Extract anti-patterns (e.g., a finding category that wasted time)
3. Write/update L1 entry in `.claude/cache/ux/`
4. If pattern applies to /design or /qa too, flag for L2 promotion

### Health Check (random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks
4. Proceed to cache check

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| axe (a11y) | `.claude/integrations/axe/` | design-system.json, test-coverage.json | On `/ux validate` or `/ux audit` |

**Fallback:** If axe MCP unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. **UX principles** — map applicable principles from `docs/design-system/ux-foundations.md` (13 principles, 10 parts)
2. **Apple HIG patterns** — platform conventions for the screen type (navigation, input, feedback)
3. **Competitor UX patterns** — check `/research` cache or Firecrawl for comparable screens in competing apps
4. **Accessibility heuristics** — WCAG AA usability (clarity, cognitive load, feedback loops)
5. **State coverage** — verify all states handled (empty, loading, error, success, permission-denied)

**Source priority:** L2 cache > L1 cache > shared layer (cx-signals.json, design-system.json) > axe adapter > manual derivation
```

- [ ] **Step 2: Wire `/design` SKILL.md**

Append to `.claude/skills/design/SKILL.md`:

```markdown
---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/design/_index.json` for L1 entries
2. Match current task against `task_signature.type` (e.g., `token_compliance_audit`)
3. Check L2 `.claude/cache/_shared/design-system-decisions.json` for token patterns
4. If hit: load `learned_patterns`, `anti_patterns`, `speedup_instructions`
5. Apply — check known violation categories first (Color > spacing > fonts)
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns (e.g., new token added, component promoted)
2. Extract anti-patterns (e.g., over-tokenized a one-off value)
3. Write/update L1 entry in `.claude/cache/design/`
4. If token/component pattern applies cross-screen, flag for L2 promotion

### Health Check (random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks
4. Proceed to cache check

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| (none directly) | — | — | Reads design-system.json populated by other skills |

**Fallback:** N/A — no direct external adapter.

## Research Scope (Phase 2 — when cache misses)

1. **Token inventory** — current tokens in `FitTracker/Services/AppTheme.swift` and `design-tokens/tokens.json`
2. **Component library** — reusable components in `FitTracker/DesignSystem/AppComponents.swift`
3. **WCAG AA compliance** — contrast ratios, tap target sizes (44pt min), reduced motion support
4. **Figma design context** — retrieve via Figma MCP `get_design_context` for the target screen
5. **Motion and animation** — specs from `docs/design-system/ux-foundations.md` Part 8

**Source priority:** L2 cache > L1 cache > shared layer (design-system.json) > Figma MCP > AppTheme.swift direct read
```

- [ ] **Step 3: Wire `/analytics` SKILL.md**

Append to `.claude/skills/analytics/SKILL.md`:

```markdown
---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/analytics/_index.json` for L1 entries
2. Match current task against `task_signature.type` (e.g., `analytics_event_spec`)
3. Check L2 cache for cross-skill event patterns
4. If hit: load screen-prefix convention, event templates, test density targets
5. Apply — generate events mechanically from template
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns (e.g., new event category, parameter format)
2. Extract anti-patterns (e.g., naming collision, duplicate event)
3. Write/update L1 entry in `.claude/cache/analytics/`
4. If event pattern applies to /qa test generation, flag for L2 promotion

### Health Check (random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks
4. Proceed to cache check

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| ga4 | `.claude/integrations/ga4/` | metric-status.json, feature-registry.json | On `/analytics validate` or `/analytics report` |

**Fallback:** If GA4 MCP unavailable, continue with existing metric-status.json data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. **Screen-prefix naming convention** — rules in `CLAUDE.md` Analytics Naming Convention section
2. **Existing taxonomy** — check `docs/product/analytics-taxonomy.csv` for existing events
3. **GA4 recommended events** — use GA4 standard names where applicable (tutorial_begin, select_content, etc.)
4. **Funnel definitions** — metrics from the feature's PRD success criteria
5. **Dashboard patterns** — prior dashboard layouts and KPI groupings from completed features

**Source priority:** L2 cache > L1 cache > shared layer (metric-status.json) > ga4 adapter > analytics-taxonomy.csv
```

- [ ] **Step 4: Wire `/dev` SKILL.md**

Append to `.claude/skills/dev/SKILL.md`:

```markdown
---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/dev/_index.json` for L1 entries
2. Match current task against `task_signature.type` (e.g., `v2_screen_implementation`)
3. Check L2 `.claude/cache/_shared/screen-refactor-playbook.json` for cross-skill methodology
4. If hit: load v2/ recipe, extracted view pattern, commit strategy
5. Apply — follow recipe directly, skip convention re-derivation
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns (e.g., new file decomposition approach, build fix)
2. Extract anti-patterns (e.g., pbxproj mistake, compile error pattern)
3. Write/update L1 entry in `.claude/cache/dev/`
4. If pattern applies to /design or /qa, flag for L2 promotion

### Health Check (random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks
4. Proceed to cache check

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| security-audit | `.claude/integrations/security-audit/` | health-status.json, test-coverage.json | On `/dev deps` or `/dev review` |

**Fallback:** If security MCP unavailable, continue without CVE scan. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. **v2/ implementation convention** — rules in `CLAUDE.md` UI Refactoring & V2 Rule section
2. **Existing code patterns** — read target directory structure and naming conventions
3. **Build configuration** — `FitTracker.xcodeproj/project.pbxproj` structure, SPM dependencies
4. **CI pipeline requirements** — `make tokens-check`, `xcodebuild build`, `xcodebuild test`
5. **Performance baselines** — cold start time, build time from prior CI runs

**Source priority:** L2 cache > L1 cache > shared layer (health-status.json) > security-audit adapter > pbxproj direct read
```

- [ ] **Step 5: Wire `/qa` SKILL.md**

Append to `.claude/skills/qa/SKILL.md`:

```markdown
---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/qa/_index.json` for L1 entries
2. Match current task against `task_signature.type` (e.g., `analytics_test_planning`)
3. Check L2 cache for cross-skill test patterns
4. If hit: load test density targets, test templates, file naming convention
5. Apply — generate tests from template at 1.3-2.7x density
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns (e.g., new test category, coverage gap found)
2. Extract anti-patterns (e.g., over-tested, flaky test pattern)
3. Write/update L1 entry in `.claude/cache/qa/`
4. If test pattern applies to /analytics event spec, flag for L2 promotion

### Health Check (random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks
4. Proceed to cache check

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| axe (a11y) | `.claude/integrations/axe/` | design-system.json, test-coverage.json | On `/qa plan` or `/qa security` |
| security-audit | `.claude/integrations/security-audit/` | health-status.json | On `/qa security` |

**Fallback:** If adapters unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. **Test strategy patterns** — L1 cache for right-sized density and templates
2. **Coverage gaps** — check `.claude/shared/test-coverage.json` for untested areas
3. **Analytics test density** — target 1.3-2.7 tests per event (from case study data)
4. **Regression risk** — check `.claude/shared/change-log.json` for recent changes affecting this area
5. **Security checklist** — OWASP Mobile Top 10 for iOS (injection, auth, data storage, crypto)

**Source priority:** L2 cache > L1 cache > shared layer (test-coverage.json) > axe adapter > security-audit adapter
```

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/ux/SKILL.md .claude/skills/design/SKILL.md .claude/skills/analytics/SKILL.md .claude/skills/dev/SKILL.md .claude/skills/qa/SKILL.md
git commit -m "feat(skills): wire 5 core SKILL.md files with cache protocol + adapters + research scope"
```

---

## Task 4: Wire 6 Peripheral SKILL.md Files (cx, marketing, research, ops, release, pm-workflow)

**Files:**
- Modify: `.claude/skills/cx/SKILL.md`
- Modify: `.claude/skills/marketing/SKILL.md`
- Modify: `.claude/skills/research/SKILL.md`
- Modify: `.claude/skills/ops/SKILL.md`
- Modify: `.claude/skills/release/SKILL.md`
- Modify: `.claude/skills/pm-workflow/SKILL.md`

Same 3-section template. These skills have empty L1 caches (no refactor patterns to seed) but still need the protocol so they start caching on first use.

- [ ] **Step 1: Wire `/cx` SKILL.md**

Append cache protocol (L1 path: `.claude/cache/cx/`, empty on start), health check trigger, adapters table (app-store-connect → cx-signals.json on `/cx reviews`; sentry → health-status.json on `/cx analyze`), research scope: (1) review sentiment/keywords, (2) crash/error from Sentry, (3) feature satisfaction, (4) confusion/friction indicators, (5) NPS/rating trends. Source priority: L2 > L1 > shared (cx-signals.json) > app-store-connect > sentry.

- [ ] **Step 2: Wire `/marketing` SKILL.md**

Adapters: firecrawl → context.json on `/marketing competitive` or `/marketing aso`. Research: (1) ASO keywords, (2) competitor positioning, (3) channel performance, (4) content patterns, (5) campaign attribution. Source priority: L2 > L1 > shared (campaign-tracker.json) > firecrawl.

- [ ] **Step 3: Wire `/research` SKILL.md**

Adapters: firecrawl → context.json on `/research wide` or `/research competitive`. Research: (1) market landscape, (2) competitor features, (3) UX pattern libraries (Mobbin, Pttrns), (4) academic/industry sources, (5) technology trends. Source priority: L2 > L1 > shared (context.json) > firecrawl.

- [ ] **Step 4: Wire `/ops` SKILL.md**

Adapters: sentry → health-status.json on `/ops health` or `/ops incident`. Research: (1) service health, (2) incident patterns/MTTR, (3) cost trends, (4) alert threshold calibration, (5) CI reliability. Source priority: L2 > L1 > shared (health-status.json) > sentry.

- [ ] **Step 5: Wire `/release` SKILL.md**

Adapters: app-store-connect → feature-registry.json on `/release checklist` or `/release submit`. Research: (1) version history/changelog, (2) submission requirements, (3) TestFlight feedback, (4) regression checklist from change-log.json, (5) store metadata status. Source priority: L2 > L1 > shared (feature-registry.json) > app-store-connect.

- [ ] **Step 6: Wire `/pm-workflow` SKILL.md**

Adapters: ALL adapters (hub receives all validation gate notifications). Research: (1) phase transition patterns from state.json history, (2) work type selection heuristics, (3) task decomposition patterns, (4) priority scoring from task-queue.json, (5) change broadcast rules. Source priority: L2 > L1 > shared (all files) > all adapters.

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/cx/SKILL.md .claude/skills/marketing/SKILL.md .claude/skills/research/SKILL.md .claude/skills/ops/SKILL.md .claude/skills/release/SKILL.md .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(skills): wire 6 peripheral SKILL.md files with cache protocol + adapters + research scope"
```

---

## Task 5: Create Hub-Native Health Check System + Validation Gate (v4.2)

The health check is not a bolt-on — it is **Phase 0 of the Skill Internal Lifecycle**, making the lifecycle 5 phases: Health → Cache → Research → Execute → Learn. This advances the framework to v4.2.

**Files:**
- Create: `.claude/shared/framework-health.json`
- Modify: `.claude/shared/skill-routing.json`
- Modify: `.claude/cache/_index.json` (add health check as Phase 0 in lifecycle)

- [ ] **Step 1: Create framework-health.json**

Write `.claude/shared/framework-health.json` with the full config from the spec: version 1.0, check_config (trigger random 0.25, min_interval 2h, threshold 0.90), 5 checks with weights (cache_staleness 0.25, cache_hit_accuracy 0.25, shared_layer_consistency 0.20, skill_routing_integrity 0.15, adapter_availability 0.15), empty history array, scoring section (per_check pass/degraded/fail, alert levels healthy >= 0.95, warning 0.90-0.95, critical < 0.90). Include a `"rollback"` section documenting the 3 options (fix, rollback cache, rollback all to tag).

- [ ] **Step 2: Add validation_gate section to skill-routing.json**

Read `.claude/shared/skill-routing.json`, then add a top-level `"validation_gate"` key with: thresholds (green: 0.95, orange: 0.90), notification_targets per level, log_target (change-log.json), scoring rules (numeric_tolerance 0.05, new_field_fills_gap: always_consistent, measured_supersedes_estimated: always_consistent, two_measured_disagree: conflict), enforcement: automatic_scoring_manual_resolution.

- [ ] **Step 3: Update _index.json lifecycle to 5 phases**

Read `.claude/cache/_index.json`, update the `"lifecycle"` section to include Phase 0:
- Add `"on_skill_start_health"`: `"PHASE 0: Read framework-health.json. If random < probability AND hours_since(last_check) > min_interval: run 5 health checks, compute weighted score, log to history. If score < alert_threshold (0.90): STOP, alert user with failing checks and rollback options. If healthy: proceed to Phase 1 (Cache Check)."`
- Rename existing phases: Cache Check becomes Phase 1, Research becomes Phase 2, Execute becomes Phase 3, Learn becomes Phase 4.
- Update description to reference v4.2.

- [ ] **Step 4: Commit**

```bash
git add .claude/shared/framework-health.json .claude/shared/skill-routing.json .claude/cache/_index.json
git commit -m "feat(framework): v4.2 — hub-native health check as Phase 0 of skill lifecycle + validation gate"
```

---

## Task 6: Update Evolution Docs + README for v4.2

**Files:**
- Modify: `docs/skills/evolution.md`
- Modify: `docs/skills/README.md`
- Modify: `docs/skills/architecture.md` (Section 18 — add v4.2 section)

- [ ] **Step 1: Add v4.2 section to evolution.md**

Append after the v4.1 section (line ~560):

```markdown

---

## 19. v4.2 — Self-Healing Hub with Integrity Verification (2026-04-10)

### What Changed: v4.1 → v4.2

v4.1 gave skills a 4-phase internal lifecycle (Cache → Research → Execute → Learn). v4.2 adds **Phase 0 (Health Check)** — making the lifecycle 5 phases and introducing self-verification into the hub itself.

### The 5-Phase Skill Internal Lifecycle (v4.2)

```text
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ 0. HEALTH│───▶│ 1. CACHE │───▶│2. RESEARCH│───▶│3. EXECUTE│───▶│ 4. LEARN │
│  CHECK   │    │  CHECK   │    │ (if miss)│    │          │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

0. **Phase 0 — Health Check (random trigger):** On 25% of skill invocations (with 2h cooldown), run 5 weighted integrity checks against the cache, shared layer, routing config, and adapter layer. If score drops below 90%, STOP and alert. Self-healing: the hub monitors its own health.
1. **Phase 1 — Cache Check:** (unchanged from v4.1)
2. **Phase 2 — Research:** (unchanged)
3. **Phase 3 — Execute:** (unchanged)
4. **Phase 4 — Learn:** (unchanged) + now also updates `correction_count` if a cached pattern was overridden during execution (feeds back to health check accuracy scoring).

### The 5 Health Checks

| Check | Weight | What It Verifies |
|-------|--------|-----------------|
| Cache Staleness | 0.25 | SHA256 hashes of invalidated_by source files match. Stale entry = cache is lying. |
| Cache Hit Accuracy | 0.25 | hit_count vs correction_count ratio. Low accuracy = cache patterns are wrong. |
| Shared Layer Consistency | 0.20 | Cross-references between shared JSON files (feature status, metric instrumentation, token counts). |
| Skill Routing Integrity | 0.15 | Task types in skill-routing.json map to existing SKILL.md files and cache dirs. |
| Adapter Availability | 0.15 | Each adapter dir has adapter.md + schema.json + mapping.json. |

### Alert Levels

| Level | Score | Action |
|-------|-------|--------|
| Healthy | >= 0.95 | Silent. Log only. |
| Warning | 0.90 - 0.95 | Log + advisory to user. Continue execution. |
| Critical | < 0.90 | Log + STOP. Alert with failing checks. User chooses: fix, rollback cache, or rollback all. |

### Why This Matters

Without self-verification, a corrupted cache or inconsistent shared layer silently degrades every skill invocation. The health check catches drift before it compounds — the same principle as CI catching code drift.

### New File

- `.claude/shared/framework-health.json` — health check configuration, scoring weights, and history log

### Updated Files

- `.claude/cache/_index.json` — lifecycle now 5 phases (Phase 0 added)
- `.claude/shared/skill-routing.json` — validation_gate section added
- All 11 SKILL.md files — Health Check section added to Cache Protocol
```

- [ ] **Step 2: Update README.md evolution history**

In `docs/skills/README.md`, find the "Evolution history" bullet list and add:
```
- 2026-04-10 — v4.2: Self-healing hub. Phase 0 (Health Check) added to Skill Internal Lifecycle — 5 health checks at random intervals verify cache staleness, hit accuracy, shared layer consistency, routing integrity, and adapter availability. Alert if score drops below 90%. L1 cache seeded from 6 completed refactors. All 11 SKILL.md files wired with cache protocol, adapters, and research scope.
```

Also update the opening paragraph count: "12 skills (1 hub + 11 spokes) + 11 shared data files + 6 integration adapters + 3-level learning cache + automatic validation gate + **self-healing health check**"

- [ ] **Step 3: Update rules count in README.md**

In the "Rules that apply to every skill" section, add rule 11:
```
11. **Every skill runs Phase 0 (Health Check) on random trigger.** 25% probability, 2h cooldown. If score < 90%, execution halts until issues are resolved.
```

- [ ] **Step 4: Commit**

```bash
git add docs/skills/evolution.md docs/skills/README.md
git commit -m "docs: v4.2 evolution — self-healing hub with Phase 0 health check"
```

---

## Summary

| Task | Files | Commit |
|------|-------|--------|
| 1 | 5 L1 cache entries created | `seed 5 L1 cache entries` |
| 2 | 5 L2/L3 entries updated | `update L2/L3 entries` |
| 3 | 5 core SKILL.md files wired | `wire 5 core SKILL.md` |
| 4 | 6 peripheral SKILL.md files wired | `wire 6 peripheral SKILL.md` |
| 5 | framework-health.json + skill-routing.json + _index.json | `v4.2 health check + validation gate` |
| 6 | evolution.md + README.md | `v4.2 evolution docs` |

**Total: 6 tasks, 6 commits, ~25 files touched. Framework advances to v4.2.**
