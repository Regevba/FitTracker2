# HADF Phase 3A — T4 + T5 Data-Integrity Risk Assessment

> **Scope:** advancing the two deferred Phase 3A follow-ons — T4 (control-room HADF
> panel, fitme-story) and T5 (`AIOrchestrator` live-traffic emit hook, iOS).
> **Method:** overlaid on [infra-master-plan-2026-05-12.md](../../../docs/master-plan/infra-master-plan-2026-05-12.md)
> §2.2 (promotion criteria), §3.5 (5-phase Calibration Protocol), §3.5.4 (Reversibility
> Contract), and [data-integrity-and-rollback-2026-05-14.md](../../../docs/master-plan/data-integrity-and-rollback-2026-05-14.md)
> §2.3 (drift classification) + §3 (platform-baseline rollback). Author: 2026-06-07.
> **Verdict in one line:** **T4 = GO** (low-risk read-only advisory surface); **T5 = BLOCKED-as-specified** → descope to a measurable on-device signal, defer true `ttft_s`/`tps` to a server-side metric.

---

## 1. Classification against the Calibration Protocol (§3.5.1)

| | T4 — control-room HADF panel | T5 — AIOrchestrator emit hook |
|---|---|---|
| Layer type | **Read-only derived surface** (renders synced JSON/JSONL) | **Net-new on-device instrumentation** (analytics emit + AI-path timing) |
| New enforcement gate? | No | No |
| Calibration phases required | Minimal — §3.6.3 "no advisory window for read-only derived artifacts" | Phase A (spec) mandatory; analytics event needs `/analytics spec` Phase-1 gate |
| Repo | fitme-story (Mechanism-A-exempt, v7.8.2) | FitTracker2 (full gate set) |
| High-risk area? | No | **Yes** — `AIOrchestrator.swift` on CLAUDE.md high-risk list |
| Data-integrity risk tier | **LOW** | **HIGH** (correctness-of-measurement, not just code risk) |

**Layer Stacking Rule (§3.5.2) check:** Phase 3A sensing (T1–T3) is itself still pre-Phase-E (feature `current_phase=implementation`, no advisory→enforced gate). T4/T5 do **not** build a new *enforcement* layer on top of it — T4 only *renders* the T1–T3 outputs and T5 only *feeds* a future live-traffic variant. No stacking violation, **provided neither T4 nor T5 introduces an enforced gate.** Both must ship advisory/observability-only. ✅

---

## 2. T4 — control-room HADF panel — risk profile

**What it is:** a passkey-gated `/control-room/framework` sibling panel rendering `reference-signatures.json` (per-endpoint TTFT/TPS reference distributions) + `drift-monitor.jsonl` (drift status) + the advisory attestation readout.

### Gate/pattern overlay
| Gate / pattern | Applies? | Mitigation |
|---|---|---|
| Mechanism A `gate-coverage.jsonl` | **Exempt** (v7.8.2 cross-repo asymmetry, F8) | n/a — fitme-story side |
| **W16 — contract-boundary fixture sampling** | **YES — primary risk** | Panel loader + any test fixture MUST validate against the canonical producer schema (`reference-signatures.json` `schema_version`, `endpoints[].{provider,endpoint,n,ttft_s,tps,mean,cov,calibration_status,class}`) — never a consumer-invented shape. This is the exact 13-day silent-pass W16 reproduced on `/control-room/framework` before. |
| W11 / W34 — PR-cite cache (cross-repo) | Indirect (closure-time only) | Standard; unified PR cache covers `[fitme-story#N]`. |
| `FEATURE_CLOSURE_COMPLETENESS` (Q6/Q7) | At closure | 7 frontmatter fields + kill_criteria_resolution + PR-list parity. |
| Passkey/`noindex` gating | Inherited | New route under `/control-room/*` auto-gated by `src/proxy.ts` matcher; do **not** add a public `/framework` twin. |

