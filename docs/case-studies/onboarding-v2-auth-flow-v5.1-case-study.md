# Case Study: Onboarding v2 Auth Flow — v5.1

**Date written:** 2026-04-15
<!-- doc-debt-backfill: fields added by scripts/backfill-case-study-fields.py -->

| Field | Value |
|---|---|
| Dispatch Pattern | serial |

**Success Metrics:** TODO: review <!-- TODO: review -->


> **Core question:** How did framework v5.1 handle a feature that required full PM lifecycle + multiple design iteration cycles from manual testing?

---

## 1. Summary Card

| Field | Value |
|-------|-------|
| **Feature** | Onboarding v2 Auth Flow — Embedded Account Creation |
| **Framework Version** | v5.1 |
| **Work Type** | Feature (full 10-phase lifecycle) |
| **Complexity** | Files created: 3, Files modified: 12, Tasks: 12 + 6 post-merge fixes |
| **Wall Time** | ~3h (single session, research through design lock) |
| **Tests** | 197-198 (all pass, 0 regressions) |
| **Analytics Events** | 5 new + 4 new params |
| **Design Iterations** | 3 (initial → manual test fixes → design lock) |
| **Headline** | "Full PM lifecycle + 3 design iterations in single session — first feature with real runtime testing" |

---

## 2. Raw Data

### Phase Timing

| Phase | Duration | Notes |
|-------|----------|-------|
| 0. Research | ~5min | Competitive analysis (Duolingo, Headspace, Noom), current flow audit, 8-step proposal |
| 1. PRD | ~5min | 10 requirements, 5 GA4 events, kill criteria, analytics spec |
| 2. Tasks | ~3min | 12 tasks with dependency graph, big.LITTLE classification |
| 3. UX Spec | ~5min | 2 new screens, 10 principles applied, design system compliance |
| 4. Implement | ~15min | All 12 tasks, 11 files, 627 insertions |
| 5. Test | ~3min | 198 tests pass, 0 failures |
| 6-7. Review + Merge | ~2min | PR #80 merged to main |
| 8. Docs | ~2min | Case study entry opened |
| **Post-merge: Manual testing** | ~30min | 6 issues found and fixed |
| **Post-merge: Design iterations** | ~30min | 3 rounds of visual polish |
| **Total** | **~100min** | Single session |

### Implementation Commits (chronological)

| Commit | Description |
|---|---|
| `0fab2c4` | Initial implementation — 12 tasks, 2 new views, session restore fix |
| `99017da` | Fix #1 (pin CTAs), #3 (password manager), #4 (email registration), #6 (skip) |
| `403a7e2` | Fix #2 (icon), merge success+first action, fix flow wiring |
| `d07c40a` | Pin Welcome CTA, improve icon to match Figma layout |
| `b144526` | Replace SwiftUI icon with Figma PDF asset |
| `01986e5` | Rename icon asset, clean up duplicates |
| `70a91d0` | Welcome screen — blue bg, orange icon+text+CTA |
| `304252a` | Icon template mode — orange gradient shape only |

### Issues Found in Manual Testing

| # | Issue | Severity | Fix |
|---|---|---|---|
| 1 | CTAs not pinned to bottom | High | Extracted from ScrollView into pinned VStack on all views |
| 2 | Logo gradient wrong + not sharp | High | Replaced SwiftUI approximation with Figma PDF asset |
| 3 | No password manager support | Medium | Already handled by SecureField + textContentType |
| 4 | Email registration broken | Critical | Added inline verification code entry (old flow navigated to removed AuthHubView) |
| 5 | Apple Sign In not configured | Deferred | Needs Apple Developer Services ID |
| 6 | No "Skip for now" option | High | Added skip button + guest mode flow |
| 7 | Locked features for guests | Deferred | Separate Enhancement feature |

---

## 3. Analysis

### Level 1 — Per-Phase Performance

| Phase | Time | Key Finding |
|---|---|---|
| Research | 5min | Competitive analysis drove the "auth mid-flow" decision immediately |
| PRD | 5min | Analytics spec completed inline — no separate pass needed |
| Tasks | 3min | 12 tasks classified via big.LITTLE in under 3 minutes |
| UX Spec | 5min | Design system compliance passed on first check — no violations |
| Implementation | 15min | All 12 tasks in one pass. Fastest feature implementation in project history. |
| Manual Testing | 30min | 6 issues found — this was the **first real runtime test** with Supabase credentials |
| Design Polish | 30min | 3 iterations to lock visual design. Icon was the biggest challenge. |

### Level 2 — Cross-Phase Interaction

| Dimension | Finding |
|---|---|
| **Planning → Implementation gap** | Zero — UX spec translated directly to code. No ambiguity. |
| **Implementation → Testing gap** | Critical — email registration was broken because it tried to navigate to the removed AuthHubView. This was undetectable without runtime testing. |
| **Testing → Design loop** | 3 iterations needed. The PM workflow doesn't model iterative design cycles — it treats implementation as a single pass. This feature revealed the need for a "design review" phase between implementation and testing. |

### Level 3 — Framework Performance

| Metric | This Feature (v5.1) | Best Prior (v4.2) | Notes |
|---|---|---|---|
| Planning time (R→T) | 18min | 15min (AI Engine Arch) | Comparable |
| Implementation time | 15min | 35min (AI Engine Arch) | Faster (fewer files, but 2 new views) |
| Post-merge fixes | 6 issues, 30min | 0 issues (AI Engine Arch) | First feature with runtime testing — expected |
| Design iterations | 3 rounds, 30min | 0 (AI Engine Arch) | First feature with UI-heavy manual testing |
| Total wall time | ~100min | ~90min (AI Engine Arch) | +10min for design iterations |
| Files changed | 15 total | 17 (AI Engine Arch) | Similar scope |

