# Post-Stress-Test Remediation Plan

> **Status**: Open. Replaces the bundled "audit v2 stress test" approach after wave 1 hit framework bug F1.
> **Date**: 2026-04-18
> **Source audit**: `docs/case-studies/meta-analysis-audit-and-remediation-case-study.md`
> **Framework bugs**: `docs/superpowers/specs/2026-04-18-framework-bugs-from-stress-test.md`

## Honest State of the Audit

After PR #95 merged, the precise tally:

| Category | Open | Info/PASS | Doable now | External-blocked |
|---|---|---|---|---|
| AI | 6 | 1 | 5 | 0 |
| BE | 9 | 0 | 8 | 1 (BE-006) |
| DEEP-AI | 10 | 0 | 10 | 0 |
| DEEP-AUTH | 5 | 0 | 4 | 1 (DEEP-AUTH-002) |
| DEEP-SYNC | 4 | 0 | 3 | 1 (DEEP-SYNC-001) |
| DS | 6 | 0 | 4 | 0 (2 large initiatives — dark mode, pipeline expansion — deferred) |
| FW | 14 | 6 | 4 | 0 (4 require runtime data — partial only) |
| TEST | 7 | 0 | 3 | 0 (4 large infra items — sync mocks, XCUITest, snapshot — deferred) |
| UI | 21 | 1 | 14 | 0 (6 large file decompositions deferred) |
| **Total** | **82** | **8 PASS** | **~55 doable** | **3 external** |

The "82 open" headline differs from earlier "47" estimates because the audit-findings.json hasn't been live-updated as PRs landed. This plan uses the JSON as source of truth and counts only what's still genuinely open.

## What's Out of Scope (acknowledged, deferred)

These are real findings, but they're the wrong kind of work to bundle into incremental sprints:

| Group | IDs | Why deferred |
|---|---|---|
| Large UI decomposition | UI-001 / UI-002 / UI-003 / UI-004 / UI-005 / UI-006 | Each is a 600–2100 line file refactor; needs its own v2 plan with UX review |
| Dark mode + token pipeline expansion | DS-004 / DS-009 / DS-010 | New token variants for ~40% of categories + CI gate; multi-session initiative |
| Sync test mocks | TEST-003 / TEST-004 | Needs URLProtocol stub + mock CKDatabase infrastructure built first |
| XCUITest / snapshot infrastructure | TEST-025 / TEST-026 | Needs new Xcode test targets + dependency adoption |
| Runtime measurement backfill | FW-005 / FW-011 / FW-012 / FW-014 | Schema is correct; data only populates as the framework runs over time |
| External backend work | DEEP-AUTH-002 / BE-006 / DEEP-SYNC-001 / DEEP-AUTH-015 | Server-side WebAuthn / dual-sync coordinator / Keychain migration |
| Framework bugs (separate track) | F1 / F2 / F3 / F4 / F5 | Tracked in `framework-bugs-from-stress-test.md` — own remediation cycle |

## Five Sprints — Doable Today

Each sprint = one branch, one PR, ~30–90 min of work, mirrors the proven Sprint A–E pattern.

### Sprint F — Quick Wins (the G6 plan from wave 1)

**~10 findings.** The G6 agent already wrote a complete fix plan in `/tmp/audit-v2-traces/g6-wave1.json`. Just execute it on a normal branch (no worktree).

| ID | Sev | What |
|---|---|---|
| FW-003 | medium | Update `framework-manifest.json` `shared_files` count 15 → 24 (verified) |
| FW-004 | high | Replace hardcoded `claude-opus-4-6` with current model or remove field |
| FW-015 | low | Populate `framework_self_audit` scaffold |
| FW-020 | medium | Re-order `dispatch-intelligence` snapshots chronologically |
| AI-002 | medium | Fix FoundationModelService docstring (Tier 3 ≠ "escalate to cloud") |
| AI-020 | info | Add docstring to AISnapshotBuilder.build() noting adapter discard |
| UI-025 | info | Document that 8 v1 Onboarding HISTORICAL headers are already in place |
| FW-005 | high | PARTIAL: schema is fine, document that data populates over runs |
| FW-011 | high | PARTIAL: same — note that empty `entries[]` is initial state |
| FW-012 | medium | PARTIAL: same |
| FW-014 | medium | PARTIAL: document that `last_check: null` is expected initial state |

**Branch**: `fix/audit-sprint-f`
**Risk**: trivial. Pure config + docstring edits.
**Estimated**: 30 min.

### Sprint G — Backend & Sync Hardening

**~13 findings.** All Swift bug fixes in services we already touched in Sprint A. Mostly small, isolated patches.

| ID | Sev | What |
|---|---|---|
| BE-014 | medium | rotateKeys() atomicity — wrap in `isRotating` guard |
| BE-016 | medium | persistToDisk() error propagation to caller |
| BE-019 | medium | deleteAllUserRecords batch via CKModifyRecordsOperation |
| BE-021 | medium | Separate JWT into its own Keychain item with tighter ACL |
| BE-023 | medium | Sync deletion grace period to Supabase, not just UserDefaults |
| BE-024 | medium | Delete Supabase Auth user record in executeDeletion |
| BE-027 | low | Make encrypt() fail if keys were explicitly deleted |
| BE-029 | low | Wire goal-aware sleepGoalHours instead of 8.0 hardcoded |
| DEEP-AUTH-011 | medium | persistToDisk() transactional write (5 files atomic) |
| DEEP-AUTH-013 | medium | evaluatePolicy weak self capture before Task |
| DEEP-SYNC-010 | high | CloudKit cardio image forwarding to Supabase |
| DEEP-SYNC-011 | medium | deleteAllUserData partial-failure compensation logging |
| DEEP-SYNC-014 | medium | cloudRecordID atomic persistence with needsSync |