### Data-integrity-specific risks
1. **Schema drift between producer and panel (W16).** *Likelihood: med · Impact: med (silent stale/blank panel).* → load only `schema_version`-pinned fields; render an explicit empty state on `null`/mismatch; add a fixture sourced from the real `reference-signatures.json`.
2. **`drift-monitor.jsonl` does not exist yet** (the producer `hadf-drift-monitor.py` writes on demand; no file on disk) and **the sync script skips `.jsonl` in `shared/hadf/`** (only recurses `*.json`). *Impact: panel renders empty forever if not wired.* → add an explicit `.jsonl` forward-sync block modeled on the existing `gate-coverage.jsonl` precedent (`sync-from-fittracker2.ts:792-806`); panel must degrade gracefully to empty until the monitor runs.
3. **Heavy payload leak.** `cov` covariance matrices + full percentile blocks are large. → select-fields in the loader (provider/endpoint/n/ttft median/tps median/drift band), never dump raw `cov`.
4. **Honesty labeling.** Attestation confidence is `[T1-input → T3-interpretation]` advisory. → panel must label it "advisory — not authoritative; per-request accuracy unvalidated (RQ5)", matching `SENSING-LAYER-README.md`.

### Reversibility (§3.5.4)
Read-only surface; rollback = `git revert` the panel PR (<2 min). No gate flip, no data mutation. ✅

### Verdict: **GO.** Ship advisory/observability-only. No calibration window needed (read-only derived artifact, §3.6.3). Primary control = W16 producer-schema fixture.

---

## 3. T5 — AIOrchestrator emit hook — risk profile

### ⚠ Architectural blocker (load-bearing finding)
**`ttft_s` + `tps` as specified are NOT capturable on the iOS client today.**
- `AIOrchestrator.process(...)` → `AIEngineClient.fetchInsight` does a **one-shot `session.data(for:)`** — no streaming, **no first-token boundary**, so no true TTFT and no token-rate.
- **Provider/model are server-side only.** The iOS client knows the `segment`; the Railway FastAPI selects the LLM. The `AIRecommendation` response carries no `provider`/`model`.
- On-device `FoundationModel.adapt(...)` is also non-streaming (single `async throws` tuple).
- There is **no existing on-device HADF/ttft/tps sink** — T5 is net-new instrumentation.

⇒ Emitting a field named `ttft_s`/`tps` from the client would be **fabricated/mislabeled data** — a direct violation of the HADF program's central honesty commitment (*measured ≠ guessed*, the same principle the `calibration_status` field enforces). **Shipping it as-specified would manufacture a data-integrity defect, not close one.**

### Gate/pattern overlay
| Gate / pattern | Applies? | Note |
|---|---|---|
| **High-risk-area review policy** (CLAUDE.md Branching) | **YES** | `AIOrchestrator.swift` → parallel feature-vs-main review; both branches CI-green before merge. |
| **Analytics Naming Convention + `/analytics spec` Phase-1 gate** | **YES** | New AI-path event must be declared in `analytics-taxonomy.csv` (`screen_scope=global`, unprefixed lifecycle name e.g. `ai_inference_completed`). |
| **W23 — `AnalyticsService.logEvent` is private** | **YES** | Emit must route through a named public `log*` wrapper, never bypass the taxonomy funnel. |
| **W19 — analytics-emit silent-pass** | **YES** | A mislabeled/empty payload can be silently dropped/accepted (GA4 6-day silent reject precedent). Reinforces: don't emit a field you can't populate truthfully. |
| `verify-local` hard gates | YES | tokens-check + ui-audit P0=0 + build + test all run even for a non-UI change. |
| W25 — `@MainActor` static propagation | Testing | `AIOrchestrator` is `@MainActor`; the timing test class must be `@MainActor`. |
| QA high-risk-path integration test | YES | `/qa` requires an integration test; `AIEngineClientProtocol` URLProtocol-mock seam exists. |