---

## 4. Normalized Velocity

> Methodology: `docs/case-studies/normalization-framework.md`
> CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))

**This Feature:**
- Tasks: 18 (12 planned + 6 post-merge fixes), Work type: feature (1.0)
- Factors: UI (+0.3) + Auth (+0.5) + Runtime Testing (+0.4) + Design Iterations 3× (+0.45) = +1.65
- **CU = 18 × 1.0 × 2.65 = 47.7**
- Wall time: 100 min
- **min/CU = 2.1**
- **Rank: 1st (best ever)**
- **vs Baseline (v2.0): +86% faster**

### Cross-Version Comparison (Normalized)

| Feature | Version | Type | Wall Time | CU | min/CU | vs Baseline |
|---|---|---|---|---|---|---|
| Onboarding v2 | v2.0 | refactor | 6.5h | 25.7 | 15.2 | Baseline |
| Training v2 | v4.0 | refactor | 5h | 18.7 | 16.0 | -5% |
| Nutrition v2 | v4.1 | refactor | 2h | 16.4 | 7.3 | +52% |
| Stats v2 | v4.1 | refactor | 1.5h | 11.7 | 7.7 | +49% |
| Settings v2 | v4.1 | refactor | 1h | 7.0 | 8.6 | +43% |
| AI Rec UI | v4.2 | feature | 0.7h | 7.8 | 5.4 | +64% |
| Profile | v4.4 | feature | 2h | 16.9 | 7.1 | +53% |
| AI Engine Arch | v5.1 | enhancement | 1.5h | 17.7 | 5.1 | +66% |
| **Onboarding Auth** | **v5.1** | **feature** | **~1.7h** | **47.7** | **2.1** | **+86%** |

---

## 5. Success & Failure Cases

### What Worked

| # | Success | Evidence |
|---|---|---|
| 1 | **Full PM lifecycle in single session** | Research → PRD → Tasks → UX → Implement → Test → Merge → Design Polish — all in ~100min |
| 2 | **Competitive research drove correct architecture** | "Auth mid-flow" pattern from Duolingo/Headspace validated immediately during manual testing |
| 3 | **Session restore freeze fixed** | Detached task + 5s timeout. First successful real Supabase auth in the project. |
| 4 | **Figma MCP integration for icon** | Connected Figma, extracted design context, identified that SwiftUI can't replicate the icon, exported PDF — all within the session |
| 5 | **Design iteration velocity** | 3 rounds of visual changes (bg swap, icon rendering, CTA styling) committed and tested in ~30min |

### What Broke Down

| # | Failure | Evidence | Impact |
|---|---|---|---|
| 1 | **Email registration broken** | `startEmailRegistration` navigated to removed AuthHubView. Undetectable without runtime testing. | Critical — blocked entire email auth flow |
| 2 | **Icon invisible on orange bg** | SwiftUI circle strokes used warm colors that blended into brand gradient. | Required 3 iterations to resolve (color flip → PDF → template mode) |
| 3 | **No design iteration model in PM workflow** | The 10-phase lifecycle treats implementation as a single pass. Manual testing revealed 6 issues that required iterative fixes, not captured in the original task breakdown. | ~60min of unplanned work |
| 4 | **Supabase consolidation confusion** | Two Supabase projects existed. Had to backtrack after consolidating into the wrong one initially. | ~15min wasted |

---

## 6. Framework Improvement Signals

### Process Gap: Design Review Iteration

The PM workflow assumes: Implement → Test → Merge. But this feature revealed a loop: **Implement → Manual Test → Find Issues → Fix → Re-test → Design Iterate → Lock**.

**Recommendation:** Add an optional "Design Review" sub-phase between Implementation and Testing for UI features. This sub-phase is iterative (can loop) and produces a "design locked" artifact before advancing to formal testing.

### Anti-Patterns Discovered

- **Navigating to removed views** — when AuthHubView was removed from rootView, the email registration flow still tried to push to it via `navigationPath`. This is a class of bug where removing a view breaks invisible references.
- **Testing without runtime credentials** — compile-verification is necessary but insufficient for auth features. The project needs a "runtime test" gate for features that depend on external services.

### Cache Entries to Promote

- **CTA pinning pattern** (VStack + ScrollView + pinned bottom) — should become an L2 cache entry. Used across 5+ onboarding screens and applicable to any scrollable screen with a primary action.
- **Figma PDF asset pattern** — when SwiftUI can't replicate a design, export as PDF and use Image(). Should be L1 cache for `/design`.

---

## 7. Key Finding

**First real runtime test exposed a class of bugs invisible to compile-verification.** The email registration flow was broken because it navigated to a view that no longer existed in the view hierarchy. This could only be discovered by running the app with real Supabase credentials and tapping through the flow. The PM workflow's Testing phase (Phase 5) focuses on CI/unit tests — it needs a manual testing checkpoint for features with external service dependencies.

**Design iteration is not modeled but essential.** Three rounds of visual changes were needed to lock the Welcome screen design. The PM workflow treats implementation as a single pass, but UI features naturally require iterative refinement after seeing the result on-device. This isn't a bug in the framework — it's a gap that should be explicitly acknowledged and supported.

---

## 8. Methodology Notes

### Data Sources
- `state.json` — phase timestamps, task completion
- `git log` — 8 implementation commits, PR #80
- Session observations — manual testing issues, design iterations
- Figma MCP — icon export and design context

### Limitations
- Single practitioner
- Single session — no context reload penalty
- First feature with real Supabase credentials — comparison to prior features is imperfect
- Design iterations were unplanned — timing is approximate
