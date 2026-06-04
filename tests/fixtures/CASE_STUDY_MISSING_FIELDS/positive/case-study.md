---
date_written: 2026-06-04
title: F16 test fixture — missing required fields
---

# Positive fixture for CASE_STUDY_MISSING_FIELDS

This case study deliberately omits the 4 REQUIRED_FRONTMATTER_FIELDS:
work_type, success_metrics, kill_criteria, dispatch_pattern.

Date is 2026-06-04 which is >= FIELDS_CUTOFF_DATE (2026-04-28), so the
gate must fire and reject the commit.
