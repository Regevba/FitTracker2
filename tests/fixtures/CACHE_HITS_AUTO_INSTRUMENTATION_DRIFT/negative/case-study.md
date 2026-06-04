---
date_written: 2026-06-04
work_type: Feature
dispatch_pattern: serial
success_metrics:
  - name: tests_pass_pct
    target: 100
    tier: T1
kill_criteria:
  - "all tests fail for 7 consecutive days"
framework_version: v7.9.1
tier_tags_present: true
kill_criteria_resolution: "not_tripped — all tests pass for the F16 fixture"
---

# Negative fixture for CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT

Full frontmatter to clear FEATURE_CLOSURE_COMPLETENESS. Baseline cache_hits
populated; gate must NOT fire. T1 tier tag in body.
