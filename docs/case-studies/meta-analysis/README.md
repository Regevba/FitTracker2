# Meta-Analysis Reports

> Cross-case analyses that examine the FitMe PM framework as a whole rather than individual features. These documents synthesize data across all case studies to validate the normalization model, identify measurement gaps, and project framework improvements.

## Reports

| Report | Date | Source | Purpose |
|--------|------|--------|---------|
| [Meta-Analysis Validation](meta-analysis-validation-2026-04-16.md) | 2026-04-16 | Nemotron 3 Super (Nvidia) | External validation of the normalization model, arithmetic consistency check, identification of 8 measurement gaps, and 8 concrete recommendations for improvement |
| [What-If: V6.0 From Day One](what-if-v6-from-day-one-2026-04-16.md) | 2026-04-16 | Claude Opus 4.6 (Anthropic) | Counterfactual experiment: retroactive application of v6.0 measurement to all 24 features. Covers precision gains, CU v2 recalculation, rolling baseline plateau detection, parallel decomposition, AI model cost comparison, and full effort/ROI analysis |
| [Meta-Analysis 2026-04-21](meta-analysis-2026-04-21.md) | 2026-04-21 | Internal (Claude Opus 4.7) | Structural meta-analysis of all case studies + framework state immediately before the Gemini independent audit. Source corpus that Gemini reviewed |
| [Independent Audit — Gemini 2.5 Pro](independent-audit-2026-04-21-gemini.md) | 2026-04-21 | Google Gemini 2.5 Pro | Verbatim text of the independent audit covering 65 case studies + 3 internal meta-analyses. Different vendor, different model family, artifact-only access. **Trigger** for v7.5 + v7.6 framework rework. Same-day correction appended for the false-positive PR-vs-issue mix-up |
| [v7.5 Advancement Report](v7-5-advancement-report.md) | 2026-04-24 | Internal (Claude Opus 4.7) | Before/after measurement of every Gemini Tier item across the v7.1 → v7.5 transition. Every quantitative claim T1/T2/T3 tagged |
| [Unclosable Gaps Inventory (v7.7 — 4 remain)](unclosable-gaps.md) | 2026-04-27 | Internal (Claude Opus 4.7) | The 4 mechanically unclosable Class B gaps remaining after v7.7 closed the cache_hits writer-path gap. Each gap has a 4-section format: technical reason / observability / human action / tracking. Includes the v7.5 → v7.6 and v7.7 Class A vs Class B promotion tables. |
| [v7.7 Validity Closure](../framework-v7-7-validity-closure-case-study.md) | 2026-04-27 | Internal (Claude Opus 4.7) | Full narrative of v7.7: 5 new check codes (4 gating + 1 advisory permanent), framework-health dashboard, cache_hits writer-path closed, 32 case-study frontmatter backfills, 3 timing-phases backfills. Case study chain: Gemini audit → v7.5 → v7.6 → v7.7. |

## How These Relate

The Nvidia meta-analysis identified the problems. The What-If analysis models the solution.

```
Meta-Analysis (Nvidia)          What-If (Claude)
  8 measurement gaps    ──────>   Cost/benefit of fixing each gap
  Normalization model   ──────>   CU v2 recalculation for all features
  Power law validation  ──────>   R² improvement (0.82 → 0.87)
  Recommendations       ──────>   Full implementation + ROI: 2.2x
```

## When to Add a New Report

Add a meta-analysis report when:
- A new framework version ships and needs cross-feature validation
- The dataset grows by 5+ features since the last analysis
- An external model or reviewer audits the case study data
- A counterfactual experiment is run against the historical dataset

## Related Documents

- [Normalization Framework](../normalization-framework.md) — CU formula, velocity calculations, trend data
- [Case Study Template](../case-study-template.md) — Template for individual feature case studies
- [Framework Measurement v6.0 Case Study](../framework-measurement-v6-case-study.md) — The case study for the feature that implemented the v6.0 recommendations
