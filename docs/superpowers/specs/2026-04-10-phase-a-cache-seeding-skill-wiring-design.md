# Phase A: Cache Seeding + SKILL.md Wiring — Design Spec

**Date:** 2026-04-10
**Goal:** Populate the L1/L2/L3 learning cache with real patterns from 6 completed v2 refactors, wire all 11 SKILL.md files with cache protocol + adapter + research scope sections, and codify the validation gate in skill-routing.json.

**Architecture:** Top-down extraction from the case study (§3 per-skill analysis) + state.json data into the existing `.claude/cache/` structure, followed by appending 3 standardized sections to each SKILL.md.

---

## Work Stream 1: Cache Seeding

### L1 Cache Entries (5 skills)

**Entry format:** Each entry follows the schema defined in `.claude/cache/_index.json` — `cache_key`, `task_signature`, `learned_patterns[]`, `anti_patterns[]`, `speedup_instructions`, `invalidated_by[]`, `hit_count`, timestamps.

#### 1.1 `/ux` — `v2-screen-audit-playbook`

**File:** `.claude/cache/ux/v2-screen-audit-playbook.json`

**task_signature:**
- type: `v2_screen_audit`
- inputs: `["screen_name", "v1_file_path", "ux_foundations_path"]`
- context: "Audit a v1 Swift screen against 13 UX Foundations principles. Produce v2-audit-report.md with P0/P1/P2 severity."

