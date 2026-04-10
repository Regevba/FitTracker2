---
name: qa
description: "Quality assurance — test planning, execution, coverage reporting, regression checks, security audits. Sub-commands: /qa plan {feature}, /qa run, /qa coverage, /qa regression, /qa security."
---

# Quality Assurance Skill: $ARGUMENTS

You are the QA specialist for FitMe. You create test plans, run test suites, measure coverage, perform regression checks, and audit security.

## Shared Data

**Reads:** `.claude/shared/feature-registry.json` (what to test), `.claude/shared/metric-status.json` (quality guardrails)

**Writes:** `.claude/shared/test-coverage.json` (coverage per feature), `.claude/shared/health-status.json` (quality gate status)

## Sub-commands

### `/qa plan {feature}`

Generate a test plan from PRD acceptance criteria.

1. Read `.claude/features/{feature}/prd.md` for acceptance criteria
2. Read `.claude/features/{feature}/ux-spec.md` for UI states (empty/loading/error/success)
3. Generate test cases covering:
   - Happy path for each user flow
   - Edge cases from PRD
   - Error states
   - Accessibility (if has_ui)
   - Analytics events (if requires_analytics) — event firing, consent gating, taxonomy sync
4. Classify: unit, integration, UI, performance
5. Estimate effort per test

Output: `.claude/features/{feature}/test-plan.md`

### `/qa run`

Execute the test suite.

1. Run `make tokens-check` — design system gate
2. Run `xcodebuild build` — compilation check
3. Run `xcodebuild test` — XCTest suite
4. Parse results, report pass/fail counts
5. Update `.claude/shared/health-status.json`

### `/qa coverage`

Generate coverage report.

1. Count test files and test methods
2. Map tests to features (by file naming convention)
3. Identify untested features/areas
4. Report coverage gaps
5. Update `.claude/shared/test-coverage.json`

### `/qa regression`

Run post-merge regression suite.

1. Switch to main: `git checkout main && git pull`
2. Run full test suite
3. Compare results against previous run
4. Flag any new failures
5. Special attention to analytics regression (all events still fire, consent gating works)

### `/qa security`

Run security audit checklist.

1. **Encryption audit** — verify AES-256-GCM + ChaCha20-Poly1305 in EncryptionService
2. **Key storage audit** — verify Keychain with biometric ACL
3. **Auth audit** — verify JWT handling, session persistence, passkey implementation
4. **Data exposure audit** — scan for PII in logs, analytics events, error messages
5. **OWASP Mobile Top 10** checklist
6. **Dependency audit** — check for known CVEs in SPM/npm dependencies

## System Guardrails (from CLAUDE.md)

These must NEVER degrade:
- Crash-free rate > 99.5%
- Cold start < 2s
- Sync success rate > 99%
- CI pass rate > 95%

## Key References

- `FitTrackerTests/` — existing test files
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — analytics event definitions
- `docs/product/analytics-taxonomy.csv` — event taxonomy
- `CLAUDE.md` — quality guardrails

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| xcode | MCP | Build results, test execution, coverage data from xcresult |
| codecov | REST | Historical coverage trends, diff coverage analysis |
| axe | MCP | Accessibility test results (shared with /ux) |
| sentry | MCP | Crash data for regression testing (shared with /ops) |

**Adapter location:** `.claude/integrations/{axe,sentry,security-audit}/`
**Shared layer writes:** `test-coverage.json`, `health-status.json`

### Validation Gate

All incoming test/quality data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /qa + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /qa + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for a QA task, research:

1. **Test strategy** — what test types suit this feature (unit, analytics, UI state, integration), expected coverage
2. **Existing patterns** — how similar features were tested, XCTest conventions, mock vs real data approaches
3. **Coverage baselines** — current test counts, gap analysis, regression risk areas
4. **Tools & APIs** — Xcode test runner configs, xcresult parsing, Codecov integration, axe a11y scanning
5. **Quality gates** — CI pipeline checks (tokens-check, build, test), system guardrails from CLAUDE.md

Sources checked in order: L1 cache → shared layer (test-coverage.json, health-status.json) → integration adapters (axe, sentry) → codebase (FitTrackerTests/) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/qa/_index.json`. Check for cached test strategy patterns, coverage baselines, regression test outcomes from prior features.

**Phase 4 (Learn):** Extract new patterns (test types per feature category, coverage expectations, regression indicators). Write/update L1 cache.

**Cache location:** `.claude/cache/qa/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
Read `.claude/cache/qa/_index.json`, match `analytics_test_planning`, check L2 for cross-skill test patterns. If hit: generate tests from template at 1.3-2.7x density. If miss: Phase 2.

### Phase 4 — Learn (on skill complete)
Extract new test categories, coverage gaps. Write L1. If applies to /analytics, flag L2.

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| axe | `.claude/integrations/axe/` | design-system.json, test-coverage.json | On `/qa plan` or `/qa security` |
| security-audit | `.claude/integrations/security-audit/` | health-status.json | On `/qa security` |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. Test strategy patterns from L1
2. Coverage gaps from test-coverage.json
3. Analytics test density targets (1.3-2.7x)
4. Regression risk from change-log.json
5. Security checklist (OWASP Mobile Top 10)

**Source priority:** L2 cache > L1 cache > shared layer (test-coverage.json) > axe adapter > security-audit adapter
