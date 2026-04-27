---
title: Onboarding v2 Retroactive — Multi-Screen v2-Rule Validation
date_written: 2026-04-27
work_type: Enhancement
dispatch_pattern: serial
success_metrics:
  primary: "Validate v2-subdirectory rule scales to a multi-screen feature without regressions"
kill_criteria:
  - "Build target swap fails for any of the multi-screen v2 files"
  - "v1 historical comments fail to render in IDE for any swapped file"
status: stub_pending_resume
---

# Onboarding v2 Retroactive (stub)

> **[T3]** This is a stub created during v7.7 M2 T10 to satisfy the
> linkage gate (`STATE_NO_CASE_STUDY_LINK`). The actual case-study content
> will be written when this feature resumes after v7.7 closure (its
> `paused.resume_signal` fires on `framework-v7-7-validity-closure phase=complete`).
> At that point this file will be filled in with the multi-screen
> v2-rule application narrative.

## Context

Onboarding v2 (PR #59) was the pilot foundations-aligned UI refactor and
shipped *before* the v2-subdirectory rule was codified in CLAUDE.md.
It used the older "patch v1 in place" approach. The v7.7-paused feature
`onboarding-v2-retroactive` is the planned retroactive split into the
`v2/` subdirectory convention to validate the rule scales to a feature
with multiple screens.

## Resume signal

`framework-v7-7-validity-closure phase=complete`. After resume, the
`paused.snapshot.next_action_when_resumed` field in
[`.claude/features/onboarding-v2-retroactive/state.json`](../../.claude/features/onboarding-v2-retroactive/state.json)
is the entry point.