**learned_patterns:**
1. **Principle-to-pattern mapping** — pre-loaded mapping of which principles apply to which UI patterns (navigation depth → Hick's Law, data entry → Zero-Friction Logging, etc.). Confidence: high. Sources: Home, Training, Nutrition, Stats, Settings audits.
2. **Severity calibration** — P0 = token violations + missing analytics + broken a11y. P1 = UX behavior gaps + missing states. P2 = copy + content + deferred improvements. Confidence: high. Sources: all 6 audits.
3. **Diminishing returns awareness** — later screens in a refactor series have fewer findings (27→32→23→9→4). Lower count is not degradation — it means fewer issues exist. Confidence: high. Sources: case study §3.1.
4. **Front-load anti-patterns** — check known violations first (raw Color literals, missing VoiceOver labels, hardcoded spacing). Highest-value findings come from anti-pattern library. Confidence: high.

**anti_patterns:**
1. **Re-deriving principle mappings** — Home v2 spent 2h deriving which principles apply. By Nutrition, the L2 cache had the full mapping. Never re-derive from scratch. Source: Home v2.
2. **Auditing already-fixed patterns** — if a prior screen fixed a pattern (e.g., raw Color.white), don't flag it as a finding on the next screen unless it reappears. Source: Settings v2.

**speedup_instructions:** "Start by loading L2 `ux-foundations-map.json` for the principle→pattern mapping. Then check the anti-pattern library against the v1 file. Only investigate novel patterns not covered by cache."

**invalidated_by:** `["docs/design-system/ux-foundations.md"]`

#### 1.2 `/design` — `token-compliance-checker`

**File:** `.claude/cache/design/token-compliance-checker.json`

**task_signature:**
- type: `token_compliance_audit`
- inputs: `["screen_name", "swift_file_path", "AppTheme_path"]`
- context: "Check a SwiftUI file for raw color/spacing/font literals and propose semantic token replacements."

**learned_patterns:**
1. **Token categories that fail first** — Color literals (Color.white, .black, hex values) are the #1 violation. Raw spacing (.padding(16)) is #2. Raw fonts are #3. Check in this order. Confidence: high. Sources: all 6 refactors.
2. **DS evolution per refactor** — v2.0 added 0 tokens, v4.0+ added 2-4 per refactor. When a pattern appears 2+ times across screens, propose a new semantic token. Confidence: high.
3. **Compound reuse tracking** — components extracted in one refactor (ProgressBar from Nutrition, AppLayout from Stats) are immediately available for subsequent screens. Always check existing components before extracting new ones. Confidence: high.

**anti_patterns:**
1. **Over-tokenizing** — not every value needs a semantic token. One-off micro-adjustments (responsive padding for a specific layout) can stay as raw values. Only tokenize patterns that repeat. Source: Settings v2 (0 new tokens — all existing tokens covered it).
2. **Missing pbxproj update** — Onboarding v2 had 3 pbxproj fix commits because v2 files weren't added to the build target. Always update pbxproj in the same commit as the v2 file creation. Source: Onboarding v2.

**speedup_instructions:** "Load L2 `design-system-decisions.json` for the current token inventory. Grep for known violation patterns (Color.white, .black, hex values, hardcoded padding/font). Propose fixes using existing tokens first, new tokens only for 2+ occurrence patterns."

**invalidated_by:** `["FitTracker/Services/AppTheme.swift", "FitTracker/DesignSystem/AppComponents.swift"]`

#### 1.3 `/analytics` — `screen-prefix-convention`

**File:** `.claude/cache/analytics/screen-prefix-convention.json`

**task_signature:**
- type: `analytics_event_spec`
- inputs: `["screen_name", "feature_name", "analytics_taxonomy_path"]`
- context: "Define screen-prefixed analytics events for a feature, following the naming convention in CLAUDE.md."

**learned_patterns:**
1. **Screen-prefix naming rule** — every screen-scoped event MUST use `{screen}_` prefix (home_, training_, nutrition_, stats_, settings_, onboarding_). Cross-screen events stay unprefixed. GA4 recommended events keep their names. Confidence: high. Sources: CLAUDE.md, all 6 refactors.
2. **Event template per screen type** — typical events: `{screen}_action_tap`, `{screen}_metric_viewed`, `{screen}_empty_state_shown`, `{screen}_error_shown`. Customize but start from this template. Confidence: high.
3. **Test pattern per event** — each event gets 1-3 tests: (1) event fires on action, (2) event carries correct parameters, (3) optional: event does NOT fire in wrong state. Target density: 1.3-2.7 tests/event. Confidence: high.

**anti_patterns:**
1. **Ad hoc naming** — before Training v2, events were named inconsistently. Always apply the screen-prefix rule. Source: Onboarding v2, Home v2.
2. **Over-testing events** — Home v2 had 5.25 tests/event. This was wasteful. Right-sized is 1.3-2.7x. Source: case study §3.5.

**speedup_instructions:** "Load the screen-prefix naming rule from this cache. For each user action on the screen, generate a `{screen}_{action}` event name. Cross-reference against docs/product/analytics-taxonomy.csv to avoid duplicates. Generate 1-3 tests per event."

**invalidated_by:** `["CLAUDE.md", "docs/product/analytics-taxonomy.csv"]`

#### 1.4 `/dev` — `v2-implementation-recipe`

**File:** `.claude/cache/dev/v2-implementation-recipe.json`

**task_signature:**
- type: `v2_screen_implementation`
- inputs: `["screen_name", "v1_file_path", "v2_audit_report_path"]`
- context: "Implement a v2/ screen refactor following the CLAUDE.md v2 convention: create v2/ dir, same filename, swap in pbxproj, build bottom-up from design system."

**learned_patterns:**
1. **v2/ directory recipe** — (1) Create `{parent}/v2/` dir, (2) Create `{parent}/v2/{SameFilename}.swift` with same type name, (3) In pbxproj: add PBXGroup for v2/, add PBXFileReference + PBXBuildFile for v2 file, REMOVE v1 from Sources build phase (keep as PBXFileReference), (4) v1 gets HISTORICAL header comment. Confidence: high. Sources: all 5 post-Onboarding refactors.
2. **Extracted view pattern** — when a v2 file exceeds ~400 lines, extract sub-views into the same v2/ dir. Training v2 extracted 6 views from a 2,135-line v1. Each extracted view is a separate file in v2/. Confidence: high. Source: Training v2.
3. **Commit strategy** — one commit for v2 file creation + pbxproj swap. Separate commits for analytics instrumentation, test files, and documentation. Confidence: high.

**anti_patterns:**
1. **Patching v1 in place** — Onboarding v2 patched v1 with 20 inline changes. This made diffing harder and missed structural improvements. Always create a fresh v2 file. Source: Onboarding v2.
2. **Forgetting pbxproj** — Onboarding had 3 fix commits for pbxproj. Training onward had 1 clean commit. Always update pbxproj in the same commit as v2 file creation. Source: Onboarding v2.
3. **Building top-down from v1** — v2 should be built bottom-up from design system tokens/components, not by copying v1 and patching. Source: CLAUDE.md v2 rule.

**speedup_instructions:** "Follow the 4-step v2/ recipe from pattern #1. If v1 exceeds 400 lines, plan extracted views before coding. Update pbxproj in the same commit. Build bottom-up from AppTheme tokens + AppComponents."

**invalidated_by:** `["CLAUDE.md", "FitTracker.xcodeproj/project.pbxproj"]`

#### 1.5 `/qa` — `analytics-test-patterns`

**File:** `.claude/cache/qa/analytics-test-patterns.json`

**task_signature:**
- type: `analytics_test_planning`
- inputs: `["screen_name", "analytics_events_list", "existing_test_file"]`
- context: "Plan and write XCTest analytics tests for screen-prefixed events. Target 1.3-2.7 tests per event."

**learned_patterns:**
1. **Right-sized test density** — 1.3-2.7 tests per analytics event is the sweet spot. Below 1.0 = under-tested. Above 3.0 = over-tested (diminishing returns). Confidence: high. Sources: Training (1.3x), Nutrition (2.4x), Stats (2.5x), Settings (2.7x).
2. **Test template** — for each event: (1) test that event fires on the expected user action, (2) test that event parameters are correct (screen_name, action_type, etc.), (3) optional: test that event does NOT fire in wrong context. Confidence: high.
3. **Test file naming** — `{Screen}AnalyticsTests.swift` in the test target. One file per screen. Confidence: high. Sources: all 6 refactors.

**anti_patterns:**
1. **Over-testing** — Home v2 had 5.25 tests/event because test patterns were being established. This was a one-time learning cost, not a target. Source: Home v2, case study §3.5.
2. **Testing implementation details** — test that the event fires, not how the analytics service works internally. Source: general principle validated across all 6.

**speedup_instructions:** "Load the test template from this cache. For each event in the analytics spec, generate 2 tests (fires + correct params). Add a 3rd test only if there's a plausible false-positive scenario. Target 1.3-2.7x density."

**invalidated_by:** `["FitTracker/Services/Analytics/AnalyticsService.swift"]`

### L2 Cache Updates (3 entries)

Update existing entries in `.claude/cache/_shared/` with actual data from all 6 refactors:

**ux-foundations-map.json:** Update `hit_count` to 6, `last_hit` to 2026-04-10, add all 6 refactors to `source_executions`, and ensure all 13 principle mappings are present with confidence: high.

**screen-refactor-playbook.json:** Update with the complete v2 refactor recipe (from `/dev` L1 cache) as a cross-skill pattern. Add the full workflow: /ux audit → v2-audit-report → /ux spec → /design audit → /dev implement → /qa test. Source executions: all 6 refactors.

**design-system-decisions.json:** Update with token evolution data: which tokens were added per refactor, which components were extracted, the compound reuse chain (ProgressBar → Stats, AppLayout → Settings).

### L3 Cache Updates (2 entries)

**architecture-patterns.json:** Add `v2_subdirectory_convention` as a validated architectural pattern with 6 successful applications. Add `hub_and_spoke_skill_dispatch` as validated.

**anti-patterns.json:** Add `patching_v1_in_place` (source: Onboarding), `forgetting_pbxproj_update` (source: Onboarding), `over_testing_events` (source: Home), `re_deriving_cached_patterns` (source: Home).

---

## Work Stream 2: SKILL.md Wiring

Each of the 11 SKILL.md files gets 3 new sections appended at the end.

### Section Template

```markdown
---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/{skill}/_index.json`
2. Match current task against `task_signature.type` in L1 entries
3. Check L2 (`_shared/`) for cross-skill patterns matching this task type
4. If hit: load `learned_patterns`, `anti_patterns`, `speedup_instructions`
5. Apply loaded patterns — skip derivation steps covered by cache
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns and anti-patterns from this execution
2. Write or update L1 cache entry in `.claude/cache/{skill}/`
3. If pattern overlaps with an existing L2 entry, increment `hit_count`
4. If a new pattern applies to 2+ skills, flag for L2 promotion

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
{skill-specific rows — see table below}

**Fallback:** If adapter is unavailable, continue with existing shared layer data. Log unavailability to `change-log.json`.

## Research Scope (Phase 2 — when cache misses)

When L1/L2 cache misses for the current task, investigate these 5 dimensions:

1. {dimension 1}
2. {dimension 2}
3. {dimension 3}
4. {dimension 4}
5. {dimension 5}

**Source priority:** L2 cache > L1 cache > shared layer > external adapter > manual derivation
```

### Per-Skill Wiring Details

#### `/ux` SKILL.md
**Adapters:** axe → design-system.json, test-coverage.json — pull on /ux validate or /ux audit
**Research dimensions:** (1) UX principles from ux-foundations.md, (2) Apple HIG patterns for the screen type, (3) Competitor UX patterns from /research cache, (4) Accessibility heuristics (WCAG AA + cognitive), (5) State coverage (empty/loading/error/success)

#### `/design` SKILL.md
**Adapters:** None directly (reads from design-system.json populated by other skills)
**Research dimensions:** (1) Token inventory from AppTheme.swift, (2) Component library from AppComponents.swift, (3) WCAG AA contrast + tap target compliance, (4) Figma design context (via Figma MCP), (5) Motion/animation specs from ux-foundations.md §8

#### `/analytics` SKILL.md
**Adapters:** ga4 → metric-status.json, feature-registry.json — pull on /analytics validate or /analytics report
**Research dimensions:** (1) Screen-prefix naming convention from CLAUDE.md, (2) Existing taxonomy from analytics-taxonomy.csv, (3) GA4 recommended event names, (4) Funnel definitions from PRD metrics, (5) Dashboard template patterns from prior features

#### `/dev` SKILL.md
**Adapters:** security-audit → health-status.json, test-coverage.json — pull on /dev deps or /dev review
**Research dimensions:** (1) v2/ implementation convention from CLAUDE.md, (2) Existing code patterns in target directory, (3) Build configuration (pbxproj, SPM), (4) CI pipeline requirements (make tokens-check, xcodebuild), (5) Performance baselines from prior builds

#### `/qa` SKILL.md
**Adapters:** axe → design-system.json, test-coverage.json; security-audit → health-status.json — pull on /qa plan or /qa security
**Research dimensions:** (1) Test strategy patterns from L1 cache, (2) Coverage gaps from test-coverage.json, (3) Analytics test density targets (1.3-2.7x), (4) Regression risk from change-log.json, (5) Security checklist (OWASP Mobile Top 10)

#### `/cx` SKILL.md
**Adapters:** app-store-connect → cx-signals.json, feature-registry.json; sentry → health-status.json, cx-signals.json — pull on /cx reviews or /cx analyze
**Research dimensions:** (1) Review sentiment and keyword patterns, (2) Crash/error patterns from Sentry, (3) Feature satisfaction signals, (4) Confusion/friction indicators, (5) NPS and rating trends

#### `/marketing` SKILL.md
**Adapters:** firecrawl → context.json, feature-registry.json — pull on /marketing competitive or /marketing aso
**Research dimensions:** (1) ASO keyword performance, (2) Competitor positioning and messaging, (3) Channel performance data, (4) Content patterns that drive engagement, (5) Campaign attribution and ROAS

#### `/research` SKILL.md
**Adapters:** firecrawl → context.json — pull on /research wide or /research competitive
**Research dimensions:** (1) Market landscape and size, (2) Competitor feature matrices, (3) UX pattern libraries (Mobbin, Pttrns), (4) Academic/industry sources, (5) Technology trends affecting the domain

#### `/ops` SKILL.md
**Adapters:** sentry → health-status.json — pull on /ops health or /ops incident
**Research dimensions:** (1) Service health across all infrastructure, (2) Incident patterns and MTTR, (3) Cost trends per service, (4) Alert threshold calibration, (5) CI pipeline reliability

#### `/release` SKILL.md
**Adapters:** app-store-connect → feature-registry.json — pull on /release checklist or /release submit
**Research dimensions:** (1) Version history and changelog patterns, (2) Submission requirements and guidelines, (3) TestFlight feedback from prior builds, (4) Regression checklist from change-log.json, (5) Store metadata and screenshot status

#### `/pm-workflow` SKILL.md
**Adapters:** All adapters (hub receives all validation gate notifications)
**Research dimensions:** (1) Phase transition patterns from state.json history, (2) Work type selection heuristics, (3) Task decomposition patterns from prior features, (4) Priority scoring from task-queue.json, (5) Change broadcast and notification rules

---

## Work Stream 3: Validation Gate in skill-routing.json

Add a `validation_gate` section to `.claude/shared/skill-routing.json`:

```json
{
  "validation_gate": {
    "thresholds": {
      "green": 0.95,
      "orange": 0.90
    },
    "notification_targets": {
      "green": ["receiving_skill", "pm-workflow"],
      "orange": ["receiving_skill", "pm-workflow"],
      "red": ["receiving_skill", "pm-workflow", "user"]
    },
    "log_target": ".claude/shared/change-log.json",
    "scoring": {
      "numeric_tolerance": 0.05,
      "new_field_fills_gap": "always_consistent",
      "measured_supersedes_estimated": "always_consistent",
      "two_measured_disagree": "conflict"
    },
    "enforcement": "automatic_scoring_manual_resolution"
  }
}
```

---

## Out of Scope

- Actually connecting MCP servers (needs API keys — Phase B)
- Running skills against the seeded cache (validation happens when skills are next invoked)
- Figma infographic for the case study
- AI Engine v2 adaptation

## Files Created/Modified Summary

**Created (5 L1 cache entries):**
- `.claude/cache/ux/v2-screen-audit-playbook.json`
- `.claude/cache/design/token-compliance-checker.json`
- `.claude/cache/analytics/screen-prefix-convention.json`
- `.claude/cache/dev/v2-implementation-recipe.json`
- `.claude/cache/qa/analytics-test-patterns.json`

**Modified (5 L2/L3 cache entries):**
- `.claude/cache/_shared/ux-foundations-map.json`
- `.claude/cache/_shared/screen-refactor-playbook.json`
- `.claude/cache/_shared/design-system-decisions.json`
- `.claude/cache/_project/architecture-patterns.json`
- `.claude/cache/_project/anti-patterns.json`

**Modified (11 SKILL.md files):**
- `.claude/skills/{ux,design,analytics,dev,qa,cx,marketing,research,ops,release,pm-workflow}/SKILL.md`

**Modified (1 shared config):**
- `.claude/shared/skill-routing.json`
