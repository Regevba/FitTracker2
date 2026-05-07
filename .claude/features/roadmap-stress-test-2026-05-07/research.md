# Phase 0 Research — `roadmap-stress-test-2026-05-07`

**This artifact is the sequenced roadmap.** It was produced inline in chat just before the experiment opened, then copied here as the canonical research output for v7.8.1 protocol compliance.

---

## The 9-step sequence

| # | Feature | Status today | DS Residual bundled in | Why bundle |
|---|---|---|---|---|
| **S1** | `app-store-assets` | paused implementation · FIT-17 | **Figma old frame cleanup (start)** | Marketing screenshots require clean Figma source-of-truth frames. |
| **S2** | `onboarding-v2-retroactive` refactor into `v2/` subdir | per V2 Rule "Backward compat note" | **9 raw literals (onboarding subset)** + **VoiceOver labels (start)** | Migrating onboarding to `v2/` is fix-as-you-touch + critical a11y surface. |
| **S3** | Refine case-study presentation/readability | open | _(none — pure content/MDX)_ | fitme-story side, no iOS DS surface. |
| **S4** | Code Connect (Figma ↔ code mapping) for iOS Figma | open | **Figma old frame cleanup (finish)** | Code Connect requires 1:1 mapping; stale frames must go. |
| **S5** | Research mode: complete Figma design + architecture for BOTH surfaces | open · Phase 0 only | **Android token output for Style Dictionary** | Architecture doc designs the unified iOS/Android/Web pipeline. |
| **S6** | Readiness-Aware Training Alert (Smart Reminders v2 layer) | open · Enhancement | _(fix-as-you-touch raw literals)_ | AI avatar + AIInsightCard touch areas may surface drift. |
| **S7** | Smart Reminders ↔ PN v2 deep-link integration | open · Enhancement | _(none)_ | Pure platform-infrastructure adaptation. |
| **S8** | Medium Priority UX (light → hard) | 11 items | **VoiceOver labels (finish)** + **9 raw literals (sweep)** | Dark Mode E2E + Dynamic Type + VoiceOver = a11y sprint sub-bucket. |
| **S9** | Low Priority sweep | 12 items | **9 raw literals (final catchall)** | Final sweep through any remaining drift. |

## Step 8 — Medium Priority sub-sequence (light → hard)

| Sub-step | Item | Effort |
|---|---|---|
| 8a | Chart goal target lines | light |
| 8b | Chart tap-to-tooltip | light |
| 8c | Notification settings UI | light |
| 8d | CSV data export from Settings | light |
| 8e | Trend alerts (HRV drop ≥3d) | light · partially superseded by S6 |
| 8f | User feedback loop for AI | medium |
| 8g | Exercise search/filter | medium |
| 8h | **A11y sprint**: Dark Mode E2E + Dynamic Type + VoiceOver | medium · bundled |
| 8i | Training program customization | hard · partially redundant with Import Training Plan |

## Step 9 — Low Priority order (smallest blast radius first)

Chart export/share → chart compare mode → 1RM calc → supersets/circuits → custom exercises → meal timing → photo food logging → AI meal suggestions → Watch complication → widgets → iPad/macOS → no-passcode-fallback. Phone OTP stays explicitly deferred.

## DS Residuals cross-reference

| Residual | Where it gets cleared |
|---|---|
| **9 raw literals across views** | S2 (onboarding) → S8h (a11y sweep) → S9 (final catchall) |
| **Android token output for Style Dictionary** | S5 (architecture doc) |
| **VoiceOver labels comprehensive audit** | S2 (start) → S8h (finish) |
| **Figma old frame cleanup** | S1 (start, marketing prune) → S4 (finish, Code Connect cleanup) |

## Time estimate (sum of per-step estimates from the roadmap)

| Step | Effort |
|---|---|
| S1 | ~1 week |
| S2 | ~3 days |
| S3 | ~1 week |
| S4 | ~3 days |
| S5 | ~1 week (research only) |
| S6 | ~1 week |
| S7 | ~3 days |
| S8 | ~3 weeks |
| S9 | ~2 weeks |
| **Total** | **~10 weeks** end-to-end |

S1–S5 are the highest-leverage cluster (~3.5 weeks); S6–S9 are incremental polish.

## Sources

- Original chat-rendered roadmap (2026-05-07 ~21:25 IDT, chat thread)
- Open backlog: [`docs/product/backlog.md`](../../../docs/product/backlog.md) (post PR #252)
- v7.8.1 protocol gates: [CLAUDE.md → Data Integrity Framework](../../../CLAUDE.md)
- Baseline: [`ucc-passkey-auth` case study](../../../docs/case-studies/ucc-passkey-auth-case-study.md) (~125 min, 9 phase transitions, 28 tasks)

## Decision

Run all 9 steps as serial sub-features within a single meta-feature (`roadmap-stress-test-2026-05-07`). Each sub-feature follows the v7.8.1 protocol independently (its own state.json, isolated worktree if it touches infra, Tier 2.2 logging, FEATURE_CLOSURE_COMPLETENESS gate at Phase 8). The meta-feature itself opts out of Mode C isolation (Q3 override, documented in state.json) because nesting isolated worktrees inside isolated worktrees creates excessive complexity without protocol benefit.

The experiment measures THROUGHPUT (sub-features completed per session) and PROTOCOL OVERHEAD (% of step duration spent on Tier 2.2 + state.json + pre-commit fixups), not 10-week completion.
