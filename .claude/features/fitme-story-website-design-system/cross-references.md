# Cross-references — fitme-story-website-design-system

**Created:** 2026-05-10
**Triggered by:** User directive 2026-05-10: "make sure to incorporate all of the data and ux/design decisions made on the site so far, when design system is finished let's review the entire site under the design system lens and see what other enhancements needs to be made, cross reference this task and the design system with other tasks that are already in backlog and your memory"

---

## §1 Existing site decisions the showcase MUST surface

These are durable design decisions already shipped in fitme-story. The new `/design-system` route's Part 2 (the website-side showcase) needs to make each visible — either in a "Design heritage" section, inline alongside the token/component it touches, or via a "Decisions log" subsection. Source-tagged.

### From `globals.css` + audit history

| Decision | Source | Where to surface |
|---|---|---|
| **Contrast fix A-002 + A-018** — light-mode `--color-neutral-500` shifted from `#78716C` (4.16:1 fail) to `#5C5754` (≥4.7:1 pass) | `globals.css:35` comment | Inline note on the neutral-500 token swatch |
| **Dark-mode contrast overrides** — neutral-500/700, brand-indigo, brand-coral all shift to lighter shades to pass 4.5:1 on dark bg | `globals.css:58-68` | Per-token Light + Dark side-by-side already shows this; add caption |
| **Safari `<details>` chrome quirks** — disclosure triangle hidden + tap-highlight removed | `globals.css:84-99` | "Implementation notes" subsection on the Disclosure component card |
| **Prose code overflow** (audit T24) — `overflow-wrap: anywhere` for inline `<code>` in narrow viewports | `globals.css:111-114` | "Implementation notes" subsection on the prose typography card |
| **Editorial table mobile scroll** (audits CS-006 + CS-020 + R-009) — `display: block` + horizontal scroll | `globals.css:129-173` | "Implementation notes" subsection on the prose table example |

### From `/design-system/page.tsx` (existing iOS narration in Part 1)

| Decision | Source |
|---|---|
| **13 principles list** — "Clarity over cleverness", "Touch affordances above 44pt", … | `page.tsx:14-28` |
| **Onboarding flow alt-text audit** (A-014) — `alt` is content-describing, not just title | `page.tsx:30-32` comment |
| **6 onboarding screens + 4 live app screens** with full alt text + caption grammar | `page.tsx:33-97` |
| **Pipeline diagram** — `tokens.json` → Style Dictionary → `DesignTokens.swift` → CI gate | `page.tsx:302-316` |

### From `docs/design-system/ux-foundations.md`

| Principle category | Items |
|---|---|
| **8 universal heuristics** | Fitts's Law (44pt+), Hick's Law (max 5-7 options), Jakob's Law (iOS conventions), Progressive Disclosure, Recognition over Recall, Consistency, Feedback, Error Prevention |
| **5 FitMe-specific principles** | Readiness-First, Zero-Friction Logging, Privacy by Default, Progressive Profiling, Celebration Not Guilt |

These already feed Part 1's PRINCIPLES list (13 entries). The showcase Part 2 should NOT re-list them — instead, link to the canonical doc.

### From audit synthesis (`docs/research/2026-05-08-fitme-story-audit-synthesis.md`)

| Decision | Status |
|---|---|
| **6 P0 audit findings** (A-001 skip-to-content, A-002+A-018 contrast, V-004 mobile nav, CS-008 frontmatter chrome bimodal, CS-016 TimelineNav unused, CS-020 table overflow) | Resolved 2026-05-08 via PRs #59-#67 + FT2 #254 |
| **13 quick-win P1 fixes** | Resolved (same PRs) |
| **S1 — ArticleNav** (sticky TOC + scroll progress + prev/next) | LIVE on prod 2026-05-08 |
| **S2 — `buildMetadata()` for OG/JSON-LD** | LIVE (every route) |
| **S3 — callout component family** | LIVE (5 callouts) |
| **S4 — `rehype-pretty-code`** | LIVE |
| **S5 — `<MobileNav>` hamburger** | LIVE |

The showcase should reference these in a "Design heritage" subsection — past audit decisions whose fixes are now baseline.

### From case-study presentation refactor (`docs/case-studies/case-study-presentation-refactor-case-study.md`)

| Decision | Source |
|---|---|
| **Alternative A chrome locked 2026-04-28** — SummaryCard → DataKey → VisualAidResolver → KillCriterionBanner → DeferredItemsList → narrative body | Locked pattern |
| **17 visual-aid components** | `docs/design-system/case-study-visual-aid-catalog.md` |
| **Frontmatter audit** — 25/25 case studies backfilled with `tldr`, `key_numbers`, `visual_aid`, `honest_disclosures`, `kill_criteria` | Validator at `fitme-story/scripts/validate-frontmatter.ts` |

The showcase should surface the case-study chrome pattern as a "Composition" section — components composed for case-study consumption.

---

## §2 Backlog cross-references

Source: `/Volumes/DevSSD/FitTracker2/docs/product/backlog.md`

### Items this feature ENABLES or UNBLOCKS

| Backlog item | How this feature unblocks |
|---|---|
| **`SEARCH-1` — site-wide search on fitme-story** | Showcase route emits structured component metadata that can be indexed for search |
| **"Complete Figma design + architecture for both surfaces (iOS + fitme-story)"** | Showcase route + Code Connect mappings provide auditable web-component coverage; iOS-side parallel evolution remains a separately tracked item |
| **"Re-activate Code Connect publish when Figma seat/plan unblocks (added 2026-05-10)"** | Drift detection (Bucket D) provides the parity check that publish-readiness depends on |

### Items that DEPEND ON or are SHIPPED-AND-SURFACED by this feature

