# HADF Phase 3A — Sensing / Observability Layer

> **Status:** active (T1–T3 shipped 2026-06-05). **Detection/observability ONLY.**
> This layer makes **no dispatch or routing decisions**. Whether routing on a
> signature improves outcomes is unproven and pre-registered as RQ4 (Phase 3B).
> Per-request single-shot attestation accuracy is unvalidated (RQ5). Never route
> on attestation output; never present it as authoritative.

Phase 3A turns the validated HADF signal — streaming TTFT/TPS signatures are
real, provider-general, substrate-discriminating, and short-term-stable (all 4
Phase 2-bis sub-experiments PASS, 2026-06-05) — into a passive surface that
*detects* and *reports*.

## Components

| Component | Producer | Output | Tier |
|---|---|---|---|
| Reference store (T1) | `scripts/hadf-build-reference-store.py` | `reference-signatures.json` | T1 (instrumented) |
| Attestation (T2) | `scripts/hadf-attest.py` | stdout / JSON | T1-input → **T3 advisory** interpretation |
| Drift monitor (T3) | `scripts/hadf-drift-monitor.py` | `drift-monitor.jsonl` (append-only) | T1 (KS / Mahalanobis vs baseline) |

T4 (control-room HADF panel, fitme-story) and T5 (`AIOrchestrator` live-traffic
emit hook — high-risk-area review) are **deferred follow-ons** (spec §3/§4).

## reference-signatures.json

Built from the **closed** Phase 2-bis raw collections (Sub-exps 1/2/3/1B). Per
`(provider, endpoint)`: n, TTFT/TPS quantiles + mean/std, 2-D mean + covariance
(for Mahalanobis attestation), and provenance (contributing sub-exps).
Endpoints with `n < --min-n` (default 50) are excluded as `excluded_low_n` —
this filters rate-limited v1 partials (mistral n=9, vercel n=5). Records whose
TTFT exceeds `--max-ttft` (default 30s) are dropped as connection-stall / retry
artifacts — **not** streaming-latency samples (7 dropped: the Sub-exp 1B Fire-0
launch-probe stalls of 995s / 886s / 124s plus 4 borderline, whose variance
would otherwise swallow the per-endpoint covariance and break attestation). The
drop count is recorded per endpoint (`provenance.dropped_implausible_ttft`) and
in `dropped_implausible_ttft_total`. Current build: **8 endpoints, 7197 valid
records**, `min_n=50`, `max_ttft_s=30`, as-of 2026-06-05.

**Same-model endpoints attest "weak", by design.** `anthropic/claude-haiku` and
`aws-bedrock/.../claude-haiku-4-5` serve the *same model* with overlapping TPS,
so the attestation runner-up gap is <1σ → confidence is **weak**, never strong.
This is the correct conservative posture and a live demonstration of the RQ5
caveat (single-shot attestation is not authoritative). The Phase 2-bis Sub-exp 3
result — that these two endpoints ARE distinguishable in aggregate
(signature_delta_ratio 2.89) — holds at the *distribution* level, which is what
the drift monitor uses; it does not promise per-request separability.

Rebuild:

```bash
make hadf-reference-store AS_OF=2026-06-05
# or with extra raw dirs from per-sub-exp worktrees:
python3 scripts/hadf-build-reference-store.py \
    --raw-dir <impl-worktree>/.claude/shared/hadf \
    --raw-dir <subexp3-worktree>/.claude/shared/hadf \
    --raw-dir <subexp1b-worktree>/.claude/shared/hadf \
    --out .claude/shared/hadf/reference-signatures.json --as-of 2026-06-05
```

## Attestation (advisory)

Scores an observed `(ttft_s, tps)` against every reference endpoint via
Mahalanobis distance (same math as the Sub-exp 3 verdict) and reports the best
match + a confidence band:

- **strong** — within 2σ of a centroid AND ≥1σ closer than the runner-up
- **weak** — within 4σ
- **uncertain** — beyond 4σ ⇒ `unknown / unseen substrate`

Every output carries `advisory: true` and the "do NOT route" caveat.

```bash
make hadf-attest TTFT=1.47 TPS=170      # → bedrock/haiku, strong
python3 scripts/hadf-attest.py --jsonl <raw.jsonl>   # batch summary
```

## Drift monitor (operationalizes Sub-exp 1B)

Compares a recent window vs each endpoint's locked baseline. Mahalanobis mean
shift in baseline-σ units → `stable` (<1σ) / `minor_drift` (1–3σ) /
`significant_drift` (>3σ, re-baseline recommended). KS divergence on either
marginal (p<0.01) raises a `ks_diverged` flag. Windows below 30 samples report
`insufficient_window`. Drift is **expected** over time (provider infra changes);
flagging it is the point, not a failure.

```bash
make hadf-drift-monitor WINDOW=<recent-raw.jsonl> AS_OF=2026-06-05
# appends one JSON line per endpoint to drift-monitor.jsonl
```

## Tests

`scripts/tests/test_hadf_sensing.py` — 8 tests pinning the builder
(aggregate + low-n filter + empty-error), attestation (centroid match,
unseen-substrate uncertainty, advisory-flag invariant), and drift monitor
(stable / significant / insufficient-window). Requires numpy + scipy + pytest.

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-02-hadf-phase3a-sensing-layer-design.md`
- Acting layer (RQ4): `docs/superpowers/specs/2026-06-02-hadf-phase3b-rq4-decision-value-design.md`
- Source of truth: `.claude/shared/hadf/HADF-SOURCE-OF-TRUTH.md` §10
