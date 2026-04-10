# `/qa` — Quality Assurance

> **Role in the ecosystem:** The correctness layer. Owns test planning, execution, coverage reporting, regression checks, and security audits.

**Agent-facing prompt:** [`.claude/skills/qa/SKILL.md`](../../.claude/skills/qa/SKILL.md)

---

## What it does

Creates test plans from PRD acceptance criteria, executes test suites, measures coverage, runs regression checks, and performs security audits against the OWASP Mobile Top 10.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/qa plan {feature}` | Generate test plan from PRD | "Create test plan for the onboarding feature" | Phase 5 (Test) |
| `/qa run` | Execute test suite | "Run all tests and report" | Phase 5 (Test) |
| `/qa coverage` | Coverage report by feature | "Which features have test gaps?" | Phase 5 (Test) |
| `/qa regression` | Post-merge regression | "Run regression on main after merge" | Phase 7 (Merge) |
| `/qa security` | OWASP security audit | "Run security audit on the auth module" | Phase 5 (Test) |

## Shared data

**Reads:** `feature-registry.json` (what to test), `metric-status.json` (quality guardrails).

**Writes:** `test-coverage.json` (per-feature coverage), `health-status.json` (quality gate status).

## System Guardrails (must NEVER degrade)

- Crash-free rate > 99.5%
- Cold start < 2s
- Sync success rate > 99%
- CI pass rate > 95%

`/qa` treats any regression against these as a P0 and blocks Phase 5 approval.

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 5 (Test) | `/qa plan` + `/qa run` + `/qa coverage` |
| Phase 5 analytics tests | `/analytics validate` pipes through the same test runner |
| Phase 7 (Merge) | `/qa regression` on main |

## Upstream / Downstream

- Writes coverage consumed by `/dev` and `/release`
- Receives bug dispatches from `/cx` when root cause = functionality
- Feeds quality-gate pass/fail to `/release` before submission

## Standalone usage examples

1. **Test planning:** `/qa plan onboarding` → generates test cases from PRD acceptance criteria with effort estimates
2. **Quick test run:** `/qa run` → executes `make tokens-check` + `xcodebuild build` + `xcodebuild test`
3. **Security check:** `/qa security` → checks encryption (AES-256-GCM), Keychain ACL, JWT handling, PII exposure

## Recent usage

- **37+ analytics tests** written across 3 test files validating GA4 instrumentation for Home v2, Body Composition, and Training v2 features.
- **v2-refactor-checklist Section J** (QA verification gate) completed for both Home v2 and Training v2 refactors.
- **Regression checks** ran on main after each of the 5 feature merges (#61, #63, #65, #67, #74).
- **Test plans** generated from PRD acceptance criteria for all Feature and Enhancement work items.

## Key references

- [`FitTrackerTests/`](../../FitTrackerTests/) — XCTest suite
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — CI pipeline
- [`Makefile`](../../Makefile) — `make verify-local`, `make tokens-check`
- [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — Section J is the QA verification gate

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §9
- [dev.md](dev.md), [analytics.md](analytics.md) — upstream/downstream partners
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/qa/SKILL.md`](../../.claude/skills/qa/SKILL.md)

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| xcode | MCP | Test execution, build results, simulator control, code coverage data |
| codecov | REST | Coverage reports, diff coverage, historical coverage trends per PR |
| axe | MCP (shared with `/ux`) | Automated accessibility testing, WCAG AA violation detection |
| sentry | MCP (shared with `/ops`) | Production error rates, crash-free session tracking, regression signals |

**Adapter config:** `.claude/integrations/xcode/`, `.claude/integrations/codecov/`, `.claude/integrations/axe/`, and `.claude/integrations/sentry/`

All incoming data passes through the **automatic validation gate**:

- GREEN (>= 95%): clean, auto-written
- ORANGE (90-95%): minor discrepancies, written with advisory
- RED (< 90%): blocked, user must resolve

Validation is automatic. Resolution is always manual.

### Learning Cache

**Location:** `.claude/cache/qa/`

Caches: test strategy patterns (which test types caught the most regressions per feature category), coverage baselines (per-module coverage history), regression indicators (symptom patterns that preceded prior regressions).

On start: check cache for matching task signature, load learned patterns.
On complete: extract new patterns, write to L1 cache. Flag cross-skill patterns for L2 promotion.
