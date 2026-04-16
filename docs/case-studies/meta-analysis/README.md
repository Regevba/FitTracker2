# Meta-Analysis Reports

> Cross-case analyses that examine the FitMe PM framework as a whole rather than individual features. These documents synthesize data across all case studies to validate the normalization model, identify measurement gaps, and project framework improvements.

## Reports

| Report | Date | Source | Purpose |
|--------|------|--------|---------|
| [Meta-Analysis Validation](meta-analysis-validation-2026-04-16.md) | 2026-04-16 | Nemotron 3 Super (Nvidia) | External validation of the normalization model, arithmetic consistency check, identification of 8 measurement gaps, and 8 concrete recommendations for improvement |
| [What-If: V6.0 From Day One](what-if-v6-from-day-one-2026-04-16.md) | 2026-04-16 | Claude Opus 4.6 (Anthropic) | Counterfactual experiment: retroactive application of v6.0 measurement to all 24 features. Covers precision gains, CU v2 recalculation, rolling baseline plateau detection, parallel decomposition, AI model cost comparison, and full effort/ROI analysis |

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
