# Tasks — `roadmap-stress-test-2026-05-07`

> Human-readable mirror of `state.json::tasks[]`. The 9 entries here ARE the 9 roadmap sub-features. Each entry expands into its own full PM workflow when picked up.

---

## Sequence + DS Residual bundling

| ID | Sub-feature | Skill | Lane | cu_v2 | Effort | DS Residual bundled |
|---|---|---|---|---|---|---|
| **S1** | `app-store-assets` resume (paused implementation) | `/design` | P-core | 7 | ~5d | Figma old frame cleanup (start) |
| **S2** | `onboarding-v2-retroactive` refactor into `v2/` subdir | `/dev` | P-core | 6 | ~3d | 9 raw literals (onboarding subset) + VoiceOver labels (start) |
| **S3** | Refine case-study presentation/readability | `/design` | P-core | 5 | ~5d | _(none — pure content/MDX)_ |
| **S4** | Code Connect (Figma ↔ code mapping, iOS) | `/design` | P-core | 6 | ~3d | Figma old frame cleanup (finish) |
| **S5** | Research: complete Figma design + arch for both surfaces (Phase 0 only) | `/research` | P-core | 8 | ~5d | Android token output for Style Dictionary (architecture) |
| **S6** | Readiness-Aware Training Alert (Smart Reminders v2 layer) | `/dev` | P-core | 7 | ~5d | _(fix-as-you-touch raw literals)_ |
| **S7** | Smart Reminders ↔ PN v2 deep-link integration | `/dev` | P-core | 5 | ~3d | _(none — platform infra)_ |
| **S8** | Medium Priority UX (light → hard, includes a11y sprint) | `/dev` | P-core | 8 | ~15d | 9 raw literals (sweep) + VoiceOver labels (finish) |
| **S9** | Low Priority sweep | `/dev` | E-core | 4 | ~10d | 9 raw literals (final catchall) |

**Total estimated effort:** ~10 calendar weeks (~54 person-days)
**Lane allocation:** 8 P-core + 1 E-core
**Critical path:** S1 → S2 → S3 → S4 → S5 (3.5 weeks); S6 → S7 → S8 → S9 (6 weeks parallel-eligible after S5)

## Dependency graph

```
                       S1 (app-store-assets)
                              │
                              ▼
                       S2 (onboarding v2/)
                              │
                              ▼
                       S3 (case study presentation)
                              │
                              ▼
                       S4 (Code Connect)
                              │
                              ▼
                       S5 (Figma research)
                          /        \
                         ▼          ▼
                  S6 (Readiness    S8 (Medium UX)
                    Alert)              │
                       │                ▼
                       ▼          S9 (Low Priority)
                  S7 (Smart
                    Reminders ↔
                    PN v2)
```

## Phase-2 dispatch order

The meta-feature stays in serial mode (no parallel sub-feature execution within a single session) to keep the experiment measurable. Each sub-feature runs S1 → S9 in order. The case study captures wall time per sub-feature; the data-collection ledger captures structured per-phase metrics.

**Wave 1 (this session, target 3 sub-features):** S1 → S2 → S3
**Wave 2 (next session, depends on S1/S2/S3 outcomes):** S4 → S5
**Wave 3 (post-S5):** S6 → S7
**Wave 4 (long tail):** S8 → S9

## Per-sub-feature protocol

Each sub-feature runs the FULL v7.8.1 protocol independently:

1. Auto-isolate via `scripts/create-isolated-worktree.py` (sub-features each get their own worktree if they touch infra)
2. `/pm-workflow {sub-feature-slug}` — bootstraps state.json, research.md, prd.md, tasks.md
3. Phase 0 → 9 sequence per CLAUDE.md
4. `/ux preflight` + `/design preflight` if `has_ui = true`
5. `/ux pre-merge-review` + `/design pre-merge-review` at Phase 6
6. PR opened **but NOT auto-merged** per session feedback rule (`feedback_no_auto_merge_without_approval.md`)
7. Phase 8: case study + showcase MDX + state.json `current_phase: complete` (FEATURE_CLOSURE_COMPLETENESS gate satisfied)

## Halt + resume

If a sub-feature can't complete in remaining session capacity:

- Tier 2.2 log captures `phase_paused` event with reason
- `state.json::current_phase` stays at the in-flight phase
- Case study `§4` records the boundary
- Data-collection ledger `subfeatures[N].notes[]` records the stop reason
- Resume = next session reads the state.json + log + case study + ledger to pick up where it left off

## Tasks marked complete only via FEATURE_CLOSURE_COMPLETENESS

A sub-feature is `done` ONLY when its own state.json reaches `current_phase: complete` AND the v7.8.1 gate validates 7 frontmatter fields + Q7 kill_criteria_resolution + Q6 PR parity. Anything short of that = `partial`.

## Cross-references

- PRD: [`prd.md`](./prd.md) — pre-registered hypotheses + start-state baseline
- Research: [`research.md`](./research.md) — the canonical roadmap
- Live case study: [`docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md`](../../../docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md)
- Data-collection ledger: [`data-collection.json`](./data-collection.json)
- Backup: `~/Documents/FitTracker2-backups/2026-05-07-pre-roadmap-stress-test/`
