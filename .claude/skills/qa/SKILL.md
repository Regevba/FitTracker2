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
