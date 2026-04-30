# Project Framework v7.1 Integrity Cycle (composed into v7.5 on 2026-04-24, extended by v7.6 on 2026-04-25)

This file is a lightweight entrypoint to the canonical v7.1 Integrity Cycle
case study and the Gemini-audit follow-up that extended it into the
Independent Auditor Agent work.

**Framework-version context:** the 72h Integrity Cycle shipped at v7.1 is now
one of eight cooperating defenses in the **v7.5 Data Integrity Framework**
(shipped 2026-04-24), and is complemented by the v7.6 mechanical-enforcement
layer (shipped 2026-04-25 — per-PR review bot via
[`pr-integrity-check.yml`](/Volumes/DevSSD/FitTracker2/.github/workflows/pr-integrity-check.yml)
and weekly framework-status cron via
[`framework-status-weekly.yml`](/Volumes/DevSSD/FitTracker2/.github/workflows/framework-status-weekly.yml)).
The v7.1 cycle now plays a **safety-net** role: per-PR enforcement catches
findings synchronously on every PR; the 72h cycle is the redundant rear-guard
that catches anything the per-PR layer misses (e.g., findings that only emerge
when state from multiple unrelated PRs interacts).
v7.1 is still the canonical entry for the cycle's history and initial design;
v7.5's case study is the canonical entry for how v7.1 composes with the 7
sibling defenses; v7.6's case study is the canonical entry for the
mechanical-enforcement layer.

## Canonical sources

- v7.5 Data Integrity Framework case study: [docs/case-studies/data-integrity-framework-v7.5-case-study.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/data-integrity-framework-v7.5-case-study.md)
- v7.1 case study: [docs/case-studies/integrity-cycle-v7.1-case-study.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/integrity-cycle-v7.1-case-study.md)
- Gemini follow-up audit: [docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md](/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md)
- Trust bundle index: [trust/audits/2026-04-21-gemini/README.md](/Volumes/DevSSD/FitTracker2/trust/audits/2026-04-21-gemini/README.md)

## Relationship

- v7.1 shipped the 72-hour Integrity Cycle as recurring framework
  self-observation.
- Gemini's 2026-04-21 independent audit recommended an additional
  Independent Auditor Agent layer (Tier 3.1).
- The project status on 2026-04-21 is: v7.1 integrity cycle shipped, auditor
  layer shipped, staging-gated smoke-test transitions still backlog.

For implementation details, detector semantics, cadence rationale, and shipped
infrastructure, use the canonical v7.1 case study.
