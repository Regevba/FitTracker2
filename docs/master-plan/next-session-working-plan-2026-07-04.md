# Next-Session Working Plan — Advanceable Items Overlay

> **Generated:** 2026-07-04 · **Reconciled vs merged PRs:** 2026-07-05 · **Re-created on internal storage:** 2026-07-05 (post SSD-corruption migration).
> **Method:** overlay of all master/sub-plans x `docs/product/backlog.md` x Linear (FIT-*) x recent PRs (#823-#849) x every `.claude/features/*/state.json`.
> **Baseline:** integrity-check GREEN; FT2 has ZERO open PRs (housekeeping #845/#847/#840 merged).
> **START HERE next session:** run the verification block, then pick from the green list. Recommended first: #1 (F4 flip — DONE 2026-07-05, see note).
>
> **INFRA NOTE (2026-07-05):** the DevSSD (Crucial X10) suffered APFS `fsroot` corruption; the canonical checkout was re-cloned from origin to **internal storage** (`~/FitTracker2`). Nothing committed was lost (origin intact at #849). Update paths accordingly until CLAUDE.md's canonical-location note is revised.
>
> **RECONCILED 2026-07-05 vs merged PRs:** item #2 (R9 30-day coverage read) SHIPPED via #849 — struck. F4 (#1) PROMOTED to enforced 2026-07-05 (`chore/f4-version-stale-enforce`).

---

## START-HERE verification block (run first)

```bash
# from the repo root (now internal: ~/FitTracker2)
git fetch origin && git log --oneline -8 origin/main      # confirm nothing new landed since #849
make integrity-check 2>&1 | tail -8                        # confirm still green
grep -n "FRAMEWORK_VERSION_STALE_ADVISORY_MODE" scripts/check-state-schema.py   # F4: now False (enforced)
make crosswalk 2>&1 | tail -5                              # registry advisory (66 missing linear_id = by-design, DO NOT fabricate)
```

State-of-play: this week's merges (#835-#849) shipped FIT-152/155/156/157/163/164/181/183/185 + R9 coverage-read baseline (#849). Bucket-A batch is cleared; this plan is the next tier down.

---

## ADVANCEABLE NOW — unblocked dev work (ranked)

| # | Item | What & why now | Size | Source |
|---|---|---|---|---|
| ~~1~~ | ~~F4 FRAMEWORK_VERSION_STALE advisory->enforced flip~~ | **DONE 2026-07-05** — promoted on `chore/f4-version-stale-enforce` (all 4 kill criteria clear; 18-day window). Phase E validate 7d -> ~07-12. Consequence: next phase-advance of `3d-diagram` (v7.9.1) or `app-store-assets` (v5.0) will be BLOCKED until they bump to v7.10 or add `framework_version_stale_exempt`. | XS | infra sec 3.0 |
| ~~2~~ | ~~R9 Track B — 30-day coverage read~~ | **DONE — shipped #849 (2026-07-05)** as GATE_TEST_MISSING calibration baseline. Downstream T1 gate still date-locked to 2026-08-22. | — | test-coverage sec refresh |
| 3 | Dev-env Track B Makefile wiring (R7 lint-ios / R8 lint-py / R9 coverage-report / R12 lint-md + verify-local) | Producers shipped; operator-side Makefile targets + verify-local hookup is the open half. Needs isolated worktree (infra-glob touches Makefile). | M | dev-env master plan Track B |
| 4 | N6 — Quarterly Data Freshness Audit script | Tooling not built; first run due 2026-08-12. F17 gate-last-fired.json index makes it O(1). Build ahead of deadline. | M | infra sec 3.5.3 / FIT-101 |
| 5 | Small integrity/backup crons — DI-Q2 (auto 2nd snapshot on regression), DI-Q3 / FIT-206 (off-SSD shasum -c weekly cron), FIT-207 (cross-repo baseline capture in daily checkpoint) | Small, self-contained hardening. | S each | data-integrity sec 5 |
| 6 | 3D diagram (FIT-138) — advance tasks_phase | Confirmed tasks_phase, 0 tasks. NOTE: now that F4 is enforced, bump its framework_version to v7.10 when advancing. | S (PM phase) | post-v7.9 F-5 |
| 7 | E-1 / E-3 durable fixes — preflight parent_feature resolution; elevate auth_lockout_blocked_attempt to weekly digest. | S each | post-v7.9 sec 5 |
| 8 | ~~iOS product micro-features — FIT-208 (chart goal target lines), FIT-209 (chart tap-tooltip), FIT-210 (notif settings screen), FIT-211 (CSV export)~~ **✅ ALL SHIPPED 2026-07-09** (Linear Done). | S-M | Linear (filed 07-02) |

---

## Calendar-gated within ~10 days
- ~2026-07-12: F4 Phase E enforced-validation exit (watch for false-positive blocks).
- ~2026-07-13 (B16): CSV_TAXONOMY_DRIFT advisory->enforced review — needs >=7d coverage window.
- 2026-07-15: Pagefind site-wide-search feature target end (fitme-story).
- 2026-07-24: HADF Phase 2 external-audit T+60d decision.
- 2026-07-31: v8.0 ship target + V8-I1 concurrent-features trigger check.

---

## Operator-gated — needs the user, NOT a dev session
- FIT-202 — Supabase: enable RLS on cohort_stats + advisor SQL (High / security)
- FIT-203 — GA4: mark key events as conversions (D-2)
- FIT-204 — Submit fitme-story to Google Search Console + sitemap (P1.1/P1.2)
- FIT-66 — UCC cutover: flip UCC_AUTH_MODE basic->passkey (env flip)
- FIT-17 / FIT-134 — App Store assets + Apple Developer account
- D-4 — delete legacy com.regevba.FitTracker Firebase entry
- F19 / F20 — blocked on the GA4 operator actions above
- **NEW (2026-07-05): SSD repair/reformat** — DevSSD APFS fsroot corrupt; repair via Recovery First Aid or reformat + re-clone. Verify USB cable/port.

## Blocked / date-locked (do not attempt)
- T1 GATE_TEST_MISSING + F18 mutation testing — F14 Phase E -> 2026-08-22 (R9 baseline #849 now feeds it)
- F21 Sentry / T2 Sentry test / F23 /ops digest — App Store launch trigger
- T11 runtime-emission audit — needs F19 (operator GA4)
- Orchid v1.5 Track R — v1 SoC Phase 5 + Orchid toolchain
- External audits FIT-87/93/125/126 — operator-scheduled; FIT-201 flags overdue

---

## Drift to reconcile (housekeeping, not new scope)
1. Local stale dirs (on old SSD copy only): precommit-hook-latency-profiling, t16-gate-test-tier-annotation, weekly-digest-silent-gate-enrichment — complete on origin (#838). Clean internal clone already correct.
2. Doc-prose W40 stale-open: test-coverage master plan prose may still list T7/T8/T15/T16 as "open" but all shipped (#835/#839/#841/#842 + fs#256/#257). Re-check whether the master-plan prose needs a pass.
3. Registry: 66/124 features missing linear_id — by-design, non-blocking. Do NOT fabricate joins.

---

## Reconciliation notes (for trust)
- Linear open-issue count at capture: 71 (2 In Progress, 10 Todo, 59 Backlog). No hard W40 stale-opens surfaced.
- item-registry.json: 124 features, 58 with linear_id, 17 with thematic_codes.
- Only 6 features not at complete: the 3 stale-local chores (already complete on origin) + orchid-v1-5 (parked), app-store-assets (operator/external blocked), 3d-interactive-framework-flow-diagram (tasks_phase, empty).
- 2026-07-05: repo migrated off corrupt DevSSD to internal `~/FitTracker2` (clone from origin #849, fsck clean); local-only secrets (.vercel/.env.production.local, GoogleService-Info.plist) + telemetry (.claude/logs, _session-state, gh-pr-cache) rescued.
