# FitMe Cross-Layer Test Coverage Master Plan — 2026-05-13

> **Status:** CURRENT · Opened 2026-05-13 as a sub-doc of [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)
> **Scope:** Test discipline across every system layer — iOS, web (fitme-story), framework (Python gates), backend (Supabase/CloudKit/auth), AI, analytics. Forward-looking calibration of where tests exist, where they've drifted, and where they're missing.
> **Purpose:** Answer the question the infra master plan does NOT answer: "are all current tests in spec across all layers?" The infra plan covers Theme G — Test discipline for the framework layer only (F14–F18 + F19/F20 from analytics-observability). This sub-doc widens the scope to iOS + web + backend + AI + analytics and proposes a per-layer T-series candidate docket.
> **Authority:** Same scoping conventions as the infra master plan. T-candidates here feed the 2026-05-21 prioritization pass (T29) and may promote into v8.0/v8.1 alongside F-candidates.
>
> **⏱️ Refreshed 2026-06-07:** **T6 web PR JS test gate SHIPPED** (fitme-story #137, RICE 200 — the plan's highest-leverage item). **F14 + F15 dispatch-test coverage SHIPPED** (2026-05-22/23; combined write-time 8/16 + cycle-time 2/3). **F16 try-repo harness SHIPPED** v7.9.1 (3rd test layer; advisory→enforced 2026-06-18). **R9 Track B coverage telemetry SHIPPED** v7.9.1 (#626) — 30-day data read **2026-07-04** feeds the **T1 `GATE_TEST_MISSING` meta-gate** (RICE 53.3, gated on F14 Phase E = **2026-08-22**). New platform-parity surface: **t14 `platforms_tested`** field + advisory gate (2026-06-07) records which platforms each feature's tests exercised (per-platform coverage % = T15+, gated on R9 30-day data). **C3 (Sentry reachability test) deferred to App Store launch.** Quarterly cross-layer audit B4 = **2026-08-13**.

---

## 0. TL;DR

A 4-agent audit (3 internal inventories + 1 external comparison study) ran 2026-05-13 against all six system layers. Headline findings:

1. **Framework layer is best-tested but has a known keying-drift blocker.** 133 Python test methods / 13 files. v7.8.5 cache_hits keying patch (§2.4 of infra plan) MUST ship before 2026-05-21 promotion. Per-gate dispatch tests still missing on 4 gates (F14); 5 zero-coverage gates (F15). Already on the infra plan.
2. **iOS layer is partially in spec.** 549 methods / 56 files. Core services covered; Sentry has zero tests; CloudKit/Supabase sync at contract-only by design; entire View layer (~130 files) untested except via thin XCUITest (10 methods, 2 quarantined). UI test thinness is documented as intentional but no compensating snapshot-test discipline exists.
3. **fitme-story (web) is severely under-spec'd.** 122 test cases / 17 files. 119 React components: zero tests. 27 routes: zero E2E. WebAuthn route handlers: zero tests (only library-level round-trip). CI does not run JS tests on PR — only Python gates. **Out of spec for a production-facing public site + operator control room.**
4. **AI layer is the single biggest test debt.** 75 methods total; orchestration tested but cohort inference (3 tests), prompt assembly, ranking algorithm, and LLM behavioral regression have NO golden-set evals. `phase2bis-prompt-set.json` exists with no harness reading it.
5. **Backend layer has a critical hole.** `SignInService.swift` (passkey/WebAuthn) has ZERO direct tests despite being on CLAUDE.md's high-risk list. Multi-device reconciliation, encryption-key rotation, sync conflict cascades all untested.
6. **Analytics layer is taxonomy-strong, runtime-weak.** 81% event coverage by event count (93/114) but parameter-combination coverage ~40%. 4 wholly unfired events; 21 untested variants. No runtime check that emitted events match the CSV.
7. **External comparison surfaced 7 patterns worth borrowing** — golden-set AI evals (highest leverage), Swift snapshot testing, Supabase↔iOS schema-diff gate, platform-parity state.json field, `last_fired_at` index extension, orphan-test scanner, gate stage/tier annotation.

**Bottom line:** the infra master plan's Theme G (F14–F20) is necessary but NOT sufficient. It hardens the framework layer's test discipline while leaving five other layers under-spec'd. This sub-doc proposes **T-series candidates (T1–T10) covering the non-framework layers,** to be ranked alongside F-candidates at the 2026-05-21 prioritization pass.

---

## 1. Scope + Relationship to Infra Master Plan

### 1.1 What this plan covers

| Layer | Test surface | Owned by this plan? |
|---|---|---|
| **Framework (Python)** | `scripts/tests/` — 34 gates + 5 advisory + integrity-check cycle codes | Covered by infra plan F14–F18; this plan widens with T1 (per-gate dispatch test enforcement gate) |
| **iOS (Swift)** | `FitTrackerTests/`, `FitTrackerUITests/` — 549 unit + 10 UI methods | **Owned here** (T2–T5) |
| **Web (fitme-story)** | `node:test` — 17 files, 122 cases; zero React + zero E2E | **Owned here** (T6–T8) |
| **Backend** | Swift services + Supabase Edge Functions + CloudKit sync | **Owned here** (T9) |
| **AI** | AIOrchestrator, cohort prior, prompt assembly, LLM behavior | **Owned here** (T10 — golden-set evals) |
| **Analytics** | Event firing, taxonomy compliance, parameter coverage | Covered partially by analytics-observability sub-doc (F19/F20); T11 here adds runtime emission audit |

### 1.2 Relationship to v7.9 / v8.x docket

T-candidates compete with F-candidates at the 2026-05-21 ranking pass (Phase 9 of `framework-v7-8-branch-isolation`). The top-per-theme rule (infra plan §3.3) treats this as a new theme: **Theme H — Application-layer test coverage.** Theme H items walk the same calibration protocol (§3.5 of infra plan) as Theme G items: Phase A spec → B advisory + measure → C calibration → D promote → E validate.

### 1.3 What this plan does NOT cover

- **Performance / load testing** — separate concern; tracked in `docs/product/backlog.md`
- **Security penetration testing** — quarterly process; tracked via `/security-review` skill
- **Manual QA / TestFlight** — handled by `/qa` skill + `/release` skill
- **Accessibility audits** — handled by `/design accessibility`

---

## 2. Per-Layer Inventory (as of 2026-05-13)

### 2.1 Framework (Python) — 161 methods / 17 files (as of 2026-05-23)

**Updated 2026-05-24 to reflect F14 + F15 ship via `framework-f14-f15-dispatch-test-coverage` — PR #451 squash `86084c4` (merged 2026-05-23T04:55:46Z) + backfill PR #452 (`3686f98`) + closure PR #455 (`98ca1ad7`). 161/161 pytest pass; combined dispatch-test coverage 1/19 → 10/19 = 53% (write-time 1/16→8/16; cycle-time 0/3→2/3 = 67%). Closes D-PLAN-5 (was: "PR pending operator").** Baseline at plan authorship (2026-05-13) was 133 methods / 13 files; F14/F15 added the `conftest.py` shared fixtures, 9 new dispatch tests, and 3 new test files. Highlights:

| Gate / Script | Test File | Status |
|---|---|---|
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` | test_gate_coverage.py + **`test_check_state_schema.py::test_main_dispatch_*` (NEW F14)** | Keying drift closed at v7.8.5 + dispatch test added F14 |
| `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS` | test_check_state_schema.py + **`test_main_dispatch_*` (NEW F14)** | All 4 F14 gates now have dispatch tests |
| `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING` | **`test_check_state_schema.py::test_main_dispatch_*` (NEW F15)** | Was ZERO COVERAGE; now covered |
| `BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT` | **`test_integrity_check_dispatch.py` (NEW F15)** | Was ZERO COVERAGE; cycle-time advisory now covered |
| `PR_CACHE_STALE` (v7.8.4) | **`test_ensure_pr_cache_fresh.py` (NEW F15)** | Was ZERO COVERAGE; now covered via `os.utime`-based age simulation |
| `integrity-check.py` (16 cycle-time codes) | partial via test_gate_coverage.py + 2 dispatch tests | 2 codes now have dedicated dispatch tests; 14 still lack dedicated tests |
| `refresh-pr-cache.py`, `append-feature-log.py`, `ui-audit.py`, `scaffold-figma-mapping.py`, 10+ HADF scripts | — | **ZERO COVERAGE** (out of F14/F15 scope) |

**Coverage delta (2026-05-13 → 2026-05-23):**

| Surface | Pre-F14/F15 | Post-F14/F15 | Δ |
|---|---|---|---|
| Write-time gates with `test_main_dispatch_*` | 1/16 = 6% | **8/16 = 50%** | +44 pp |
| Cycle-time advisory gates with `test_main_dispatch_*` | 0/3 = 0% | **2/3 = 67%** | +67 pp |
| **Combined dispatch-test coverage (19 total)** | **1/19 = 5%** | **10/19 = 53%** | **+48 pp** |

**Judgment (updated 2026-05-23):** Per-gate dispatch test discipline now ≥50% on enforced write-time gates; the structural drift class (PR #317's silent-pass shape) is preventatively closed for the 9 covered gates. Remaining work: 6 enforced write-time gates without dispatch tests (sequential follow-on; see backlog), 1 cycle-time advisory without dispatch test (`FEATURE_CLOSURE_COMPLETENESS` mirror), and the T1 meta-gate (`GATE_TEST_MISSING`) which prevents the NEXT new gate from shipping without its dispatch test. T1 unblocks at F14 Phase E (T+90d = 2026-08-22). v7.8.5 cache_hits keying patch shipped at v7.8.5; no further blocker on framework layer ahead of v7.9.1.

### 2.2 iOS (Swift) — 549 methods / 56 files

| Production surface | Test file | Methods | Status |
|---|---|---|---|
| DomainModels.swift | EncryptionServiceTests + ImportTests (indirect) | indirect | Coverage via callers, not direct |
| EncryptionService.swift | EncryptionServiceTests | 10 | Encrypt/decrypt only; no key-rotation |
| SupabaseSyncService.swift | SupabaseSyncServiceTests | 6 | Basic merge; no chaos tests |
| CloudKitSyncService.swift | CloudKitSyncServiceTests | 6 | **Contract-only by design (v7.x deferral)** |
| **SignInService.swift (passkey/WebAuthn)** | — | **0** | **ZERO DIRECT TESTS** despite high-risk classification |
| AuthManager.swift | AuthManagerTests + AuthPolishV2Tests | 8 + 15 | Reasonable |
| AIOrchestrator.swift | AIOrchestratorTests + FitTrackerCoreTests | 14 + 33 | Dispatch tested; algorithm untested (see §2.5) |
| **Sentry integration** | — | **0** | **ZERO TESTS, NO PROD REFERENCES** — CLAUDE.md silent |
| Push Notifications v2 | NotificationTests + NotificationServiceTests + PushNotificationsReachabilityTests | 21 | Strong (UI-016 reachability lesson encoded) |
| Import-training-plan (Phase 1) | ImportTests + ImportPersistenceAndAnalyticsTests + 3 more | 53 | Strong |
| Home v2 | HomeAnalyticsTests + HomeRecommendationProviderTests + HomeReadinessUITests | 22 + 1 quarantined | Mixed |
| 5 v2 screens (Stats/Settings/Nutrition/Training/Readiness) | 5 analytics files + ReadinessEngineTests + ReadinessAlertTriggerTests | analytics-only + 27 | View layer untested |
| **DesignSystem/ (10 files)** | — | **0** | **ZERO COVERAGE** |
| **Code Connect (.figma.swift × 5)** | — | **0** | Not XCTest-testable; drift undetectable |
| **FitTracker/Views/Auth/ (9 files)** | — | **0 unit / 1–5 UI** | Heavy reliance on thin UITests |
| **FitTracker/Views/AI/ (4 files)** | — | **0** | Behavior via AIAnalyticsTests only |

**XCUITest:** 7 files / 10 methods total. `HomeReadinessUITests` + `OnboardingUITests` quarantined via `XCTSkipIf` (parallel-clone hang — resolved at PR #225 per memory, but quarantines never removed). `MealLogUITests` has a label-drift skip.

**Judgment:** core services partially current; **3 material gaps** — (a) Sentry has zero tests, (b) two sync services at contract-only with no closure plan, (c) ~130-file View layer untested. CLAUDE.md documents UI test thinness as intentional, but no compensating snapshot-test discipline exists.

### 2.3 Web (fitme-story) — 122 cases / 17 files / `node:test` runner

| Surface | Coverage |
|---|---|
| `/control-room/framework` lib (builder.ts, reconcile.ts) | Partial — builder/reconcile tested; **commands.ts + github.ts untested** |
| `/control-room/analytics` lib | 18 tests — full |
| WebAuthn library (`webauthn-server.ts`) | 3 tests (round-trip happy path) |
| **WebAuthn route handlers (`/api/auth/{authenticate,register,verify,options,devices,revoke}`)** | **0** |
| Cross-repo sync (`sync-from-fittracker2.ts`, `gate-coverage-aggregator.ts`) | 15 — strong |
| Figma drift detection | 6 — strong |
| Case-study MDX (54 files + frontmatter validator) | 4 — minimal; **no schema-validator tests** |
| Parsers (state, backlog, unified, metrics, prd) — **5 untested** | tasks.ts (26) + roadmap.ts (2) only |
| **React components — 119 .tsx files** | **0** |
| **Public site routes — 27 page.tsx/page.mdx** | **0 E2E / 0 snapshot** |

**CI Integration:** `integrity.yml` runs Python gates only. **No JS test runner in CI on PR.** `figma-drift-weekly.yml` runs the drift script weekly. Reverse-sync workflow has no test step.

**Judgment:** **Out of spec.** A production-facing public site + operator control room with zero automated validation of routes / components / auth ceremonies. Coverage is episodic (lib layers strong; surfaces absent).

### 2.4 Backend — 248 methods across 22 Swift test files (Edge Functions unaudited)

| Service | Test file | Methods | Status |
|---|---|---|---|
| SupabaseSyncService | SupabaseSyncServiceTests | 6 | Basic merge; no churn/cascade |
| CloudKitSyncService | CloudKitSyncServiceTests | 6 | Contract-only (v7.x deferral) |
| AuthManager | AuthManagerTests | 8 | Passkey + email |
| **SignInService** | — | **0** | **ZERO COVERAGE** |
| EncryptionService | EncryptionServiceTests | 10 | Encrypt/decrypt; no key-rotation |
| KeychainStorage | KeychainHelperTests | 7 | CRUD + GDPR delete |
| GDPR / AccountDeletion | AccountDeletionServiceTests | 7 | Deletion only |
| 3-way merge (Supabase) | SupabaseTests/SyncMergeTests | 5 | Some edge cases |
| OAuth/session | SupabaseTests/UserSessionMappingTests | — | Some coverage |
| **DataExportService, ConsentManager, FoodSearchService** | — | **0** | **ZERO COVERAGE** |
| **Supabase Edge Functions (if any)** | not audited | — | Out-of-scope this pass |

**Judgment:** happy-path coverage on sync/auth/encryption is reasonable. **SignInService zero-tested** despite high-risk classification. No chaos/adversarial tests. Multi-device reconciliation untested. Encryption-key rotation untested. Edge Functions (if present) need a separate audit.

### 2.5 AI — 75 methods / 5 files; zero LLM behavioral evals

| Component | Test file | Methods | Status |
|---|---|---|---|
| AIOrchestrator | AIOrchestratorTests | 14 | Dispatch, mode selection |
| AIAdapter (HK/training/nutrition input) | AIAdapterTests | 11 | Input shaping |
| **CohortPriorClient** | CohortPriorClientTests | **3** | **MINIMAL** for critical inference path |
| HomeRecommendationProvider | HomeRecommendationProviderTests | 11 | Ranking + UI state |
| ValidatedRecommendation | ValidatedRecommendationTests | 20 | Validation rules |
| AI Analytics | AIAnalyticsTests | 16 | Event attribution |
| **Prompt assembly, context truncation, Bayesian inference** | — | **0** | **ZERO COVERAGE** |
| **LLM behavioral regression (golden-set)** | — | **0** | `phase2bis-prompt-set.json` exists with no harness |

**Judgment:** **Weakest layer.** Orchestration works; the model/algorithm/prompt layer has zero behavioral regression coverage. No golden-set evals. Cohort prior — the most-bayes-driven inference path — has 3 tests.

### 2.6 Analytics — 147 methods / 11 files

| Dimension | Coverage |
|---|---|
| Event firing (count) | 93/114 = **81%** |
| Unfired events | 4 (`nutrition_hydration_updated`, `nutrition_date_changed`, `nutrition_empty_state_shown`, `onboarding_skipped`) |
| Untested parameter variants | 21 (e.g., `training_exercise_started` × all `muscle_group` values) |
| Parameter-combination coverage | **~40%** |
| Screen-prefix-rule compliance | `AnalyticsEventNamingTests.swift` (5 tests) |
| Runtime emission audit (events fired in app match CSV) | **NONE** |

**Judgment:** **Taxonomy-strong, runtime-weak.** CSV-driven taxonomy is well-curated; enforcement is unit-test only. F19 (`CSV_TAXONOMY_DRIFT`) + F20 (`GA4_MCP_DISCONNECTED`) from analytics-observability sub-doc help; this plan adds T11 (runtime emission audit).

---

## 3. External Comparison — Top 7 Patterns Worth Borrowing

Full agent report cited 10 systems; synthesis below. Each pattern is mapped to the layer it strengthens + an effort estimate.

| # | Pattern | Source | Targets layer | Effort | Cadence |
|---|---|---|---|---|---|
| **P1** | **Golden-set + random-sweep LLM evals** ([promptfoo](https://github.com/promptfoo/promptfoo) + [Anthropic demystifying-evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)) | LLM-eval frameworks | AI | M (1–2d) | Weekly drift + PR gate on golden |
| **P2** | **Swift snapshot testing** ([uber/ios-snapshot-test-case](https://github.com/uber/ios-snapshot-test-case), [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)) | Airbnb/Uber/Lyft pattern | iOS View layer | M-L (3–5d initial, then per-feature) | PR gate |
| **P3** | **Schema-diff gate** ([oasdiff](https://www.oasdiff.com/) pattern adapted to Supabase↔iOS) | Stripe/GitHub API discipline | Backend ↔ iOS | S (4–8h) | pre-commit + nightly |
| **P4** | **Platform-parity state.json field** (`platforms_tested: {ios, web, backend, ai}`) | Linear/Lyft cross-platform pattern | Framework + cross-cutting | XS (1–2h) | pre-commit (extends FEATURE_CLOSURE_COMPLETENESS) |
| **P5** | **`last_fired_at` + `last_failed_at` index per gate** ([AWS Config DescribeConfigRuleEvaluationStatus](https://docs.aws.amazon.com/config/latest/APIReference/API_ConfigRuleEvaluationStatus.html), [driftctl](https://github.com/snyk/driftctl)) | Gate-rich infra tools | Framework (extends F17) | S (4h) | Weekly + on-demand |
| **P6** | **Orphan-test scanner** ([ArchDrift](https://www.archdrift.com/), [shipmonk dead-code-detector](https://github.com/shipmonk-rnd/dead-code-detector)) | Drift-detection ecosystem | iOS + Web | S (4–8h) | Weekly cron, advisory |
| **P7** | **Test-type stratification + `stages:` declaration** ([pre-commit.com](https://pre-commit.com/) + [Next.js core testing](https://github.com/vercel/next.js/blob/canary/contributing/core/testing.md)) | Pre-commit + Next.js patterns | Framework metadata | XS-S (2–4h) | One-time schema bump |

**Overkill for this context** (NOT borrowed): Pact bi-directional broker; Next.js isolated-installation-per-test; 30K-snapshot scale (Airbnb); Inspect AI as second eval framework; Muter for Swift mutation testing (deferred — low value-per-hour at current size).

---

## 4. T-Series Candidate Docket (Theme H — Application-Layer Test Coverage)

Eleven candidates surfaced. RICE-est uses the same convention as infra plan §3.1. Effort is wall-time for a focused sub-agent dispatch (XS=≤2h, S=≤8h, M=≤2d, L=≤5d).

| ID | Layer | Item | Pattern | RICE-est | Notes |
|---|---|---|---|---|---|
| **T1** | Framework metadata | **Per-gate dispatch test enforcement gate** — extend F14 with a meta-gate `GATE_TEST_MISSING` that fails CI when a new gate function in `scripts/check-state-schema.py` (or `integrity-check.py` / `check-case-study-preflight.py` / `ensure-pr-cache-fresh.py`) ships without a paired `test_main_dispatch_*` in `scripts/tests/`. Filename-pairing contract from Semgrep. Inventory source: `scripts/tests/conftest.py` 9 violation recipes + the test files added by F14/F15. | P7 partial | H (R=10 I=2 C=80% E=0.3w → 53.3) | Closes the drift class that produced the cache_hits keying bug. F14 shipped 2026-05-22→05-23 → Phase E exit ≈ 2026-08-22 (T+90d). Ticket opened in `docs/product/backlog.md` Framework v7.8.5+v7.9+ track on 2026-05-23. |
| **T2** ⏸ **DEFERRED to App Store launch** | iOS | **Sentry integration test pass** — wire Sentry SDK reachability tests (mirror of `PushNotificationsReachabilityTests` for `crash_free_rate`). Closes the CLAUDE.md silent-pass that Sentry has zero tests + zero prod references. **Deferred 2026-05-21 alongside the parent Sentry integration pause:** iOS app is pre-launch (TestFlight beta only — not real-user signal per `feedback-ios-app-not-in-production` memory). No value landing a reachability test against an inactive service. Resume trigger = App Store submission. Cadence ledger §C3 closed 2026-05-23 with this deferral. | — | H (R=10 I=3 C=100% E=0.3w → 80.0) | Pre-launch crash gate (post-launch). High blast radius if Sentry actually disconnected. |
| **T3** | iOS | **SignInService passkey/WebAuthn unit tests** — 8–12 tests covering credential registration, assertion, fallback to email, error states. Closes the highest-risk zero-coverage backend service. | — | H (R=10 I=3 C=100% E=0.5w → 48.0) | Mirrors `AuthManagerTests` scope. |
| **T4** | iOS | **Swift snapshot testing on v2 views** — add `pointfreeco/swift-snapshot-testing` SPM dep; baseline 6 v2 screens (Home/Stats/Settings/Nutrition/Training/Readiness) + 4 auth views; snapshot diff as PR gate. Covers ~130-file View layer drift. | P2 | M (R=8 I=3 C=60% E=0.5w → 28.8 initial; grows per-feature) | Replaces deferred XCUITest expansion. Single-shot deterministic — no parallel-clone hang. |
| **T5** | iOS | **Mock-protocol drift detection** — wrap `MockKeychainStorage`, `MockSupabaseClient`, `StubAIEngineClient`, `CountingAIEngineClient` in a shared `MockValidation.swift` that fails build if protocol surface drifts beyond mock conformance. Lightweight. | — | M (R=6 I=2 C=100% E=0.3w → 40.0) | Closes the "Last audit touch: 2026-04-18" concern. |
| **T6** | Web | **fitme-story PR test gate** — add `npm test` step to `pr-integrity-check.yml` (or new `web-tests.yml`) so the 122 existing tests gate every PR. Currently zero JS tests run on PR. | — | H (R=10 I=2 C=100% E=0.1w → 200.0) | **Highest RICE.** Single-line CI config addition. Mandatory before any T7/T8. |
| **T7** | Web | **Critical-route smoke tests** — add Playwright (or `next test`) smoke tests on 5 critical routes: `/`, `/case-studies`, `/control-room/framework`, `/control-room/analytics`, `/api/auth/authenticate/options`. Closes the "27 routes, zero E2E" gap. | — | H (R=8 I=3 C=80% E=0.5w → 38.4) | Foundation for further E2E expansion. |
| **T8** | Web | **WebAuthn route handler tests** — test the 7 `/api/auth/*` route handlers (currently only library-level `round-trip.test.ts` exists). Mock attestation/assertion payloads. Closes pre-cutover risk before basic-auth flip. | — | H (R=8 I=3 C=80% E=0.4w → 48.0) | Operator-blocking if cutover hits a regression. |
| **T9** | Backend | **Backend chaos/edge tests** — multi-device sync reconciliation, encryption-key rotation, GDPR cascade across CloudKit+Supabase, network-churn auth recovery. 8–15 new tests across existing test files. | — | M (R=6 I=2 C=60% E=0.7w → 10.3) | Adversarial coverage; lower R until a user-reported incident raises it. |
| ~~**T10**~~ | AI | ~~**Golden-set LLM eval harness**~~ — **SHIPPED 2026-06-10** (pulled forward from v8.1 once Phase 2-bis closed 2026-06-05). **Scoping reframe:** the FitMe AI is *deterministic* (`InsightService` rule engine), not generative — the LLM path is gated behind an unset `LLM_API_KEY`/DPA, so a deterministic golden set is *better* (zero flake, no key, hard PR gate). Shipped `ai-engine/tests/golden/insight_cases.jsonl` (24 cases, all 4 segments + confidence + escalation + edges) + `tests/test_golden_insights.py` + a live-LLM scaffold that skips when `LLM_API_KEY` unset. 60 passed / 1 skipped; negative-control proven. Feature `ai-golden-set-evals`. | P1 | H (R=10 I=3 C=60% E=1.0w → 18.0) | **Was the biggest layer gap — now closed.** |
| **T11** | Analytics | **Runtime emission audit** — instrument a test-mode flag that captures every emitted event during integration-test runs; diff against `docs/product/analytics-taxonomy.csv` at suite-end. Catches unfired-by-test events automatically. Complements F19 (CSV drift). | — | M (R=8 I=2 C=80% E=0.4w → 32.0) | Closes the "4 unfired + 21 untested variants" gap structurally. |

**Cross-cutting (lower priority):**

| ID | Item | RICE-est |
|---|---|---|
| **T12** | Supabase↔iOS schema-diff gate (P3) — pre-commit hook diffs Supabase migration files against `DomainModels.swift` matching fields | M (R=6 I=2 C=60% E=0.4w → 18.0) |
| **T13** | `last_fired_at` + `last_failed_at` index extension to ALL gates (P5; extends F17) | S (R=8 I=2 C=100% E=0.2w → 80.0) |
| **T14** | Platform-parity state.json field (P4) — `platforms_tested: {ios, web, backend, ai}` extends FEATURE_CLOSURE_COMPLETENESS | XS (R=8 I=2 C=100% E=0.1w → 160.0) |
| **T15** | Orphan-test weekly cron (P6) — advisory scanner asserts every `*Tests.swift` references ≥1 production symbol (and vice versa) | S (R=6 I=1 C=80% E=0.3w → 16.0) |
| **T16** | Test-tier / stage annotation on all 34 gates (P7) — adds `stage:` + `tier:` to gate metadata | XS (R=6 I=1 C=100% E=0.2w → 30.0) |

**Total: 16 T-candidates (T1–T16).**

### 4.1 Layer distribution

| Layer | T-candidates | RICE-sum |
|---|---|---|
| Framework metadata | T1, T13, T14, T16 | 323.3 |
| iOS | T2, T3, T4, T5 | 196.8 |
| Web | T6, T7, T8 | 286.4 |
| Backend | T9, T12 | 28.3 |
| AI | T10 | 18.0 |
| Analytics | T11 | 32.0 |
| Cross-cutting | T15 | 16.0 |

### 4.2 Top-5 by RICE

1. **T6** (Web PR test gate) — RICE 200.0 — single-line CI config; should ship as v7.9.1 ride-along.
2. **T14** (platform-parity state.json field) — RICE 160.0 — extends an existing enforced gate; ~1h effort.
3. **T2** (Sentry integration test) — RICE 80.0 — closes a silent zero-coverage on a high-risk surface.
4. **T13** (`last_fired_at` extension to all gates) — RICE 80.0 — natural extension of F17 once F17 ships.
5. **T1** (per-gate dispatch test enforcement gate) — RICE 53.3 — closes the drift class behind cache_hits keying.

---

## 5. Sequencing — Forward Plan

Calibration protocol (§3.5 of infra plan) applies. Each T-candidate walks Phases A → B → C → D → E (22 days minimum per layer; T14 + T16 are XS metadata changes that may skip B–C).

### 5.1 Earliest-eligible windows

| Window | Eligible | Why |
|---|---|---|
| **v7.9.1 ride-along (~2026-06-04 → 2026-06-11)** | T6, T14, T16 | XS/S effort; non-gate-additive (T6, T16) or extends existing enforced gate (T14); no calibration window needed |
| **v8.0 docket (decided 2026-05-21, ship target ~2026-07-31)** | T1, T2, T3, T6 (if not in v7.9.1), T8, T11, T13 | Top-RICE items; walk full A–E calibration |
| **v8.1 docket (target ~2026-09)** | T4, T5, T7, T10 | Medium effort; T10 (AI golden-set) deferred to allow Phase 2-bis prompt-set to stabilize |
| **v8.2+ (target Q4 2026)** | T9, T12, T15 | Lower-RICE; ship when telemetry signals demand |

### 5.2 Dependency graph

```
T1 (per-gate dispatch enforcement)  ← depends on F14 in Phase E
T4 (Swift snapshot testing)         ← independent (new SPM dep)
T6 (Web PR test gate)               ← independent (CI config only)
T7 (Web E2E smoke)                  ← depends on T6 (so the gate exists)
T8 (WebAuthn route tests)           ← depends on T6
T10 (AI golden-set)                 ← depends on Phase 2-bis sub-experiments closing
                                       (~2026-06-07) so golden-set has stable prompts
T11 (runtime emission audit)        ← depends on F19 (analytics CSV drift) in Phase B
T13 (last_fired_at extension)       ← depends on F17 in Phase E
T14 (platform-parity field)         ← depends on FEATURE_CLOSURE_COMPLETENESS enforced
                                       (= v7.9 promotion 2026-05-21)
```

### 5.3 Layer stacking rule applied

§3.5.2 of infra plan: **no new layer built on top of a layer that hasn't reached Phase E.** Concrete applications:

- T1 cannot ship until F14 reaches Phase E (~2026-07-25 if F14 ships at v8.0 start).
- T13 cannot ship until F17 reaches Phase E (~2026-07-25 at earliest).
- T11 cannot ship until F19 (analytics CSV drift gate) reaches Phase B with ≥7d telemetry.
- T14 can ship the same day FEATURE_CLOSURE_COMPLETENESS is promoted to enforced (2026-05-21 if v7.9 promotion succeeds), as it's a field extension of an already-Phase-E gate.

---

## 6. Calibration & Cadence

### 6.1 Per-T-candidate calibration

Same 5-phase protocol as F-candidates. Specific notes per layer:

- **iOS T-candidates (T2–T5):** Phase B telemetry comes from `xcodebuild test` log parsing — no gate-coverage.jsonl equivalent. Manual operator review at T+7d.
- **Web T-candidates (T6–T8):** Phase B telemetry comes from GitHub Actions run summaries. Failure ratio < 5% at T+7d to advance.
- **AI T-candidate (T10):** Phase B = weekly cron of golden-set; failure threshold is "pass rate ≥ baseline" (calibrated during Phase A).
- **Backend T-candidates (T9, T12):** Phase B = include in nightly integration-test sweep; Phase C exit = 14 days of green.

### 6.2 Quarterly cross-layer test-discipline audit

In addition to the §3.5.3 Data Freshness Audit on framework gates, propose a parallel quarterly audit for application-layer tests:

- **Initial run:** 2026-08-13 (T+90d).
- **Recurring:** 2026-11-13, 2027-02-13, 2027-05-13.
- **Scope:** For each layer (iOS / web / backend / AI / analytics), assert: (a) test count not declining, (b) production-symbol coverage ≥ prior quarter, (c) no new "zero-coverage" production directories, (d) staleness markers (TODO / FIXME / XCTSkip / .skip / .only) trend.

Output: `docs/process/cross-layer-test-audit-{date}.md` quarterly snapshot + advisory PR if regression detected.

---

## 7. Risk Register (sub-doc-specific)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **T6 lands but reveals 30+ failing existing JS tests (silent rot)** | Medium | Medium | Phase A: pre-flight local `npm test` audit. If failures exist, fix-first as PR before gate flips enforced. |
| **T4 snapshot baseline captures buggy current UI as canonical** | High | Medium | Phase A: review every initial snapshot with operator + spec before merging baseline. Pair with `/ux pre-merge-review`. |
| **T10 golden-set goes stale as AIOrchestrator evolves** | High | Medium | Quarterly audit (§6.2) includes golden-set refresh as a sub-item. Treat golden-set authorship as recurring, not one-shot. |
| **T2 Sentry tests pass against a stub but production Sentry is misconfigured** | Medium | High | Pair T2 with manual smoke run against staging Sentry project; codify in `runtime-smoke-gates.md` profile. |
| **T9 backend chaos tests are flaky on CI** | High | Low | Run as nightly advisory before promoting to PR gate. |
| **Effort estimate slippage on T4 / T7 / T10 (M-L items)** | Medium | Medium | Each ships incrementally — baseline first, then per-feature additions in subsequent PRs. |

---

## 8. Open Questions

1. **Should T6 (Web PR test gate) ship at v7.8.5 rather than v7.9.1?** RICE 200.0; effort ~1h. Argument for: closes a silent zero-CI-coverage gap that's existed since fitme-story spun up. Argument against: v7.8.5 is scoped to cache_hits keying only. Decide at 2026-05-13 morning.
2. **Snapshot test runner choice for T4** — `pointfreeco/swift-snapshot-testing` (canonical) vs `uber/ios-snapshot-test-case` (older, broader iOS app proof). Default recommendation: pointfreeco (active maintenance, SPM-first). Decide at T4 Phase A.
3. **Golden-set authorship for T10** — written by operator manually vs generated from production logs via Mechanism C session-attribution data? Argument for log-derived: zero hallucination risk. Argument against: privacy + production-data-handling concerns. Decide at T10 Phase A.
4. **Should Theme H be a separate framework version bump?** A v8.x where v8.0 = Theme G + H combined vs v8.0 = Theme G only + v8.1 = Theme H. Top-per-theme rule (§3.3 of infra plan) suggests combined; this sub-doc opens the question explicitly.
5. **Edge Functions audit** — Supabase Edge Functions (if any exist) were out-of-scope this pass. Should a follow-up audit run before T9 starts? Decide at T9 Phase A.
6. **Mock library extraction (T5 expansion)** — should mocks live in a separate Swift Package (`FitTrackerMocks`) for cleaner versioning, or remain inline in `FitTrackerTests/`? Decide at T5 Phase A.
7. **Analytics runtime emission audit (T11) — sample rate** — capture every event in test (100%) vs sample (10%)? 100% is simpler; sample is cheaper. Decide at T11 Phase A.

---

## 9. References

### Source documents
- [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) — parent plan; §3.1 Source D + §3.6.4 v8.0 docket
- [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — analytics-observability sub-doc with F19/F20
- [`docs/superpowers/specs/2026-05-08-framework-v7-9-candidates.md`](../superpowers/specs/2026-05-08-framework-v7-9-candidates.md) — F14–F18 spec
- [`docs/case-studies/m-4-xcuitest-infrastructure-case-study.md`](../case-studies/m-4-xcuitest-infrastructure-case-study.md) — XCUITest env-flake history
- [`docs/process/runtime-smoke-gates.md`](../process/runtime-smoke-gates.md) — runtime profile system that T2 hooks into

### External patterns
- [Next.js core testing](https://github.com/vercel/next.js/blob/canary/contributing/core/testing.md) — P7 stratification source
- [AWS Config DescribeConfigRuleEvaluationStatus](https://docs.aws.amazon.com/config/latest/APIReference/API_ConfigRuleEvaluationStatus.html) — P5 source
- [oasdiff](https://www.oasdiff.com/) — P3 source
- [pre-commit.com](https://pre-commit.com/) + [try-repo](https://github.com/pre-commit/pre-commit/issues/850) — P7 + F16 source
- [Semgrep test rules](https://semgrep.dev/docs/writing-rules/testing-rules) — T1 + F15 pairing convention
- [promptfoo](https://github.com/promptfoo/promptfoo) + [Anthropic demystifying-evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — P1 + T10 source
- [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) + [uber/ios-snapshot-test-case](https://github.com/uber/ios-snapshot-test-case) — P2 + T4 source
- [Maestro XCTest best practices](https://maestro.dev/insights/xctest-best-practices-ios-testing) — XCUITest serialization
- [ArchDrift](https://www.archdrift.com/) + [shipmonk dead-code-detector](https://github.com/shipmonk-rnd/dead-code-detector) — P6 + T15 source

### Live state
- [`.claude/features/framework-v7-8-branch-isolation/state.json`](../../.claude/features/framework-v7-8-branch-isolation/state.json) — T29 prioritization pass (Theme H ranking)
- [`.claude/logs/gate-coverage.jsonl`](../../.claude/logs/gate-coverage.jsonl) — framework gate telemetry input
- `FitTrackerTests/` + `FitTrackerUITests/` — iOS test root
- `fitme-story/scripts/` + `fitme-story/src/lib/` + `fitme-story/src/app/` — web test root

---

## 10. Change Log for This Document

| Date | Change |
|---|---|
| 2026-05-13 | Initial creation. Synthesizes 4-agent audit (iOS / web / framework+backend+AI / external comparison) + proposes T1–T16 candidate docket for Theme H (Application-Layer Test Coverage). Feeds 2026-05-21 prioritization pass. |
