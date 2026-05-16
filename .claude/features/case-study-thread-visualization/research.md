# Research — case-study-thread-visualization

**Phase:** 0 (Research & Discovery)
**Date opened:** 2026-05-16
**Brainstorm:** see `state.json.brainstorm` (problem / solution / assumptions / strategy modes documented)
**Cluster catalog source:** Explore agent enumeration 2026-05-16, full inventory in §3 below

---

## 1. What is this solution?

A visual timeline thread that renders multi-part case-study series as a connected horizontal flow on the fitme-story public site. When a case study belongs to a series (e.g., UCC = 4 parts spanning v4.3 → v7.8.1), the listing page renders the entire series as a single timeline component (nodes = parts, edge = chronological progression). When a reader clicks into any part, the same timeline appears at the top of the detail page with a "you are here" marker indicating their position in the series.

The primitive is a new `series_id` frontmatter field + a typed catalog of all series + a `Timeline` component + listing/detail page integration. FT2-only case studies that belong to a public-facing series get backfilled as new fitme-story MDX showcases so each series renders complete on the public site.

---

## 2. Why this approach?

### Problem (from brainstorm)

When a project ships across multiple case studies, readers see them as disconnected items in a flat listing. The progression from one part to the next is invisible at the listing level; readers must click into individual studies and manually trace prose mentions to discover the thread.