| Backlog item | Status | Relationship |
|---|---|---|
| **Case-Study Presentation Refactor** | SHIPPED 2026-04-28 (PR #146) | Showcase surfaces locked Alt A chrome + 17 visual aids |
| **Unified Control Center** | SHIPPED 2026-05-06 (PR #232) | Showcase documents control-room components (Bucket C T10-T12) |
| **fitme-story-public-enhancements rollup** | 23/24 SHIPPED | Foundation: 17 component node IDs + 33 token vars + Figma file + Code Connect mappings |
| **Framework Story Site** | LIVE (fitme-story.vercel.app) | Showcase is the natural public-facing inventory |
| **Public-site audit + 5-PR ship 2026-05-08** | SHIPPED | Showcase displays the post-audit baseline (6 P0s + 13 P1s resolved) |
| **UI-Audit Baseline Burndown** | SHIPPED 2026-04-24 (PR #139) | Showcase respects the hard ui-audit gate (P0=0 enforced) |

### Items NOT directly related

- iOS-side design system work (separate parallel evolution; tracked in `ios-code-connect-workflow.md`)
- Recovery biometrics, smart-reminders behavioral learning (unrelated AI features)
- Sentry/auth-runtime verification (infra)

---

## §3 Memory cross-references

Source: `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/MEMORY.md`

### Direct predecessors (this feature continues their lineage)

| Memory entry | Relationship |
|---|---|
| **`fitme-story-public-enhancements rollup — 23/24 done`** | This feature is the EXPLICIT next-phase evolution of the foundation laid by T18-T21 of the rollup |
| **`2026-05-09 Web Code Connect + iOS CC scaffold + case-study audit codified` — RESOLVED 2026-05-10** | All 4 pause-time PRs merged. Web Code Connect mappings (12 `.figma.tsx` files) are the foundation showcase reads from |
| **`code-connect-automation` — closed 2026-05-10** | Layer A+B+C automation shipped; T5 deferred (Figma scope blocker). No publish required for this feature; showcase works without |
| **`Public-site audit + 5-PR ship 2026-05-08`** | Predecessor: the audit findings that the showcase surfaces as baseline-resolved |

### Peer features (active or recently shipped that the showcase touches)

| Memory entry | Relationship |
|---|---|
| **`UCC — Wave 2 SHIPPED end-of-day 2026-05-05 (39/44, 89%)`** + `UCC FORMALLY CLOSED 2026-05-06` | Showcase documents control-room components powering /control-room/* |
| **`Case-Study Presentation — SHIPPED 2026-04-28`** | Showcase surfaces locked Alt A chrome |
| **`v7.8.1 cross-repo framework port 2026-05-09 — FULLY MERGED 2026-05-10`** | This feature operates under v7.8.2 gates |
| **`HADF version alignment — V7.0 across all surfaces — MERGED`** | Showcase respects framework version sources of truth |

### Baseline references

| Memory entry | Relationship |
|---|---|
| **`UI-Audit Baseline Burndown — MERGED 2026-04-24 via PR #139`** | Hard gate active in main; showcase respects + cites |
| **`fitme-story preview verify-blind-switch — RESOLVED 2026-05-08`** | Vercel preview workflow used to verify showcase before merge |

### Memory entries to ADD on completion

When this feature ships, add a memory entry:
- File: `project_fitme_story_website_design_system_shipped.md`
- Index line: `- [fitme-story website design system SHIPPED YYYY-MM-DD] — public /design-system route + N components mapped + drift detection live + dark-mode matrix + contribution doc. Continuation of fitme-story-public-enhancements rollup foundation.`

---

## §4 Post-feature site review (queued, not in scope)

Per user directive: "when design system is finished let's review the entire site under the design system lens and see what other enhancements needs to be made".

Queued as **Bucket H — Post-feature holistic site audit** (NEW; tasks T31-T33). Does NOT block this feature's PR merge. Triggered post-merge:

- **T31** — Walk every fitme-story route (`/`, `/case-studies`, `/case-studies/[slug]`, `/glossary`, `/framework`, `/framework/dispatch`, `/framework/dev-guide`, `/timeline/[version]`, `/research`, `/trust`, `/about`, `/pm-flow`, `/control-room/*`) and check against the now-completed design system. Capture findings as `docs/research/{date}-fitme-story-design-system-lens-audit.md`.
- **T32** — Triage findings by P0 / P1 / P2; file each as a backlog item or open follow-up PRs.
- **T33** — Update `MEMORY.md` with the audit synthesis + open follow-up tracker.

This work is intentionally **DEFERRED until after** the showcase route + drift detection ship. Doing it before would surface findings that are pending fixes from this feature's own work.

---

## §5 Summary

This feature is the **next-phase evolution** of the fitme-story website's design system, building on:
- **17 Figma component node IDs** + 12 `.figma.tsx` mappings (rollup T20)
- **33 Figma token variables** (rollup T19)
- **`docs/design-system/fitme-story-design-architecture.md`** (rollup T21)
- **6 P0 + 13 P1 audit fixes** shipped 2026-05-08
- **Locked case-study Alt A chrome** + 17 visual aids
- **ArticleNav, MobileNav, callouts, prose styling** baseline

It produces:
- **51 Figma variables** (collection grew 36 → 51 in Bucket A) — motion + elevation + z-index added
- **31-component manifest** (Bucket B T4) — 12 Figma-mapped + 19 unmapped (Bucket C closes the gap)
- **`/design-system` Part 2 showcase** (Bucket B T6)
- **Drift detection** (Bucket D)
- **Dark-mode parity matrix** (Bucket E)
- **Contribution guidelines** (Bucket F)
- **Post-feature site audit** (NEW Bucket H)