### Data-integrity-specific risks
1. **Fabricated metric (CRITICAL).** Emitting `ttft_s`/`tps` the client cannot measure. → **descope:** emit only what is truthfully measurable on-device — round-trip `duration_ms` (wall-time around the `fetchInsight`/`adapt` await) + `source_tier` (cloud vs on-device, already an `AnalyticsParam`). Capture true `ttft_s`/`tps` + provider/model **server-side** (consistent with the backlog item `F-AUTH-LATENCY-SERVER-METRIC` / `duration_ms_server`).
2. **Taxonomy drift (W23).** → named wrapper + `/analytics spec` pass before code.
3. **High-risk-path regression.** → optional-chained `analytics?` seam already in `process(...)`; emit is additive and no-ops when analytics unwired (preserves existing test paths). Still requires the high-risk review gate.
4. **Soak-window dilution.** If shipped during a soak window, freeze or backfill adoption metrics (CLAUDE.md soak-window discipline).

### Reversibility (§3.5.4)
Additive emit behind optional chaining; rollback = `git revert` (<2 min). No schema/gate change if descoped to `duration_ms`. ✅

### Verdict: **BLOCKED as specified → DESCOPE.**
- **T5a (now, low-risk):** on-device `ai_inference_completed` event with `duration_ms` + `source_tier`, via a named `AnalyticsService.logAiInference...` wrapper, gated by `/analytics spec` + high-risk-area review. Truthfully measurable; closes the "no live-traffic observability" gap honestly.
- **T5b (deferred, server-side):** true `ttft_s`/`tps` + `provider`/`model` require (a) a streaming rewrite of `AIEngineClient.fetchInsight` and (b) a Railway contract returning per-call timing + provider/model. Track as a server-side metric (sibling to `F-AUTH-LATENCY-SERVER-METRIC`); do **not** attempt client-side.

---

## 4. Data-integrity risk register (summary)

| ID | Risk | Task | Likelihood | Impact | Tier | Control |
|---|---|---|---|---|---|---|
| R1 | Producer↔panel schema drift (W16) | T4 | Med | Med | LOW | schema-pinned loader + producer-sourced fixture |
| R2 | `drift-monitor.jsonl` unsynced/absent | T4 | High | Low | LOW | explicit `.jsonl` sync block + empty-state |
| R3 | Advisory data shown as authoritative | T4 | Low | Med | LOW | explicit advisory labeling (RQ5 caveat) |
| R4 | **Fabricated `ttft_s`/`tps` client metric** | T5 | High | High | **HIGH** | **descope to `duration_ms`+`source_tier`; ttft/tps server-side** |
| R5 | Analytics taxonomy bypass (W23) | T5 | Med | Med | MED | named wrapper + `/analytics spec` gate |
| R6 | High-risk-path regression (AIOrchestrator) | T5 | Low | High | MED | feature-vs-main review + CI-green both + integration test |
| R7 | Soak-window adoption dilution | T4+T5 | Low | Low | LOW | freeze or backfill in same PR |

**No platform-baseline-rollback (§3) trigger:** neither task is a compound/CRITICAL drift class; both are single-PR `git revert`-able. The heavyweight escape hatch stays unused.

---

## 5. Recommended execution order
1. **T4 now** — panel ships advisory/observability-only; W16 fixture is the gate. fitme-story branch, passkey-gated route.
2. **T5a now (if `/analytics spec` clears)** — descoped `duration_ms`+`source_tier` emit on a feature branch with high-risk-area review.
3. **T5b deferred** — server-side ttft/tps + provider/model; new backlog item, not client-side.
4. Closure: keep `hadf-phase3a-sensing` honest — record PR(s), do NOT claim live ttft/tps until T5b ships; update `SENSING-LAYER-README.md` + HADF SoT to reflect T4 done + T5 descoped.