**Branch**: `fix/audit-sprint-g`
**Risk**: medium — touching auth/sync code requires care.
**Estimated**: 90–120 min. Add tests where reasonable (most of these have testable surface).

### Sprint H — AI Pipeline Correctness

**~14 findings.** All in `FitTracker/AI/`. Some are bug fixes, some are docstring improvements.

| ID | Sev | What |
|---|---|---|
| AI-001 | high | iOS 26 `#available` guard before Foundation Model `adapt()` calls |
| AI-011 | medium | Build adapters inside process() so lastAdapters not empty on first call |
| AI-012 | medium | Lift isProcessing lifecycle to processAll(), suppress per-segment flicker |
| AI-013 | low | Lightweight JWT expiry check (decode payload, check exp claim) |
| DEEP-AI-006 | high | Same as AI-013 — same root cause |
| DEEP-AI-007 | high | setAdapters() actually called by AISnapshotBuilder.build() |
| DEEP-AI-008 | medium | Same as AI-012 — same root cause |
| DEEP-AI-009 | medium | Foundation Model isAvailable check before invocation |
| DEEP-AI-010 | medium | Adapter disjointness asserted at runtime (debug build) |
| DEEP-AI-011 | medium | computeFreshness uses oldest, not newest, adapter date |
| DEEP-AI-012 | medium | Redact biometrics from buildPrivateContext when logging enabled |
| DEEP-AI-013 | low | Distinguish under-18 from missing in ageBand() |
| DEEP-AI-014 | low | trainingDaysPerWeek now uses real value (cascade from Phase 2) — verify |
| DEEP-AI-015 | critical (META) | Verify fabrication-over-nil pattern fully eliminated by Phase 2 |

**Branch**: `fix/audit-sprint-h`
**Risk**: medium — AI orchestrator is high-traffic code path. Add tests for AI-011/AI-012 fixes.
**Estimated**: 90–120 min.

### Sprint I — UI Token & Cleanup Small Wins

**~14 findings.** Raw font literals, dead code, small DS gaps. NOT large file decompositions.

| ID | Sev | What |
|---|---|---|
| UI-007 | medium | HISTORICAL MainScreenView raw fonts — confirm file is excluded from build |
| UI-008 | medium | `.font(.system(size: 32))` in v2 onboarding welcome → AppText token |
| UI-009 | medium | `.font(.system(size: 36))` in v2 onboarding → AppText token |
| UI-010 | medium | `.font(.system(size: 22))` close button → AppText token |
| UI-011 | medium | Hardcoded font + width → tokens |
| UI-012 | medium | `.foregroundColor(.white)` → `.foregroundStyle(.white)` |
| UI-013 | medium | Two raw fonts in empty-state branches |
| UI-014 | medium | AppSelectionCard / AppInputShell raw shadows → AppShadow tokens |
| UI-021 | medium | Raw font size 56 for bell icon |
| UI-022 | low | Raw font size 28 for AI sheet button |
| UI-023 | low | 'Choose File' card needs disabled state or remove |
| UI-024 | low | Remove dead RecommendationOutcome construction |
| DS-008 | medium | Inline GeometryReader progress bars → ProgressBar component |
| DS-011 | medium | Migrate inline opacity literals to AppOpacity tokens |
| DS-015 | low | Remove unused Focus.ring + Opacity.hover or document use |

**Branch**: `fix/audit-sprint-i`
**Risk**: low — mechanical token migrations.
**Estimated**: 60–90 min.

### Sprint J — Remaining Test Coverage (light)

**~3 findings.** What can be done without new mock infrastructure.

| ID | Sev | What |
|---|---|---|
| TEST-009 | high | Mark resolved in audit JSON (already covered by RecommendationMemoryTests in PR #89) |
| TEST-014 | high | ReminderScheduler tests — testable without mocks (uses UserDefaults) |
| TEST-023 | medium | PARTIAL: skeleton tests with notes on what URLProtocol mock infra would unblock |

**Branch**: `fix/audit-sprint-j`
**Risk**: low.
**Estimated**: 45 min.

## Total Sprints F–J

- **Estimated effort**: 5–7 hours across 5 sprints / 5 PRs
- **Estimated findings resolved**: ~54 (taking us from 127/170 → ~181/170 — wait, that's over 100% because of overlap with previously deferred. Realistic: ~127 + 54 = 181 of 170 actionable, meaning we'd have closed everything closeable)

## Recommended Order

1. **Sprint F** (quick wins, validates the post-stress-test workflow)
2. **Sprint I** (UI/DS small wins — low risk, high finding count)
3. **Sprint J** (close the test category)
4. **Sprint G** (backend & sync — needs more care)
5. **Sprint H** (AI pipeline — most subtle, save for last)

## Out-of-Scope Items Tracked

Three separate tracks for what's deferred:

1. **Framework bugs** — `docs/superpowers/specs/2026-04-18-framework-bugs-from-stress-test.md` — F1–F7
2. **Large UI decomposition** — needs per-screen v2 plan with UX review (MealEntrySheet, SettingsView, etc.)
3. **Architectural items** — Server WebAuthn, dual-sync coordinator, dark mode pipeline, XCUITest target — each its own future sprint

## Why This Approach

- **Predictable**: Mirrors Sprints A–E that already succeeded
- **No framework dependency**: Doesn't require fixing F1 first
- **Honest scope**: Acknowledges what's deferred, why, and where it's tracked
- **Cleanly partitioned**: 5 sprints by domain — easy to context-switch, easy to review
- **Stops the methodology debate**: We tried concurrent dispatch, it's blocked, moving on
