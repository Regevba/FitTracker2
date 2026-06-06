# HADF Program — Closeout & Next-Phase Readiness (2026-06-06)

Authoritative handoff record marking the HADF experimental program complete and
the next phase ready to launch. The live status ledger remains
[`HADF-SOURCE-OF-TRUTH.md` §-1](../../.claude/shared/hadf/HADF-SOURCE-OF-TRUTH.md);
this doc is the master-plan-level closeout + tracker reconciliation.

## 1. Program status: COMPLETE — CONFIRMED (sensing layer)

**HADF Phase 2-bis is COMPLETE. All four sub-experiments PASSED → the HADF
dispatch premise is CONFIRMED at the SENSING layer.**

| Sub-exp | Verdict | Key number [T1] | n_valid |
|---|---|---|---|
| 1 — cloud generalization | ✅ PASS | silhouette 0.7003 @ k=5 | 2,600 |
| 2 — cloud vs local | ✅ PASS | KS TTFT p=9.3e-136, TPS p=5.9e-322 | 800 |
| 3 — routing falsification | ✅ PASS (survived) | signature_delta_ratio 2.89 (>2.0) | 2,239 |
| 1B — cross-window drift | ✅ PASS | silhouette 0.98 @ k=2; drift 0.19σ | 1,465 |

Total program cost ≈ $1.74; no kill criterion fired. **Honesty boundary:**
confirms SENSING (signatures detectable); does NOT confirm ACTING (routing
improves outcomes) — pre-registered as RQ4 / Phase 3B, not yet started.

## 2. Shipped downstream

| Work | PR | Status |
|---|---|---|
| Block C synthesis case study + showcase 22c | FT2 #632 | merged |
| HADF×ORCHID overlay → CONFIRMED | FT2 #634 | merged |
| ORCHID capstone published (slot 37) | fitme-story #180 | merged |
| Phase 2-bis synthesis showcase publish | fitme-story #179 | merged |
| Phase 3A sensing layer (reference-store + attestation + drift-monitor, detection-only) | FT2 #635 | merged |
| SoT + integration-note doc-refresh → CONFIRMED | FT2 #641 | merged |
| Signature-expansion feature (calibration_status honesty layer + on-device harness + real M4 calibration + one-command experiment) | FT2 #644 | **open — ready for execution** |
| ORCHID standalone repo: v1.5 forward-port + HADF validation doc | orchid #1 | **open** |
| Research-page surfaces capstone | fitme-story #181 | merged |

## 3. Tracker reconciliation

- **Linear:** FIT-71 (HADF Phase 2-bis) = **Done**. FIT-116 + FIT-117 (Sub-exp 1 ORCHID analysis) → **Done** (subsumed by Block C synthesis + #634 overlay + #641 note). Still-open *future* items (correctly NOT closed): FIT-195/196 (Phase 3A T4/T5 deferred follow-ons), FIT-124 (Track 6 / acting-layer = next phase), FIT-126/127 (External Audits #2 2026-06-12 / #3 2026-08-05), FIT-68/65/129 (Phase 2 external-audit + backup decisions), FIT-130 (replication pack).
- **Notion:** "HADF Phase 2-bis + ORCHID Integration" page prepended with the ✅ COMPLETE — CONFIRMED status block. "HADF Phase 3a — T4 + T5 Deferred Follow-ons" page already correct.
- **Backlog:** `docs/product/backlog.md` in-progress row flipped to ✅ complete — CONFIRMED.

## 4. Backup (this session)

Full program archived **dual-location, sha256-verified (106 files)**:
- `~/Documents/FitTracker2-backups/2026-06-06-hadf-program-final/`
- `/Volumes/DevSSD/FitTracker2-snapshots/2026-06-06-hadf-program-final/`

Contents: all 63 raw `.jsonl` fires (Sub-exp 1/2/3/1B) + verdicts + locked preregs
+ calibrated reference store (incl. real M4) + docs + full script toolchain + tests.
See the backup's `README.md` + `SHA256SUMS.txt`.

## 5. Next phase — READY TO LAUNCH

### 5a. Signature-expansion experiment (ready now)
Feature `hadf-signature-expansion` (PR #644) is **ready for execution**. The
`calibration_status` honesty layer + on-device + cloud calibration harnesses ship
with a one-command experiment:
```bash
make hadf-expand-signatures DRY_RUN=1   # preview
make hadf-expand-signatures             # fire — device (free) + cloud (paid), → instrumented ≥12
```
Manifest: `.claude/shared/hadf/signature-expansion-endpoints.json`. Currently 9
instrumented signatures (8 baseline + real M4, K2 PASS); firing the cloud leg
takes it past 12. Gated only on merge of #644 + operator firing the paid leg.

### 5b. Phase 3B / RQ4 — acting-layer decision-value (designed, not started)
Spec: [`docs/superpowers/specs/2026-06-02-hadf-phase3b-rq4-decision-value-design.md`](../superpowers/specs/2026-06-02-hadf-phase3b-rq4-decision-value-design.md).
Tests whether *routing on* a signature beats a naive baseline (RQ4) + single-shot
classifier accuracy (RQ5) + long-horizon drift (RQ6). **Needs a design pass +
operator confirmation + a locked pre-registration before any data collection** —
the same pre-registration discipline as Phase 2-bis. This is the load-bearing
next experiment: it gates any live *dispatch* (acting) activation.

### 5c. Phase 3A follow-ons (deferred, tracked)
T4 control-room HADF panel (fitme-story, FIT-195) + T5 AIOrchestrator live-traffic
emit hook (iOS high-risk-area, FIT-196). Not blocked — scheduled follow-ons.

## 6. Calendar anchors
- **2026-06-12** — External Audit #2 (raw `.jsonl` integrity across sub-exps) — the 2026-06-06 backup is the audit substrate.
- **2026-08-05** — External Audit #3 (Block C synthesis + ORCHID v2 coherence).