**Evidence:**
- fitme-story [`content-schema.ts:77`](https://github.com/Regevba/fitme-story/blob/main/src/lib/content-schema.ts) has an unused `related: z.array(z.string()).optional()` field — someone designed for related-linking but no MDX file populates it.
- Listing page [`case-studies/page.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/app/case-studies/page.tsx) groups only by hardcoded milestones + era buckets + v7 slug-regex categories. **Zero cross-feature/project grouping exists.**
- UCC thread today is invisible to readers: slot `23a` (UCC migration) and slot `26` (UCC passkey) appear 3 slots apart with no connection cue. Other clusters even more so — the framework-v7 chain spans 12 case studies across slots `21`–`33`.

### Reach

Conservative estimate from cluster catalog (§3): **63 case studies belong to clusters with ≥2 members** — that's 63/87 ≈ **72% of published case studies** are in a series, currently rendered as if standalone.

---

## 3. Cluster catalog (Phase 0 deliverable)

Full enumeration produced by Explore agent 2026-05-16. **87 case studies total** (73 FT2 active + 73 fitme-story); 24 are standalone (templates, meta-docs, orphan pre-rule features, audit-family). **22 clusters identified**, 17 are cross-repo.

### 3.1 Cross-repo clusters (≥1 fitme-story member — visible to public)

| Series ID | Parts | FT2 members | fitme-story members | Backfill needed? |
|---|---|---|---|---|
| `ucc` | 6 | 4 | 2 (23a + 26) | NO — both halves represented |
| `hadf` | 4 | 2 | 2 (12 + 22b) | YES — `hadf-hardware-aware-dispatch` Phase 1 needs FT2 backfill clarity |
| `smart-reminders` | 4 | 2 | 2 (08a + 23) | NO — both backfilled |
| `training-plan` | 4 | 2 | 2 (19a + 23b) | NO — both backfilled |
| `onboarding-v2` | 3 | 2 | 1 (06) | YES — `onboarding-v2-retroactive` needs MDX |
| `push-notifications` | 3 | 2 | 1 (23c) | YES — v1 partial-ship case study needs MDX |
| `authentication` | 2 | 1 | 1 (22d) | NO |
| `home-today-screen` | 2 | 1 | 1 (18a) | NO |
| `stats` | 2 | 1 | 1 (22c) | NO |
| `framework-v7` (mega) | 12 | 7 | 5 (22, 22a, 23, 25, 29) | **AMBIGUOUS — see decision point 2** |
| `ui-audit` | 8 | 5 | 4 (20a, 28, 31, 33) | NO — recent additions cover all phases |
| `design-system-sweep` | 7 | 4 | 3 (27, 30, 32) | YES — original `fitme-story-website-design-system` predates 27 |
| `ai-engine` | 2 | 1 | 1 (07) | NO |
| `android` | 2 | 1 | 1 (24a) | NO |
| `gdpr` | 2 | 1 | 1 (24b) | NO |
| `google-analytics` | 2 | 1 | 1 (24c) | NO |
| `eval-driven` | 2 | 1 | 1 (03) | NO |
| `user-profile` | 2 | 1 | 1 (04) | NO |
| `parallel-write-safety` | 2 | 1 | 1 (10) | NO |
| `parallel-stress-test` | 2 | 1 | 1 (08) | NO |
| `measurement-v6` | 2 | 1 | 1 (11) | NO |
| `framework-history` | 15 | 5 | 15 (01, 02, 05, 09, 13–17, 18–20, 21, 21a) | NO — fitme-story is canonical |
| `roundup` | 2 | 1 | 1 (24) | NO |

### 3.2 FT2-only clusters (no public showcase — internal infrastructure)

| Series ID | Parts | Members | Why FT2-only |
|---|---|---|---|
| `audit-program` | 10 | post-stress-test + remediation + 185-findings + audit-v2 G1-G6 | Internal QA workstream, not externally narratively interesting |
| `pm-infrastructure` | 3 | pm-workflow-evolution + pm-workflow-showcase + pm-workflow-skill | Doc files, not case studies per se |
| `orchid` | 2 | orchid-ai-accelerator + orchid-v1-5-additive-units | Pre-rule, sparse metadata, not yet decided whether to backfill |

### 3.3 Standalone (no cluster)

24 files including templates (`case-study-template.md`), meta-docs (`framework-honesty-ledger.md`, `data-quality-tiers.md`, `dual-outlet-pattern.md`, `normalization-framework.md`), one outdated study (`original-readme-redesign-case-study.md`), and 2 orphan studies (`integrity-cycle-v7.1`, `case-study-presentation-refactor`). The `framework-history` series acts as the "meta" home for orphan-ish narrative pieces in fitme-story.

### 3.4 Naming convention proposed

- kebab-case series IDs
- Stable across schema versions (i.e., don't rename `ucc` to `unified-control-center` later — readers cite by URL slug pattern)
- Series titles (human-readable) live in the typed catalog separate from IDs
- Same series ID across both repos (FT2 case study and fitme-story showcase share `series_id: ucc`)

---

## 4. Why this over alternatives?

(See `state.json.brainstorm.solution.alternatives_considered` for full pros/cons.)

| Approach | Listing visibility | Detail visibility | Effort | Chosen? |
|---|---|---|---|---|
| **Option 1 — Series buckets + breadcrumb (compact)** | Series as single expandable card | Thin breadcrumb above article | ~1d | No (less visible) |
| **Option 2 — Visual timeline thread (prominent)** | Horizontal timeline rendering | Same timeline with "you are here" | ~2-3d | **YES** |
| Option 3 — Minimal: `related[]` + footer links | None (flat list unchanged) | Footer "related" block | ~2hr | No (post-click only) |

Option 2 chosen because the user explicitly prioritized **discoverability over compactness** — they want the thread visible at the listing level so multi-part progression is signaled BEFORE a click, not after.

---

## 5. External sources & inspirations

| Source | Pattern | How it applies |
|---|---|---|
| GitHub release pages (e.g., React releases) | Vertical version-by-version listing with continuity cues | Inspiration for "version markers" on timeline nodes |
| Apple newsroom / Tesla product timeline | Horizontal scrolling timelines with hero cards per stop | Visual treatment of timeline component |
| Stripe changelog | Grouped releases with TL;DR per stop | Per-node summary hover/focus state |
| Linear sub-project chains | Parent-issue + sub-issues with progression | Could inspire prev/next navigation |
| Next.js docs versioned learn track | Series-aware navigation with progress indicator | "You are here" pattern for detail page |

No direct API or library dependency — the timeline is hand-rolled with Tailwind/CSS + the existing fitme-story design system tokens. Considered using a generic timeline package; rejected because (a) the design system requires token compliance and (b) the component is small (~150 LOC estimated).

---

## 6. Data & demand signals

- **63/87 case studies (72%)** belong to a series — high latent demand for connection.
- **External audience signal:** the framework story site exists specifically to showcase the framework's evolution; threading is the natural next step on that arc.
- **GA4 signal:** existing case-study page views don't distinguish series members from solo studies, so we can't directly measure "did the reader navigate to the next part?" today. The feature is itself the instrumentation that enables this measurement.
- **Internal signal:** during the cluster enumeration, the agent had to manually piece together which studies belonged to which threads by reading prose and version numbers. A human reader is doing this same work today.

---

## 7. Technical feasibility

| Concern | Risk | Mitigation |
|---|---|---|
| Schema field rename later (`series_id` → `series_ids[]`) | Low — single field is forward-compatible to array via codec | Ship single-id v1; codec promotes to array if needed |
| Backfill consistency (manual MDX authoring drift) | Medium — 6-10 new MDX files prone to inconsistency | Reuse existing MDX frontmatter linter; add CI check that every `series_id` resolves to ≥2 members |
| Timeline component visual density (12-node framework-v7 chain) | High — won't fit cleanly on mobile | Phase 3 UX spec must address responsive layout: collapsed-by-default + max 5-7 visible nodes with horizontal scroll/paging |
| Performance — listing page render with 22 inline timelines | Medium — could add 50-200KB of SVG markup | Render timelines as static HTML (no client-side hydration); lazy-load below-the-fold |
| MDX frontmatter schema lock-in | Low — `series_id` is optional; existing studies unaffected | Schema additive only |

---

## 8. Proposed success metrics (draft for PRD)

| Metric | Type | Target | Why |
|---|---|---|---|
| **Primary:** % of case-study readers who click a series-timeline node to navigate within the same series | T1 (GA4 instrumented) | ≥5% within 30 days | Validates discoverability |
| Secondary: avg # of case studies viewed per session (pre/post baseline) | T1 (GA4) | +20% | Threading increases lateral exploration |
| Secondary: bounce rate on series-member detail pages | T1 (GA4) | -10% | "Where to next" reduces dead-end |
| Secondary: # series with ≥1 reader navigation event in first 30 days | T1 (GA4) | ≥10 / 17 cross-repo series | Validates breadth not just one popular thread |
| Guardrail: listing page LCP | T1 (Vercel Speed Insights) | no regression vs baseline | Don't tank performance for the visual |
| Guardrail: a11y AXE score on listing | T1 (axe-core CI) | ≥ baseline | Timeline must be keyboard + screen-reader navigable |
| Kill criterion | — | If at 30 days post-ship ZERO navigation events recorded across ALL series, the feature fails its core hypothesis | See brainstorm.strategy.kill_criteria_seed |

---

## 9. Open questions / decision points for Phase 1 PRD

The brainstorm and cluster catalog surfaced **four decisions** that need user resolution before the PRD can be written. Each affects scope and downstream effort.

### Decision 1: Minimum cluster size

The catalog shows 22 clusters. **8 of those 22 are 2-member clusters** (authentication, home-today-screen, stats, ai-engine, android, gdpr, google-analytics, eval-driven, user-profile, parallel-write-safety, parallel-stress-test, measurement-v6, roundup). Threading them produces tiny timelines (just 2 nodes). Question: is a 2-node timeline worth rendering, or set a floor at ≥3?

| Floor | Clusters rendered | Notes |
|---|---|---|
| ≥2 | 22 clusters, 63 studies | Maximum coverage |
| ≥3 | ~9 clusters, ~50 studies | Major threads only (UCC, HADF, framework-v7, ui-audit, etc.) |
| ≥4 | ~7 clusters, ~45 studies | Only the most narratively rich threads |

### Decision 2: Framework-v7 mega-cluster

The agent flagged that "framework-v7" conflates two threads: HADF (product/infrastructure feature, v7.0) and the integrity/measurement saga (v7.5 → v7.8.3). The user's earlier "single 10-part chain" decision was based on memory estimates. Actual catalog shows:

- **HADF cluster** is already separate (4 members: 2 FT2 + 2 fitme-story)
- **framework-v7 cluster** has 12 members (7 FT2 + 5 fitme-story) covering v7.5 → v7.8.3
- Plus `data-integrity` standalone (`integrity-cycle-v7.1`) sits orphaned between v7.1 and v7.5

Options:
- **A — Single 12-part `framework-v7` chain v7.5→v7.8.3** (orig user decision, includes integrity-cycle-v7.1 as part 1)
- **B — Split: `hadf` (already 4 parts) + `framework-integrity` (v7.1, v7.5, v7.6, v7.7, v7.8, v7.8.1, v7.8.3 — 12 parts)** (agent recommendation; cleaner narratives)
- **C — Three-way: `hadf` + `framework-integrity-early` (v7.1-v7.7) + `framework-integrity-v7.8` (v7.8 patch series)**

### Decision 3: Backfill scope

Confirmed needed (from §3.1 NO→YES rows):
- `hadf-hardware-aware-dispatch` Phase 1 — public showcase missing
- `onboarding-v2-retroactive` — public showcase missing
- `push-notifications-v1` — public showcase missing
- `fitme-story-website-design-system-case-study` — orig FT2 case predates fitme-story 27

Optional / lower priority:
- `framework-story-site-case-study` — partially covered by fitme-story 14 already
- Audit family (10 case studies, internal-only by nature) — would add a 10-part "audit-program" thread to the public site if backfilled
- `orchid` (2 case studies, pre-rule sparse metadata)

| Backfill option | Effort | Total new MDXs |
|---|---|---|
| Just confirmed-needed (4 MDXs) | ~2-3h | 4 |
| + Lower-priority cross-repo (5 MDXs) | ~4-6h | 9 |
| + audit family + orchid (17 MDXs) | ~10-15h | 21 |

### Decision 4: Series naming

Three flavors candidate names exist for the same threads:
- Short / project-style: `ucc`, `hadf`, `ai-engine`
- Long / descriptive: `unified-control-center`, `hardware-aware-dispatch-framework`, `ai-engine-architecture`
- Hybrid: `framework-v7` vs `framework-integrity-v7` vs `framework-evolution-v7`

Convention will be locked into URL slugs and citations (e.g., if we ever surface `/case-studies/series/ucc` later). Question: short or long? Recommend **short** (URL-friendly + memorable + already aligns with how the team refers to them in memory + meetings).

---

## 10. Recommendation

Proceed to Phase 1 PRD with the following defaults (subject to user decisions on §9):

- **Min cluster size:** 3+ (renders 9 meaningful threads, skips 13 trivial 2-node ones)
- **Framework-v7 split:** Option B (separate `hadf` + `framework-integrity`)
- **Backfill scope:** confirmed-needed only (4 MDXs, ~2-3h)
- **Naming:** short IDs (`ucc`, `hadf`, `framework-integrity`)

This produces a focused v1 covering ~9 major series with high narrative density. 2-node clusters can be added in a v1.1 follow-up if the navigation event metric validates the primary hypothesis.

---

## 11. Decision log (input to Phase 1)

| # | Decision | Locked | Source |
|---|---|---|---|
| D1 | Visual approach: Option 2 (prominent timeline) | ✅ | Conversation 2026-05-16 |
| D2 | Scope: all identifiable clusters | ✅ (refined in §9 D1 above) | Conversation 2026-05-16 |
| D3 | FT2-only studies backfilled into fitme-story | ✅ (scope refined in §9 D3) | Conversation 2026-05-16 |
| D4 | Framework v7.X chain | ⚠️ revisit per §9 D2 (catalog refined the original decision) | Conversation 2026-05-16 + agent recommendation |
| D5 | Run via /pm-workflow as Feature | ✅ | Conversation 2026-05-16 |
| D6 | Sequencing: Phases 0-3 now, hard-pause before Phase 4 until 2026-05-22 | ✅ | Calibration window protection per cadence-followups C1 precedent |
| D7 | Min cluster size: **≥3 members** | ✅ 2026-05-16 | Resolves §9 D1 |
| D8 | Series naming: **hybrid** (short for projects, long for framework versions) | ✅ 2026-05-16 | Resolves §9 D4 |
| D9 | Framework split: **`hadf` + `framework-integrity-v7`** (split per agent recommendation) | ✅ 2026-05-16 | Resolves §9 D2; overrides earlier "single chain" |
| D10 | Backfill scope: **confirmed-needed only (4 MDXs)** — hadf P1 + onboarding-v2-retroactive + push-notifications-v1 + fitme-story-website-design-system-orig | ✅ 2026-05-16 | Resolves §9 D3 |

---

## 13. Final locked series catalog (post-decisions)

Filtered to ≥3 members, names per hybrid convention, framework-v7 split applied:

| Series ID | Title | Parts | Era | Backfill |
|---|---|---|---|---|
| `ucc` | Unified Control Center | 6 | v4.3 → v7.8.1 | none |
| `hadf` | Hardware-Aware Dispatch | 4 | v7.0 → v7.7 | +1 MDX (Phase 1 hadf-hardware-aware-dispatch) |
| `framework-integrity-v7` | Framework Integrity v7 | 12 | v7.1 → v7.8.3 | none |
| `ui-audit` | iOS UI Audit Burndown | 8 | v7.1 → v7.8.3 | none |
| `design-system-sweep` | fitme-story DS Sweep | 7 (4 FT2 + 3 fitme-story; 1 backfill needed) | v7.8.2 → v7.8.3 | +1 MDX (orig DS case study) |
| `framework-history` | Framework Evolution (pre-v7) | 15 | v2.0 → v6.x | none |
| `smart-reminders` | Smart Reminders | 4 | v5.1 → v7.8 | none |
| `training-plan` | Training Plan | 4 | v5.0 → v7.8 | none |
| `onboarding-v2` | Onboarding v2 | 3 | v5.1 | +1 MDX (retroactive) |
| `push-notifications` | Push Notifications | 3 | v7.8 | +1 MDX (v1 partial-ship) |

**Total: 10 series rendered, ~66 case studies threaded, 4 backfill MDXs needed.**

Skipped (2-member clusters per ≥3 floor): authentication, home-today-screen, stats, ai-engine, android, gdpr, google-analytics, eval-driven, user-profile, parallel-write-safety, parallel-stress-test, measurement-v6, roundup. These can be added in a v1.1 follow-up if `case_study_series_node_click` metric validates the primary hypothesis post-ship.

---

## 12. References

- Brainstorm output: `.claude/features/case-study-thread-visualization/state.json.brainstorm`
- Cluster catalog: §3 above (sourced from Explore agent enumeration 2026-05-16)
- fitme-story schema: [`src/lib/content-schema.ts:77`](https://github.com/Regevba/fitme-story/blob/main/src/lib/content-schema.ts)
- fitme-story listing: [`src/app/case-studies/page.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/app/case-studies/page.tsx)
- Infra master plan overlay: `docs/master-plan/infra-master-plan-2026-05-12.md` (no violations; sequencing locked)
- Cadence followups C1 precedent: `.claude/shared/must-have-cadence-followups.md` L133
