# Data Quality Tiers

> **Purpose:** Make the provenance of every metric explicit. A narrative
> cache-hit rate should not be weighed the same as an instrumented
> wall-time measurement. This convention, recommended by the Google
> Gemini 2.5 Pro audit (2026-04-21, Tier 2.3), codifies three tiers
> every reader can use to calibrate confidence.
>
> Applies to: case studies, per-feature PRDs, meta-analyses, dashboard
> cards, any document that reports a measurement.

---

## The three tiers

| Tier | Name | Definition | Trust | Examples |
|---|---|---|---|---|
| **T1** | **Instrumented** | Machine-generated, externally verifiable, reproducible by re-running the tool. | High | `state.json.timing.*` timestamps (v6.0+), `cache-hits.json` counters (v6.0+), token counts from a tokenizer, `git log` data, `gh pr view` resolution, tiktoken outputs, test-pass counts from CI JSON, GA4 event counts. |
| **T2** | **Declared** | Structured, human- or AI-entered in a typed field, not externally verifiable but auditable via file review. | Medium | `state.json.tasks[]` with status strings, self-reported task counts, work-type classifications, complexity-factor selections (`UI +0.3`), framework version strings. |
| **T3** | **Narrative** | Qualitative or unstructured prose, derived from recall or interpretation, not auditable against a single source of truth. | Low | Pre-v6.0 cache-hit percentages ("~45%"), pre-v6.0 wall-time estimates ("~90 min"), inferred velocity deltas, post-hoc explanations of regressions, design-iteration counts. |

## Mapping to existing markers

The case-study template (`docs/case-studies/case-study-template.md`) already uses
provenance markers on phase-timing and cache-detail rows. Map them as follows:

| Template marker | Meaning | Tier |
|---|---|---|
| `(m)` | measured | **T1** |
| `(e)` | estimated | **T3** (or **T2** if derived from a structured declaration) |
| `(i)` | inferred | **T3** |

Existing case studies need not be re-labeled. New and revised case
studies should use explicit `T1`/`T2`/`T3` labels where present, and fall
back to `(m/e/i)` only if the existing column is already in use.

## How to apply

### Every quantitative claim gets a tier

Instead of writing "cache hit rate was 45%," write:

> Cache hit rate: 45% (T3 — narrative, pre-v6.0 instrumentation)

or

> Cache hit rate: 45% (T1 — from `.claude/features/{name}/cache-hits.json`)

### Mixed-tier aggregates call out the mix

When a single number is built from multiple tiers, say so:

> Velocity (min/CU): 5.1 (T1 wall time × T2 CU)

### Pre-v6.0 data is T3 by default

Any case study with `framework_version < 6.0` in its state.json should
assume all timing, cache-hit, and token metrics are T3 unless the case
study explicitly records a different source. v6.0 introduced
instrumentation that moved those specific metrics to T1 going forward.

### Comparing across tiers requires the lowest tier

If you report "v5.1 is 5× faster than v2.0," the v2.0 wall time is T3.
The comparison result is therefore T3, not T1, even if the v5.1 side is
instrumented. Mark it: **Velocity ratio: 5× (T3 — limited by T3 baseline)**.

## What this changes

- **Readers** can filter dashboards/claims by tier and weight their trust accordingly.
- **Writers** are forced to notice when they're making a T3 claim that sounds like a T1 claim.
- **Audits** (internal meta-analysis, external audits like Gemini's) can flag tier-inflation where a T3 number is quoted as if it were T1.
- **Forward motion** — the instrumentation from v6.0 onward will produce more T1 data over time. Old case studies can be re-tagged as T3 without being re-written, and new case studies can lean on T1 where possible.

## What this does NOT do

- It does not gate merges. A T3 metric is not forbidden — just labeled.
- It does not retroactively regrade every existing case study. The 41 case studies as of 2026-04-21 stay labeled with their existing `(m/e/i)` markers; the mapping table above bridges the two systems.
- It does not override domain-specific precision terms. "eval pass rate" stays "eval pass rate" — the tier label is ADDED, not substituted.

## References

- The Gemini 2.5 Pro independent audit recommendation ("Mandate explicit data quality tiers"): [`independent-audit-2026-04-21-gemini.md`](./meta-analysis/independent-audit-2026-04-21-gemini.md) §7, Tier 2.3.
- Framework v6.0 measurement instrumentation rationale: [`framework-measurement-v6-case-study.md`](./framework-measurement-v6-case-study.md).
- CU v1 vs CU v2 (continuous factors) — a T2 → T2 upgrade in classification granularity: [`what-if-v6-from-day-one-2026-04-16.md`](./meta-analysis/what-if-v6-from-day-one-2026-04-16.md) §4.
