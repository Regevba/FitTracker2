# v8.x Build Docket — Sub-Plan

> **Status:** CURRENT · Extracted 2026-06-15 from [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.1–§3.4 to give the v8.x feature docket its own home (mirrors how `test-coverage-master-plan`, `data-integrity-and-rollback`, and `analytics-master-plan` are separate sub-plans under the infra master plan).
>
> **Parent:** [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) — §3.5 (Calibration Protocol for new layers) and §3.6 (Forward Plan v7.9 → v8.2) **stay in the parent** (heavily cross-referenced); this sub-plan is authoritative for the **candidate docket** (what's queued, what shipped, what's iceboxed).
> **Predecessor ranking artifact:** [`v8-0-docket-ranking-2026-05-13.md`](v8-0-docket-ranking-2026-05-13.md) (frozen T29 prioritization, 2026-05-21).
> **Ready-now execution plan:** [`v8-0-ready-now-workplan-2026-06-15.md`](v8-0-ready-now-workplan-2026-06-15.md).
> **Canonical current state:** [`../FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md).

---

## 0. Reconciled Status (2026-06-26)

Cross-referenced to merged PRs + session memory. Framework is at **v7.10** (shipped 2026-06-10).

**A. Shipped since the docket opened — no longer v8.0 candidates:**

| ID | Item | Shipped | PR(s) |
|---|---|---|---|
| F2 | Phase 0 reality-check sub-step | v7.9.1 | #618 |
| F4 | `FRAMEWORK_VERSION_STALE` advisory gate (stale-version detector on phase-advance) | 2026-06-16 | #740 · advisory→enforced ~2026-06-30 |
| F6 | B_medium tier documented in CLAUDE.md | done | CLAUDE.md "Impact tier labels" § + "Work Item Types" |
| F9 | `make close-feature` closure automation | shipped | #591 + #711 (sub-phase normalize) |
| F14 | Per-gate dispatch tests | 2026-05-22/23 | #451 / #452 / #455 |
| F15 | Zero-coverage gate unit tests | 2026-05-22/23 | (same feature) |
| F16 | try-repo harness | v7.9.1 | #607–#612 · **✅ enforced 2026-06-17** (try-repo-harness → main required checks; 1d early) |
| F17 | `last_fired_at` index (+ T13 `last_failed_at`) | v7.9.1 / v7.10 | #617 / #694 |
| — | GATE_COVERAGE_ZERO meta-check | v7.10 | #673 + #689 |
| T3 | SignInService passkey/WebAuthn tests | v7.10 | #695 |
| T5 | mock-protocol drift registry | v7.10 | #698 |
| T10 | AI golden-set evals | v7.10 | #691 |
| T14 | `platforms_tested` field + gate (**enforced 2026-06-21**) | 2026-06-07 | #662 · advisory→enforced flip B15 2026-06-21 (PR #781, `6ac372b`) |
| V8-I | Style-Dictionary v3→v5 migration | 2026-06-10 | #677 (was icebox L417/L435) |
| F-DEPLOYED-URL-PROBE | FT2 substrate (`scripts/probe-deployed-url.sh`) | v7.9.1 | fitme-story integration still open |
| F-CONTRACT-FIXTURE-SAMPLING | FT2 substrate + producer sampling | 2026-06-07 | #664 · consumer adoption still open |
| F-LAUNCHD-DRIFT-EXTENSION | all 3 sub-fixes | v7.9.1 | #621–#624 |

**B. Open — carried into the v8.0 build (kickoff ~2026-06-18, after F16 enforce flip):**

| ID | Item | Class | RICE-est | Gating |
|---|---|---|---|---|
| ~~F12~~ ✅ | `actionlint` warn-only CI on `.github/workflows/**` + `make actionlint` | ~~Write-time gate~~ → **CI linter** (reclassified: warn-only tooling like R18, not a state.json gate → no calibration walk) | **100.0 (highest)** | **SHIPPED** (feature `f12-actionlint-gate`; `.github/workflows/actionlint.yml` + Makefile target) |
| ~~F11~~ ✅ | `BRANCH_ISOLATION_HISTORICAL` reverse-sync exemption (state_owner_sync_origin '-reverse' + reverse-sync/ ref) | Cycle-time gate | 40.0 | **SHIPPED** (feature `f11-reverse-sync-historical-exempt`; advisory narrowing — no calibration window) |
| ~~F4~~ ✅ | `FRAMEWORK_VERSION_STALE` advisory gate — fires when a feature is advanced (current_phase transition) while `framework_version` < canonical (FRAMEWORK-FACTS.md). Scope = detection, NOT auto-mutation (operator-chosen) | Write-time gate (advisory) | 32.0 | **SHIPPED 2026-06-16** (feature `f4-framework-version-stale`, PR #740; advisory→enforced flip ~2026-06-30) |
| ~~F10~~ ✅ | `experiment_outcome` enum on `tasks[]` (documented, advisory — not a blocking gate) | Schema | 32.0 | **SHIPPED** (feature `v8-f10-f5-schema-vocab`) |
| ~~F13~~ ✅ | `source_commit` `workflow_dispatch` input + full-repo-scan fallback (reverse-sync) | GH Actions | 32.0 | **SHIPPED** (fitme-story PR #221 — reverse-sync workflow lives in fitme-story) |
| ~~F5~~ ✅ | `scope_change` Tier 2.2 vocabulary event (advisory KNOWN_EVENT_TYPES note) | Vocabulary | 20.0 | **SHIPPED** (feature `v8-f10-f5-schema-vocab`) |
| ~~F1~~ ✅ | `STATE_TASKS_FILESYSTEM_DRIFT` cycle-time advisory — complete feature + empty `tasks[]` + shipped artifact = ledger drift | Cycle-time gate | 19.2 | **SHIPPED 2026-06-17** (feature `f1-state-tasks-filesystem-drift`; advisory-permanent, 5 baseline fires) |
| ~~F3~~ ✅ | `DEPENDENCY_GRAPH_CYCLE` cycle-time advisory — cycles / self-loops / dangling refs across `scheduled_after` + `parent_feature` | Cycle-time gate | 14.4 | **SHIPPED 2026-06-17** (feature `f3-dependency-graph-cycle-check`; advisory-permanent, 0 baseline findings) |
| ~~F22~~ ✅ | Funnel Analysis Dashboards (live GA4, 3/5 funnels wired) | Product observability | M | **SHIPPED 2026-06-24** (feature `funnel-analysis-dashboards`, PR #799) |
| ~~F-CONTRACT (consumer)~~ ✅ | fitme-story consumer adoption + sampling | Cross-repo | — | **SHIPPED 2026-06-22** (feature `contract-fixture-consumer-adoption`, PR #790) |
| ~~F18~~ ✅ | Mutation testing on dispatcher files (mutmut, warn-only weekly CI, 1,857-mutant baseline) | Test infra | 13.7 | **SHIPPED 2026-06-26** (feature `f18-mutation-testing`, PR #809) |
| T1 | `GATE_TEST_MISSING` meta-gate | Test discipline | 53.3 | F14 Phase E **2026-08-22** (fed by F18 mutation-survivor data) |
| F23 | `/ops digest` skill | Skill extension | M | F22 ✓ + Sentry resume (launch-gated, §C) |
| F19/F20 | Analytics Phase 1.B GA4 conversions + gates (`CSV_TAXONOMY_DRIFT`, `GA4_MCP_DISCONNECTED`) | Telemetry/gates | M / L | D-2 operator (GA4) + post-launch signal |
| T4 | Swift snapshot testing | iOS test infra | — | Phase A scaffold shipped (#700); build pending |

**C. Paused / launch-gated:** F21 Sentry (pre-launch trigger; PR #418) · F-AUTH-LATENCY-SERVER-METRIC shipped FT2-side (fitme-story #208).

**D. Operator decision open:** W-MISTRAL-VERCEL-FREE-TIER-BURST (API-tier choice for multi-provider HADF experiments).

**Roll-up:** of the original 18 F-candidates, **17 shipped** (F2, F6, F9, F14, F15, F16, F17, GATE_COVERAGE_ZERO + F5, F10, F11, F12, F13 merged 2026-06-15 via PRs #719/#720/#721/#722 + F4 shipped 2026-06-16 via PR #740 + F1 + F3 shipped 2026-06-17 + **F18 shipped 2026-06-26 via PR #809**) + 2 resolved-by-exemption (F7, F8) → **all ready-now F-items shipped; remaining open** = F19/F20 (operator-gated, GA4 register A1) + F23 (Sentry-resume-gated, §C). **F22 shipped 2026-06-24 (#799); F-CONTRACT-consumer shipped 2026-06-22 (#790); F18 shipped 2026-06-26 (#809)** — reconciled 2026-06-26. Theme H (T1–T16): T3/T5/T10/T13/T14 shipped, T4 in flight, T1 gated to 2026-08-22. **F16 enforce flip DONE 2026-06-17** (try-repo-harness now a main required check) → **v8.0 build kickoff gate cleared**; ship target 2026-07-31.

---

## 1. F-series Candidate Features — Original Source Tables (audit trail)

> Retained verbatim from the original docket for provenance. Read live statuses through §0 above.

**Source A — Roadmap stress-test (2026-05-07 session, [case study](../case-studies/roadmap-stress-test-2026-05-07-case-study.md) §99):**

| ID | Item | Class | RICE-est | Source notes |
|---|---|---|---|---|
| **F1** | `STATE_TASKS_FILESYSTEM_DRIFT` advisory — detect pre-v7.6 features with empty `tasks[]` despite shipped work | Cycle-time gate | 19.2 | Surfaced when 5-of-10 stress-test sub-features had this drift |
| **F2** ✅ | Phase 0 sub-step: reality-check completed work against current state before scheduling | Workflow gate | 42.7 | SHIPPED v7.9.1 (#618) |
| **F3** | Phase 2 dependency-graph cycle/mismatch check for multi-feature roadmaps | Workflow gate | 14.4 | 1 dep-cycle caught manually post-hoc |
| **F4** ✅ | Auto-update `framework_version` on protocol-touching writes OR explicit migration pass | Write-time/migration | 32.0 | SHIPPED 2026-06-16 (#740) as `FRAMEWORK_VERSION_STALE` advisory detector (not auto-mutation) — 9 features had stale `framework_version` post-v7.6 |
| **F5** | Formalize `scope_change` event in Tier 2.2 vocabulary | Vocabulary extension | 20.0 | Currently logged as `event: "note"` |
| **F6** ✅ | Document B_medium tier in CLAUDE.md | CLAUDE.md doc | 30.0 | DONE — "Impact tier labels" section |

**Source B — Stress-test closure session (2026-05-07 evening):**

| ID | Item | Class | RICE-est | Source notes |
|---|---|---|---|---|
| **F9** ✅ | `make complete-feature` pre-flight / closure UX | Workflow ergonomics | 40.0 | SHIPPED — `make close-feature` (#591 + #711) |
| **F10** | Formalize `experiment_outcome` enum (`shipped`/`deferred`/`cancelled`/`superseded`) on `tasks[]` | Schema extension | 32.0 | Deferred tasks distinguished only by case-study prose |

**Source C — v7.8.3 cutover ceremony (2026-05-11):**

| ID | Item | Class | RICE-est |
|---|---|---|---|
| **F11** | Extend `BRANCH_ISOLATION_HISTORICAL` allowlist to `reverse-sync/*` OR read `state_owner_sync_origin` | Cycle-time gate | 40.0 |
| **F12** | Add `actionlint` to pre-commit stack | Write-time gate | **100.0** |
| **F13** | `source_commit` input on `workflow_dispatch` OR full-repo scan fallback | GH Actions infra | 32.0 |

**Source D — PR #317 + test-suite audit (2026-05-12):**

| ID | Item | Class | RICE-est | Status |
|---|---|---|---|---|
| **F14** ✅ | Per-gate `test_main_dispatch_<gate_id>()` requirement | Test discipline | 48.0 | SHIPPED #451/#452/#455 |
| **F15** ✅ | Unit tests for 5 zero-coverage gates | Test discipline | 40.0 | SHIPPED (joint w/ F14) |
| **F16** ✅ | try-repo end-to-end harness | Test infra foundation | 48.0 | SHIPPED v7.9.1 #607–#612 · enforce flip 2026-06-18 |
| **F17** ✅ | Per-gate `last_fired_at` derived index | Telemetry materialization | 66.7 | SHIPPED v7.9.1 #617 (+T13 #694) |
| **F18** | Nightly mutation testing on dispatcher files | Mutation testing | 13.7 | OPEN — gated on F16 Phase E + F14 |

**Source E — post-v7.9 candidate plan (2026-05-20):**

| ID | Item | Class | RICE-est | Status |
|---|---|---|---|---|
| **F19** | Analytics Phase 1.B GA4 conversions (D-2) + dashboard wiring | Telemetry wiring | M | OPEN — D-2 operator + post-launch signal |
| **F20** | Phase 1.B conversion event mapping + Firebase cleanup (D-4) | Schema cleanup | L | OPEN |
| ~~**F21**~~ | ~~Sentry full integration~~ | — | — | **PAUSED → pre-launch** (PR #418) |
| **F22** | Funnel Analysis Dashboards | Product observability | M | OPEN — depends on F19 + GA4 data |
| **F23** | `/ops digest` skill | Skill extension | M | OPEN — depends on F22 + Sentry resume |

**Resolved by exemption (v7.8.2):** F7 (cross-repo gate parity) + F8 (`gate-coverage.jsonl` parity) — documented exemptions.

---

## 2. v8.0 Icebox (V8-I — re-eval on trigger)

Source: [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](../superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md). Default disposition: "not promoted unless trigger fires."

| ID | Item | cu_v2 | Re-eval trigger |
|---|---|---|---|
| **V8-I1** | Agent Smartlog UI — `/control-room/agents` live awareness + path-overlap detection | 2.2 (B_med) | ≥5 concurrent active features for 7+ days |
| **V8-I2** | Op-log Replay — jj-style per-session rollback + GC | 2.9 (A_high) | ≥3 manual-cleanup incidents in 90d OR `git stash list` >5 for 30d |
| **V8-I3** | Vercel Sandbox / Firecracker microVM | 3.1 (A_high) | Untrusted-code-execution use case emerges |
| **V8-I4** | FS kernel sandboxing — Landlock / App Sandbox | 3.05 (A_high) | Regulatory mandate (HIPAA audit trail) |
| **V8-I5** | inotify/fsevents broadcast mediator | 1.9 (B_med) | ≥2 concurrent-write collisions in 60d w/ >30min reconciliation |
| **V8-I6** | Cross-feature dependency analysis | 2.0 (B_med) | `path-reducers.json` ≥20 entries + ≥2 conflicts organically |
| **V8-I7** | Auto-rollback on kill-criteria fire | 3.05 (A_high) | T+7d clean firing + ≥2 manual dry-run successes |

> The 8th former icebox item (Style-Dictionary v5 migration) **SHIPPED 2026-06-10 (#677)** and is removed from the icebox.

---

## 3. v8.0 Docket Decision Process (T29, 2026-05-21)

The 2026-05-21 prioritization pass at `framework-v7-8-branch-isolation` Phase 9 froze the candidate set via: (1) RICE × 7-day telemetry ranking; (2) top-3-per-theme rule (breadth over pure RICE); (3) companion case study; (4) hold-out sub-experiment; (5) Theme-G dependency precedence (F16 foundation). Full ranking: [`v8-0-docket-ranking-2026-05-13.md`](v8-0-docket-ranking-2026-05-13.md).

**Theme distribution (open counts as of 2026-06-15):**

| Theme | Open items | Notes |
|---|---|---|
| A — Roadmap realism | F1, F3 | F2 shipped |
| C — Schema drift | — | F4 (PR #740) + F10 shipped |
| D — Vocabulary | — | F5 + F6 shipped |
| E — Ergonomics | — | F9 shipped |
| F — v7.8.3 cutover | F11, F12, F13 | F12 highest-RICE (100) |
| G — Test discipline | F18, F19, F20, T1 | F14/F15/F16/F17 shipped |
| H — App-layer test coverage | T1, T4 (+ T-series, see [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md)) | T3/T5/T10/T13/T14 shipped |
| Icebox | V8-I1–V8-I7 | trigger-gated |

---

## 4. Cross-references
- Parent docket framing + §3.5 Calibration Protocol + §3.6 Forward Plan: [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)
- T29 frozen ranking: [`v8-0-docket-ranking-2026-05-13.md`](v8-0-docket-ranking-2026-05-13.md)
- Ready-now execution plan: [`v8-0-ready-now-workplan-2026-06-15.md`](v8-0-ready-now-workplan-2026-06-15.md)
- Test-coverage Theme H: [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md)
- Canonical current state: [`../FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md)
