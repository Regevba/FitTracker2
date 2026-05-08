# Research — fitme-story-public-enhancements

**Status:** Phase skipped per work_type:enhancement (B_medium tier latitude). This document points at the audit artifacts that serve as the research equivalent.

**Created:** 2026-05-08

---

## Research-equivalent artifacts (already complete)

This enhancement rollup is sourced from a comprehensive 2026-05-08 audit of the public fitme-story site, conducted by 2 parallel research agents (broad site audit + case-study reading-experience deep-dive) and synthesized into a prioritized punch list.

| Artifact | Purpose | Length |
|---|---|---|
| [`docs/research/2026-05-08-fitme-story-public-site-audit.md`](../../../docs/research/2026-05-08-fitme-story-public-site-audit.md) | Broad code-level audit of every public route + shared component | ~3,100 words; 12 V + 24 A + 18 R findings; 3 P0s |
| [`docs/research/2026-05-08-case-study-readability-deep-dive.md`](../../../docs/research/2026-05-08-case-study-readability-deep-dive.md) | Narrow audit of case-study reading experience | 28 CS findings; 6 case studies sampled across v5.0–v7.8.1; 3 P0s |
| [`docs/research/2026-05-08-fitme-story-audit-synthesis.md`](../../../docs/research/2026-05-08-fitme-story-audit-synthesis.md) | Consolidated synthesis: dedup + prioritization + sequencing | 6 P0s + 12 quick-wins + 5 strategic recommendations |

## Why this approach

Single coherent rollup vs many isolated PRs:
- **Coherent narrative** — "fix the public-site reader experience" is one story
- **Audit traceability** — every task in `tasks.md` cites its source audit finding(s)
- **Closure completeness** — when all 23 tasks ship (or have explicit deferral reasons), the rollup closes with a single case study covering the whole arc
- **Cache reuse** — patterns established in T1–T7 (heading anchors, focus rings, schema opt-out signals) carry into subsequent tasks

## Why not full PM-cycle (Research → PRD → Tasks → UX → Implement)

Per CLAUDE.md F6 (v7.9 candidate, B_medium tier latitude): "PRD/tasks/UX optional when research adequately covers them; skip with documented reason." The 3 audit artifacts cover:
- ✅ Research: what's broken, why it matters, severity tiers, file:line evidence
- ✅ PRD-equivalent: success metrics + scope + sequencing in synthesis §3 + §4
- ✅ Tasks: 23-item breakdown derivable directly from synthesis §5 (already done in this feature's `tasks.md`)
- ✅ UX-equivalent: most items mechanical (a11y / perf / schema / pipeline); larger UI items (P-MOBNAV, P-CALLOUTS) dispatch /ux + /design when picked up

## Predecessor chain

1. **framework-story-site** (v6.0 era) — built the site itself
2. **case-study-presentation** (2026-04-28, PR #146 + fitme-story #8) — Alternative A chrome refactor; G3 + G5 deferred from this work
3. **case-study-comparison-table** (2026-05-07, fitme-story #58) — added cross-corpus comparison table
4. **ucc-passkey-auth** (2026-05-07) — established the cross-repo PR cadence (FT2 + fitme-story paired)
5. **fitme-story-public-enhancements** (this feature, 2026-05-08+) — closes 30+ findings from systematic public-site audit

## What's already shipped

7 of 23 tasks completed today via 2 PRs (see `tasks.md` for the per-task ledger):

- **fitme-story #59** (`95cb4d1`, 13 files +319/-40, prod 05:11:20Z): T1 (skip-link + contrast P0s), T2 (nav chrome P1s), T3 (heading anchors), T4 (mobile table fix), T5 (chrome opt-out schema), T6 (TimelineNav prev/next)
- **fitme-story #61** (`a548e5f`, 3 files +130/-8, prod 05:31:23Z): T7 (ArticleNav sticky sidebar)
- **FT2 #254** (`f252ded`, 6 docs files +1105): the audit synthesis + spec docs that source this rollup

## What's pending (16 of 23)

See `tasks.md` for the full breakdown. Highest priority:
- **T16 (P-MOBNAV)** — only remaining P0; mobile users currently have NO nav fallback below 768px
- **T14 (P-SEO-META)** — buildMetadata() helper; per-page OG/Twitter/JSON-LD; only / has openGraph today
- **T8 + T9 + T10** — G3 → G5 → SEARCH-1 narrative (case-study refinement chain)

## Decision

Approved as Enhancement (4-phase: Tasks → Implement → Test → Merge) under v7.8.1 protocol. Tasks already drafted from audit; implementation in progress (T1–T7 done); remaining tasks ship serially as individual short branches off main.
