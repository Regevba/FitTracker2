# FitMe (FitTracker2) — Project Rules

> **Canonical repo location:** `/Volumes/DevSSD/FitTracker2`
>
> The project lives on an external SSD at `/Volumes/DevSSD/FitTracker2`, not
> on the Mac's internal storage. All build artifacts (Xcode DerivedData, SPM
> cache, npm cache, Python venvs, clang module cache, simulator data) are
> kept under `.build/` inside the repo, which is already on the SSD. Any
> absolute paths in documentation, commit messages, handoffs, or scripts
> should reference `/Volumes/DevSSD/FitTracker2` when pointing at the local
> repo — never `/Users/{name}/` or `/tmp/`. Setup details live in
> `docs/setup/ssd-setup-guide.md`.
>
> Agents running in sandboxed environments may see a different working
> directory path (e.g. `/home/user/FitTracker2`). That's the sandbox mount
> of the repo, not the real location. Files written inside the sandbox are
> the user's real files, but human-readable paths in docs should always
> point at the SSD.

## Product Management Lifecycle

Every new feature MUST follow the PM workflow. Invoke with `/pm-workflow {feature-name}`.

**Phases:** Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs

**Non-negotiable rules:**
1. No phase is skipped. Every phase requires explicit user approval.
2. No PRD without success metrics. Every feature defines: primary metric, baseline, target, kill criteria.
3. No merge without CI. Both feature branch AND main must be green.
4. Data drives decisions. Research, metrics, and kill criteria guide the lifecycle.
5. Post-launch metrics review is mandatory at the cadence defined in the PRD.
6. Phase transitions auto-sync to GitHub Issue labels (dashboard updates automatically).
7. Manual overrides allowed — user can move features forward (skip) or backward (rollback) at any time. Skipped phases are recorded in the audit trail.
8. Conflicts between state.json and GitHub Issues are resolved by asking the user.

## Work Item Types

Not everything needs the full 9-phase funnel:
- **Feature** — Full lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs). New capabilities requiring research, PRD, design.
- **Enhancement** — 4-phase (Tasks → Implement → Test → Merge). Improvements to shipped features. Parent feature must already have a PRD.
- **Fix** — 2-phase (Implement → Test). Bug fixes, error handling, security patches.
- **Chore** — 1-phase (Implement). Docs, config, refactoring, dependency updates.

Use `/pm-workflow {name}` and select the work type. Skipped phases are recorded in the audit trail with reason `work_type:{type}`.

### Impact tier labels (B_medium, A_high, B_low, …)

Backlog rows + v7.9.1+ docket entries carry an **impact tier label** like `(cu_v2 ~1.8, B_medium)` alongside RICE. The tier label is a coarse sort key for "how much does this matter to the framework's load-bearing chain" — distinct from RICE (which scores effort vs. value for a single feature).

| Tier | What it means | Typical workflow shape |
|---|---|---|
| **A_high** | Load-bearing: change blocks something downstream that operators or framework consumers rely on. Schema changes, enforced-gate additions, public-API contracts, kill-criteria evaluations that gate a promotion. | Full `Feature` lifecycle; PRD + tasks + UX (if any) NOT optional; advisory→enforced calibration window mandatory for new gates. |
| **B_medium** | Important but not load-bearing: ergonomic improvements, doc clarifications, schema additions that are non-breaking, observability extensions, internal-tool enhancements where the downstream consumer is the framework itself. | `Enhancement` or **abbreviated `Feature`** — PRD optional (state.json + case study is enough for non-novel scope); UX phase optional (skip if no user-visible surface); skipped phases recorded as `work_type_subtype:b_medium_<reason>` audit-trail entry. |
| **B_low** | Hygiene, polish, doc nits, low-risk refactors of well-tested code. | `Chore` lifecycle. |

**Why this taxonomy:** before v7.9.1, the Feature/Enhancement/Fix/Chore taxonomy left an ambiguous middle for "this is bigger than a chore but doesn't need a PRD because the scope is mechanical (e.g. add a schema field + backfill)." Operators had to pick Feature (heavy) or Enhancement (technically requires parent PRD — which doesn't exist for net-new framework scaffolding). B_medium formalizes that middle: a `Feature` work_type with `work_subtype: b_medium` may skip PRD/tasks/UX phases as long as the skip reason is documented in `phases.<skipped>.skip_reason` per the existing skipped-phase audit-trail mechanism.

**Forward-only:** existing backlog rows with `B_medium` labels (e.g. the v8.x icebox style-dictionary v5 migration — since shipped 2026-06-08 via PR #677) retain their label. New work items use the table above to choose. Old rows are not retroactively re-labeled.

## Branching Strategy

- **Large features** (>5 files changed OR new models/services) → `feature/{name}` branch
- **Small fixes** (<5 files, no new models) → direct task branch
- **Before merge:** parallel code review — diff feature vs main, identify risk areas
- **CI requirement:** both branches must pass before merge is approved
- **High-risk areas** that require extra review: DomainModels.swift, EncryptionService.swift, SupabaseSyncService.swift, CloudKitSyncService.swift, SignInService.swift, AuthManager.swift, AIOrchestrator.swift

## Data Integrity Framework (v7.5 → v7.6 → v7.7 → v7.8 → v7.8.1 → v7.8.2 → v7.8.3 → v7.8.4 → v7.8.5 → v7.8.6 → v7.9, shipped 2026-04-24 → 2026-04-25 → 2026-04-27 → 2026-05-04 → 2026-05-07 → 2026-05-08 → 2026-05-11 → 2026-05-12 → 2026-05-13 → 2026-05-15 → 2026-05-21)

The 72h Integrity Cycle shipped at v7.1 is now one of **eight cooperating defenses** in the v7.5 Data Integrity Framework — triggered by the 2026-04-21 Google Gemini 2.5 Pro independent audit. v7.6 (Mechanical Enforcement, shipped 2026-04-25) closes the remaining Class B → Class A gap by promoting four silent agent-attention checks into pre-commit failures and adding two recurring CI defenses (per-PR review bot, weekly framework-status cron).

**Write-time gates (fire on `git commit`):**
- `SCHEMA_DRIFT` — pre-commit hook rejects legacy `phase` key; canonical is `current_phase`. Install via `make install-hooks`.
- `PR_NUMBER_UNRESOLVED` — pre-commit hook verifies `phases.merge.pr_number` against a cached `gh pr list` result before state.json can record it; skipped gracefully when `gh` is unavailable.
- `PHASE_TRANSITION_NO_LOG` (v7.6) — pre-commit hook rejects a `current_phase` change in a state.json without a corresponding event in `.claude/logs/<feature>.log.json` within the last 15 minutes.
- `PHASE_TRANSITION_NO_TIMING` (v7.6) — pre-commit hook rejects a `current_phase` change without `timing.phases.<new_phase>.started_at` and, when there was a previous phase, `timing.phases.<old_phase>.ended_at`. **T16 note (v7.7):** this hook means the timing-backfill scenario resolved by v7.7 T15 (push-notifications, import-training-plan, stats-v2 had zero timing coverage because they predated mechanical enforcement) will not recur for any feature created post-v7.6. The v7.7 T15 pass addresses pre-existing data debt only — no further backfill is required for features that advanced phases after 2026-04-25.
- `BROKEN_PR_CITATION` (v7.6, write-time) — pre-commit hook rejects case-study commits that cite `PR #N` or `pull/N` if the number does not resolve in the cached `gh pr list` result; skipped gracefully when `gh` is unavailable. Cycle-level `BROKEN_PR_CITATION` still runs as a safety net.
- `CASE_STUDY_MISSING_TIER_TAGS` (v7.6) — pre-commit hook rejects scoped case-study commits (forward-only, dated ≥ 2026-04-21) when the file has no T1/T2/T3 tier tag at all. It checks tag presence, not every quantitative claim.
- `ISOLATION_OPT_OUT_REASON_MISSING` (v7.8 framework-v7-8-branch-isolation, T1) — pre-commit hook rejects state.json with `isolation_opt_out: true` but empty `isolation_opt_out_reason`. Pairs with `BRANCH_ISOLATION_VIOLATION`'s per-feature opt-out (Q3).
- `BRANCH_ISOLATION_VIOLATION` (v7.8 framework-v7-8-branch-isolation, T6/T7, **enforced at v7.9 2026-05-21**) — two-mode gate. Mode B fires on every commit when staged files match infra-path globs (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`, OR feature has `work_subtype: framework_feature` or `work_type: chore`). Mode C fires on `state.json::current_phase` mutations from a non-feature branch. Auto-isolation flow dispatches `scripts/create-isolated-worktree.py` (or `superpowers:using-git-worktrees` skill in agent context) — creates the worktree at the smart-directory-selected path, links state.json, registers the lease in `.claude/shared/agent-leases.json`. Per-feature `isolation_opt_out: true` bypasses Mode C only; Mode B (infra) ignores it (Q3 override).
- `FEATURE_CLOSURE_COMPLETENESS` (v7.8 framework-v7-8-branch-isolation, T11-T14, **enforced at v7.9 2026-05-21**) — pre-commit hook fires on `current_phase=complete` transitions. Validates: (a) 7 required case-study frontmatter fields (`date_written` or `date`, `dispatch_pattern`, `success_metrics` or `primary_metric`, `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present`); (b) Q7 — when `kill_criteria` is set, `kill_criteria_resolution` must also be non-empty; (c) Q6 — bidirectional PR-list parity between state.json (`tasks[].pr_number`, `phases.merge.pr_number`, `tasks[].related_prs`) and case study (body regex `PR #N` / `pull/N` + frontmatter `related_prs`). Override: case-study `pr_citation_exempt: [{pr_number, reason}]` frontmatter array.

**Cycle-time gates (fire every 72h via GitHub Actions):**
Runs [`scripts/integrity-check.py`](scripts/integrity-check.py) against every `.claude/features/*/state.json` and every `docs/case-studies/*.md`. **16 cycle-time check codes** (13 baseline + 3 v7.8 additions): `PHASE_LIE`, `TASK_LIE`, `NO_CS_LINK`, `V2_FILE_MISSING`, `PARTIAL_SHIP_TERMINAL`, `NO_STATE`, `INVALID_JSON`, `NO_PHASE`, `SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `CU_V2_INVALID` (v7.7), and **(v7.8 framework-v7-8-branch-isolation, all advisory)** `BRANCH_ISOLATION_HISTORICAL` (T17 — forward-only audit), `BRANCH_ISOLATION_LAUNCHD_DRIFT` (T18 — macOS-only plist scan), `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror (T19 — catches --no-verify bypasses).

- **Backfill exemption:** features tagged `case_study_type: "pre_pm_workflow_backfill"`, `"roundup"`, `"no_case_study_required"`, or `"framework_meta_retroactive"` bypass the sub-phase vocabulary check. The `framework_meta_retroactive` tag (added v7.8) is for framework-version meta features whose framework version itself shipped before spec discipline was established (v5.0 SoC, v5.2 dispatch intelligence, v6.0 measurement, v7.0 meta-analysis, v7.1 integrity cycle); the case study + git history are the source of truth — no spec/plan/PRD chain to backfill. Going forward (v7.9+), all new framework versions carry full chain-of-custody and CANNOT use this exemption.
- **Local usage:** `make integrity-check` (findings only) or `make integrity-snapshot` (write + diff vs previous).
- **Full docs:** [`.claude/integrity/README.md`](.claude/integrity/README.md).

**Readout-time dashboards (any time):**
- `make documentation-debt` — Tier 3.2 baseline ledger (7 open items); trend mode unlocks after 3 scheduled cycle snapshots.
- `make measurement-adoption` — Tier 1.1 ledger; surfaces `cache_hits 0/40` known delta tracked at [issue #140](https://github.com/Regevba/FitTracker2/issues/140).
- `make runtime-smoke PROFILE=<id> MODE=<local|staging>` — Tier 2.1 smoke-gate runner; 5 profiles incl. `sign_in_surface`.
- `.claude/logs/<feature>.log.json` — Tier 2.2 contemporaneous feature logs; append via `scripts/append-feature-log.py`.

**Data quality tiers (Tier 2.3):** every quantitative metric in a case study, PRD, or meta-analysis must carry a T1 (Instrumented) / T2 (Declared) / T3 (Narrative) label. See [`docs/case-studies/data-quality-tiers.md`](docs/case-studies/data-quality-tiers.md).

**v7.5 case study:** [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](docs/case-studies/data-integrity-framework-v7.5-case-study.md). **Remediation status:** [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md). **Cold-start entrypoints** (one-page framework-version + Gemini audit summaries): [`.claude/entrypoints/`](.claude/entrypoints/).

This framework exists because we empirically observed 7+ features sit in "shipped but state.json unreconciled" limbo for 3–14 days before the 2026-04-20 audit caught them, and because the 2026-04-21 Gemini audit surfaced that the project had shipped extensive measurement infrastructure without a measurement of its own measurement adoption. v7.5 closes both loops: data is gated at write, audited on cycle, and surfaced on demand.

**Per-PR + weekly defenses (v7.6, shipped 2026-04-25):**
- **Per-PR review bot** — [`.github/workflows/pr-integrity-check.yml`](.github/workflows/pr-integrity-check.yml) runs schema-check + integrity-check + measurement-adoption against every PR HEAD, captures the `origin/main` baseline via worktree, and sets the `pm-framework/pr-integrity` commit status. `failure` if any required command exits non-zero or if the PR introduces NEW findings vs main. Sticky comment with marker `<!-- pm-framework-pr-integrity-bot -->` updates in place.
- **Weekly framework-status cron** — [`.github/workflows/framework-status-weekly.yml`](.github/workflows/framework-status-weekly.yml) fires Mondays 05:00 UTC. Appends a snapshot to [`.claude/shared/measurement-adoption-history.json`](.claude/shared/measurement-adoption-history.json) (dedup by date). Opens `framework-status` issue on regression (decrease in `fully_adopted` or `any_adopted`).
- **Append-only adoption history** — `make measurement-adoption` now writes a dated snapshot to the history ledger; trend mode unlocks after 3 snapshots accumulate.

**v7.7 Validity Closure (shipped 2026-04-27 via PR #144 [merge `01b9e11`]; state.json reconciled in PR #158):**
Closes A1–A5 + B1–B2 + C1 from the post-v7.6 gap inventory across two PRs:

- **FitTracker2 PR #144** — 5 new gates: 4 write-time pre-commit hooks (`CACHE_HITS_EMPTY_POST_V6`, `CU_V2_INVALID`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`) + 1 cycle-time check code (`CU_V2_INVALID`) + 1 cycle-time advisory (`TIER_TAG_LIKELY_INCORRECT`, kill criterion 2 fired at baseline so it ships **advisory permanent**). Plus bulk-backfill of 32 case-study frontmatters and timing.phases backfill on 3 paused features.
- **fitme-story PR #7** — framework-health dashboard at `/control-room/framework` surfacing all 19 mechanical gates + 1 advisory + the D1/D2 human-action checklist + Tier 1.1/3.2 trend charts (charts unlock as cron snapshots accumulate).

**Outcome at synthesis time (2026-04-27):**

| Dimension | Pre-v7.7 | Post-v7.7 |
|---|---|---|
| state↔case-study linkage | 95.5% | **100%** (gated) |
| doc-debt: work_type | 60% | **100%** (gated forward) |
| doc-debt: success_metrics / kill_criteria / dispatch_pattern | 8.9–28.9% | **95.7%** (33 TODO markers reflect genuinely-absent pre-PRD data) |
| `cache_hits[]` post-v6 | 33.3% | gated to 100% on next write (issue #140 closed) |
| `cu_v2` schema | unchecked | 100% schema-validated |
| Total framework mechanisms | 18 (12 cycle + 6 write-time) | **25 gates + 1 advisory** |

**Cron-gated post-merge verifications (B1+B2):**
- Tier 1.1 trend mode unlocks at 3 history snapshots — earliest **2026-05-04** (Monday cron appends snapshot #3).
- Tier 3.2 trend mode unlocks at 3 cycle snapshots — earliest **~2026-05-03 to -06** (72h cycle accumulates 3rd snapshot).

A scheduled +7d agent will append the verification + journal entry once both fire.

**Known gap (2026-04-30 audit) — RESOLVED in v7.8:** the `CACHE_HITS_EMPTY_POST_V6` write-time gate had 0% effective coverage at v7.7 ship because 43/46 state.json files used the legacy `created` key while the gate read `created_at`. Closed by:

- PR #169 (2026-05-01) migrated 43 files from `created` → `created_at`.
- PR #173 (2026-05-02) added a defensive dual-read parser + Mechanism C scaffolding.
- PRs #185 + #186 (2026-05-03) backfilled `framework_version` to canonical `vX.Y` on all 46 features.
- PR #187 + #188 + #189 (2026-05-03) shipped Mechanism A coverage-asserting gates, Mechanism C session attribution wiring, and Mechanism E git merge driver. Effective gate coverage now visible in `.claude/logs/gate-coverage.jsonl`.

## v7.8 Bridge (advisory mode, shipped 2026-05-02 → 2026-05-03)

v7.8 closes the v7.7 silent-pass via two surfaces specified jointly with v7.9:

**Surface 1 — Silent-pass prevention (Mechanisms A, B, C, D):**

- **Mechanism A — Coverage-asserting gates** (PR #187): every write-time gate emits `{candidates, checked, skipped, skip_reasons}` to `.claude/logs/gate-coverage.jsonl`. v7.9 will promote a `GATE_COVERAGE_ZERO` meta-check to enforced once ≥7 days of stats accumulate.
- **Mechanism B — Schema field-rename detection + dual-read** (PR #173 + #185 + #186): `created` ∪ `created_at` dual-read for the migration window; canonical `framework_version` field on 46/46 features.
- **Mechanism C — PostToolUse:Read hook** (PR #173 + #188): `scripts/observe-cache-hit.py` auto-captures Read events → `.claude/logs/_session-<id>.events.jsonl`. `/pm-workflow` now writes `.claude/active-feature` on entry; SessionStart hook surfaces it; new advisory check `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (15th cycle-time check code) flags features where session events show Reads but state.json::cache_hits[] is empty.
- **Mechanism D — Pre-commit hook header self-audit** (PR #193): pre-commit hook validates its own header on each run; mismatch raises an advisory finding instead of failing silently.

**Surface 2 — Inter-agent awareness (Mechanisms E, F):**

- **Mechanism E — Custom git merge driver** (PR #189): `scripts/merge-driver-dedup.py` auto-resolves merge conflicts on append-only ledgers (`measurement-adoption-history.json`, `documentation-debt.json`) via union-dedup-by-key. `make install-hooks` registers the driver; `.gitattributes` opts the ledgers in.
- **Mechanism F — Membrane status advisory** (PR #193): `scripts/membrane-status.py` reports active feature + recent gate firings + dispatch-blocker state in a single readout. Surfaced via SessionStart and `make membrane-status`. Closes the inter-agent context-handoff gap.

**v7.8 fully shipped 2026-05-04** via 9 PRs: #173 (M-C scaffold) + #185 (PR-2 schema bridges A) + #186 (PR-3 framework_version backfill) + #187 (PR-4 Mechanism A coverage gates) + #188 (PR-5 M-C session attribution) + #189 (PR-6 Mechanism E merge driver) + #193 (PR-6 Mechanisms D + F) + #194 (PR-7 cold-start entrypoint + honesty ledger FT2-FH-001) + #195 (CI fix). Six mechanisms (A–F) all in advisory mode; v7.9 measurement window opens **2026-05-11** (+7d). Schema bridges populated on 47/47 features.

## v7.8.1 Branch Isolation + Feature-Closure Completeness (advisory mode, shipped 2026-05-07 via PR #244 squash `6d1a53f` + PR #245 closure)

v7.8.1 closes two empirically-witnessed silent-pass failure modes via cooperating pre-commit gates extending v7.8's enforcement layer. Both gates ship in **advisory mode** — they emit Mechanism A coverage telemetry but do NOT block commits. v7.9 promotion (earliest 2026-05-21, T+14d) flips them to enforced.

**Trigger incidents:**
- HADF Phase 2 (2026-04-30) — launchd plist anchored to canonical repo path; relative writes resolved against wrong tree; required mid-flight isolation + restart + remerge
- 2026-05-07 reconcile session — 5 documentation-debt fields silently missing across 4 already-shipped features (UCC + import-training-plan + framework-story-site + push-notifications-v2); detection only post-hoc via `make documentation-debt`

**3 new write-time gates (in `scripts/check-state-schema.py`):**
- `BRANCH_ISOLATION_VIOLATION` (advisory) — Mode B fires on every commit when staged files match infra-path globs (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`); Mode C fires on `state.json::current_phase` mutations from a non-feature branch. Auto-isolation flow dispatches `scripts/create-isolated-worktree.py` (or `superpowers:using-git-worktrees` skill in agent context). Per-feature `isolation_opt_out: true` bypasses Mode C only; ignored for Mode B (Q3 infra override).
- `FEATURE_CLOSURE_COMPLETENESS` (advisory) — fires on `current_phase=complete` transitions. Validates 7 required case-study frontmatter fields + Q7 (`kill_criteria_resolution` required when `kill_criteria` set) + Q6 bidirectional PR-list parity (state.json ↔ case study, override via `pr_citation_exempt`).
- `ISOLATION_OPT_OUT_REASON_MISSING` (enforced) — when `isolation_opt_out: true`, `isolation_opt_out_reason` must be non-empty.

**3 new cycle-time advisories (in `scripts/integrity-check.py`):** `BRANCH_ISOLATION_HISTORICAL` (forward-only audit, T+14d after-ship cutoff); `BRANCH_ISOLATION_LAUNCHD_DRIFT` (macOS-only plist scan); `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror (catches `--no-verify` bypasses).

**Companion deliverables:**
- `scripts/create-isolated-worktree.py` — local CLI auto-isolation (idempotent + adopt-existing)
- `make verify-isolation` + `make feature-completeness-audit` — system-wide readouts
- `/ux + /design pre-merge-review` extended with sub-step 6f (kill_criteria_resolution check)
- `.claude/shared/branch-isolation-exempt.json` — exempt-pattern allowlist
- `.claude/shared/path-reducers.json` extended with `gate-coverage.jsonl` + `_session-*.events.jsonl` entries

**v7.8.1 first feature shipped via the v7.8 protocol** — first feature using Mechanism C session attribution + isolated worktree from Phase 1 onward + Tier 2.2 logging on every phase transition + Mechanism A coverage telemetry verification on its own gates. 14 commits across 9 phase transitions in one session; 28/28 implementation tasks done; 130/130 unit tests pass; 19/19 pipeline assertions pass.

**Spec:** [`.claude/features/framework-v7-8-branch-isolation/prd.md`](.claude/features/framework-v7-8-branch-isolation/prd.md). **Case study:** [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](docs/case-studies/framework-v7-8-branch-isolation-case-study.md). **Out-of-scope spec** (7 v8 candidates queued for Phase 9 prioritization 2026-05-21): [`docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md`](docs/superpowers/specs/2026-05-07-branch-isolation-out-of-scope.md).

**Spec:** [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md).
**Predecessor v7.7 spec:** [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md).
**Predecessor v7.7 plan:** [`docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md`](docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md).
**v7.7 case study:** [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](docs/case-studies/framework-v7-7-validity-closure-case-study.md).
**v7.8 case study (live append-only journal):** [`docs/case-studies/framework-v7-8-bridge-case-study.md`](docs/case-studies/framework-v7-8-bridge-case-study.md).

## v7.8.2 Cross-Repo Telemetry Asymmetry — Documented Disposition (shipped 2026-05-08)

v7.8.2 is a **patch-level bump** that does NOT add new gates. It codifies a forward-looking policy decision and ships one operability fix. Closes 2 v7.9 candidates (F7 + F8) by documenting the "no-port" decision rather than building cross-repo gate parity.

**Trigger:** during the 2026-05-08 fitme-story public-site audit session, the FT2 `PostToolUse:Read` hook fired `python3 scripts/observe-cache-hit.py` blindly even when cwd was in fitme-story (where the script doesn't exist), producing 30+ blocking-error notifications. Empirically confirmed F8 finding (Mechanism A telemetry is FT2-only).

**What shipped:**

- **Hook fix:** `.claude/settings.json` PostToolUse:Read command now has a Bash short-circuit existence guard (`[ -f scripts/observe-cache-hit.py ] && python3 ... || true`). Silently no-ops when the script is absent (cross-repo cwd, missing worktree, etc.).
- **Disposition spec:** [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) — 7 sections explaining (1) the asymmetry, (2) why no full parity, (3) what we DO ship, (4) what does NOT change, (5) re-eval triggers (3 signals), (6) cross-references, (7) disposition record.

**What does NOT change in v7.8.2:**
- All v7.5 → v7.8.1 gates still fire on FT2 commits (no regression)
- Mechanism A `gate-coverage.jsonl` still emits for every FT2 gate fire
- Mechanism C session-attribution still works when cwd is FT2
- Tier 2.2 contemporaneous logging still works for any feature in FT2

**v7.9 candidates resolved at v7.8.2:**
- **F7** (Tier 2.2 per-phase emission gate parity for fitme-story) — RESOLVED via documented exemption
- **F8** (Mechanism A `gate-coverage.jsonl` parity for fitme-story) — RESOLVED via documented exemption

**Re-evaluation cadence:** Annual (next 2027-05-08) OR earlier if any of 3 signals fire. See spec §5.

**v7.8.2 ships via** PR #258 (FT2 chore). Tracks: [fitme-story-public-enhancements T22 + T23](https://github.com/Regevba/FitTracker2/issues/255).

**Spec:** [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md).

## v7.8.3 Cross-Repo State Sync Implementation (in flight, per spec 2026-05-11)

v7.8.3 is the umbrella release for the `cross-repo-state-sync-impl` Feature.
Bundles all deferred Phase C/D state-sync work with two v7.9 candidates
(V2 + V9) into a single 5-phase rollout. Gates HADF Phase 2-bis: that
campaign cannot start until all 5 phases ship and per-phase calibration
targets are met.

**Phase 0 promotes (shipped 2026-05-11 PR #298):**
- V2 — `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` advisory → enforced
- V9 — Mechanism E custom git merge driver extends to `.claude/logs/<feature>.log.json`
- New `make snapshot-phase` Makefile target + `scripts/snapshot-phase-completion.sh` for per-phase off-SSD backups

**Phase 1 deliverables (shipped 2026-05-11 — D-3 PR #299 + C-4 fitme-story PR #86):**
- D-3 — unified cross-repo PR cite cache: `scripts/refresh-pr-cache.py` + multi-repo `_load_pr_cache` + `REPO_MAP` whitelist + `resolve_pr_cite()` for routing match groups; closes BROKEN_PR_CITATION's silent-skip on `[fitme-story#N]` cites + URL-form mis-routing; 63/63 retroactive cite validation
- C-4 — fitme-story control-room cross-repo gate-coverage aggregator: forward-sync extension mirrors FT2's `gate-coverage.jsonl` as `src/data/integrity/gate-coverage-ft2.jsonl`; `src/lib/control-room/gate-coverage-aggregator.ts` combines both repos' streams time-sorted; `/control-room/framework` page renders aggregated counts

**Phase 2 deliverables (in flight 2026-05-11):**
Every `state.json` now carries a top-level `state_owner` enum field
(`{"ft2", "fitme-story"}`) per the cross-repo contract — value reflects
WHERE the canonical state.json file lives, not where the feature's code
lives. Required from 2026-05-13 forward; backfilled to all 62 existing
features in a single mechanical commit. Three new write-time gates:
- `STATE_OWNER_MISSING` — required field
- `STATE_OWNER_INVALID` — must be in valid enum
- `STATE_OWNER_LOCATION_MISMATCH` (morphed C-5) — file location must
  match `state_owner`; sync mirrors with `state_owner_sync_origin`
  ending in `-reverse` are exempted (D-1 reverse-sync compatibility)

**Phases 3-4 (in flight):** D-1 reverse-sync GitHub Action (Phase 3) + cutover ceremony with first fitme-story-native feature (Phase 4).

**Spec:** [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md).
**Plan:** [`docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`](docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md).

## v7.8.4 Pre-v7.9 Telemetry Calibration & Doc-Debt Cleanup (shipped 2026-05-12)

v7.8.4 is a **patch-level hygiene release** that does NOT add new gates, with one exception: a small operability gate (`PR_CACHE_STALE` auto-refresh) closing the v7.8.3-era false-positive incident. The release exists to clean the noise floor before the **2026-05-21 v7.9 promotion-decision data freezes** — master plan §2.2 promotion criterion #2 ("no false positives") is more credible against a clean baseline.

**What ships:**

1. **PR cache freshness auto-refresh** — new `scripts/ensure-pr-cache-fresh.py` runs before every `make integrity-check` and inside `.github/workflows/integrity-cycle.yml`. Triggers a refresh when `.cache/gh-pr-cache.json` is empty, missing, or older than 24h. Refresh failure logs to stderr but does NOT abort the run (downstream BROKEN_PR_CITATION + PR_NUMBER_UNRESOLVED gates remain operative). Closes the **33-finding false-positive incident** observed 2026-05-12 when an empty-cache run flagged every PR citation as broken.
2. **TIER_TAG_LIKELY_INCORRECT heuristic narrowed (3 fixes in `scripts/validate-tier-tags.py`):**
   - `is_target_or_kill_claim()` filter — skips T1 claims whose context contains target/kill/threshold language (forward-looking declarations, not observations)
   - Word-boundary `\b` after unit regex — eliminates false positives where the unit letter is the first char of a longer word (`h` in `hook`, `s` in `schema`, `d` in `declared`)
   - Intervening tier-marker filter — skips claims whose context contains another T-tag (e.g., `T1 ... T2`) — number likely belongs to the second tier marker, not the first
3. **New reference ledger** `.claude/shared/case-study-t1-references.json` — pinned numerical values for T1 claims that are correctly instrumented but whose values are derived/computed and not captured by `measurement-adoption.json` or `documentation-debt.json` (initial seed: 3 entries — 57% ui-audit P1 reduction, 92min stress-test wall time, 2/9 post-v6 adoption ratio at synthesis time)
4. **cache_hits[] backfills** — `framework-v7-8-branch-isolation` (33 attributed Reads) + `import-training-plan` (95) populated from Mechanism C session-ledger attributions. Clears 2 CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE advisories.
5. **Doc-debt LOW items closed (5/5):**
   - `docs/case-studies/dual-outlet-pattern.md` — added YAML frontmatter (date_written, work_type, dispatch_pattern, success_metrics, kill_criteria, kill_criteria_resolution)
   - `docs/case-studies/framework-v7-8-branch-isolation-case-study.md` — added `success_metrics` field (companion to existing `primary_metric`)
   - `.claude/features/ios-code-connect/state.json` — added `case_study_type: no_case_study_required` + exemption reason
6. **Stale lockfile cleared** — `.claude/active-feature` reset from `ios-ui-audit-p1-burndown` (closed) to empty so the next `/pm-workflow` invocation owns it cleanly.
7. **Pre-v7.9 snapshot captured** — `make snapshot-phase PHASE=pre-v7-9-baseline FEATURE=framework-v7-8-branch-isolation` writes baseline to `~/Documents/FitTracker2-backups/2026-05-12-framework-v7-8-branch-isolation-pre-v7-9-baseline/` (12 files, sha256-verified).

**Outcome:** `make integrity-check` baseline at v7.8.4 ship — **0 findings + 0 advisory** (was 35+9 at session open, 6 advisory after stale-cache fix, 0+0 post-v7.8.4).

**What does NOT change in v7.8.4:**
- All v7.5 → v7.8.3 gates fire identically (no regression)
- v7.9 promotion calendar unchanged (decision 2026-05-21 per master plan §2.2)
- Master plan v8.x F-candidate docket unchanged

**v7.8.4 ships via** PR (TBD) on `chore/framework-v7-8-4-calibration-patch`. Lifecycle catalog entry mirrors v7.8.2's documented-disposition format.

**Spec:** N/A — patch-level hygiene; rationale captured in this section + cold-start entrypoint [`.claude/entrypoints/framework-v7-8-4.md`](.claude/entrypoints/framework-v7-8-4.md).

## v7.8.5 Observability Layer (shipped 2026-05-13)

v7.8.5 adds two operator-facing observability surfaces — both are **documentation + a hook**, no new gates, no telemetry impact on the 2026-05-21 v7.9 promotion data:

1. **Observed Patterns Catalog** — [`.claude/integrity/observed-patterns.md`](.claude/integrity/observed-patterns.md) is the canonical manifest of gate-firing patterns operators must recognize before debugging. 23 gate patterns + 9 workflow patterns documented. Auto-loaded as preflight by [`/pm-workflow`](.claude/skills/pm-workflow/SKILL.md). CLI: `make observed-patterns`. **Mandatory rule: any new pattern surfaced during a session MUST be appended to the catalog before the protocol closes the feature.** Shipped via PR #328 (initial 23-pattern catalog) + PR #341 (W9 detection mechanism).

2. **W9 branch-drift real-time alert** — [`scripts/check-branch-drift.py`](scripts/check-branch-drift.py) runs as a `PostToolUse:Bash` hook. Detects when the current git branch has changed unexpectedly between tool calls within a session (typically because another concurrent Claude session sharing the same git working directory ran `git checkout`, flipping HEAD). Emits a LOUD stderr warning surfaced back to the assistant via tool output, with a 4-step recovery playbook. Per-session state at `.claude/_session-state/<session_id>-branch.txt` (gitignored). Disable: `CLAUDE_W9_DISABLE_DRIFT_CHECK=1`. Full playbook: [`observed-patterns.md`](.claude/integrity/observed-patterns.md) W9.

**Operator obligation:** when any framework gate or advisory fires during a session, the FIRST step is to check the catalog (`make observed-patterns`). Apply documented remediation if pattern matches; investigate only if novel; ALWAYS append a new entry when surfacing a novel pattern.

## v7.8.6 Cadence Batch (shipped 2026-05-15)

v7.8.6 ships observability surfaces that close the **96-hour drift window** between the weekly framework-status cron (Mon 05:00 UTC) and the 72-hour integrity cycle (per `docs/master-plan/data-integrity-and-rollback-2026-05-14.md` §2.1+§2.3). No new enforcement gates; every addition is a read/diff/warn surface.

**MUST-have batch (PR #363):**

1. **`make integrity-diff`** — compares current platform state vs the 2026-05-14 pre-v7.9 baseline anchor. Anchored at `~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/platform-baseline/`. Override via `INTEGRITY_DIFF_BASELINE=<path>`. CI mode: `EXIT_ON_REGRESSION=1` exits 1 on regression. Producer: [`scripts/integrity-diff.py`](scripts/integrity-diff.py).

2. **Unified preflight entry point** — [`make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]`](Makefile). Aggregates every pre-work check (W1 ssh-agent, PR cache freshness, branch isolation, integrity findings, drift vs anchor, doc-debt, adoption baseline) into a single call. Writes `.claude/shared/preflight-cache.json` that all 10 downstream skills (ux, design, dev, qa, analytics, cx, ops, release, marketing, research) read from their `## Shared Data` section. Schema: [`docs/skills/preflight-cache-schema.md`](docs/skills/preflight-cache-schema.md). Mandatory Phase 0.0 step in `/pm-workflow`.

3. **Weekly Mechanism A gate-coverage zero-drift scan** — extends `framework-status-weekly.yml`. Tracks distinct gates emitting telemetry week-over-week via `.claude/shared/gate-coverage-weekly.jsonl` (append-only). Surfaces any gate that previously emitted but stopped — opens the digest issue with reason `A2 gate-coverage`. Producer: [`scripts/weekly-trend-scan.py`](scripts/weekly-trend-scan.py).

4. **Per-dimension adoption trend nudge** — same workflow extension. Diffs `timing_wall_time` / `per_phase_timing` / `cache_hits` / `cu_v2` / `fully_adopted_post_v6` against prior weekly snapshot. Opens digest issue on any decrease with reason `A4 per-dimension`. Addresses the documented `fully_adopted_post_v6` 27.3% → 8.3% regression + `cu_v2 ≥50%` chronic miss (master plan §2.5).

5. **W1 ssh-agent preflight** — [`scripts/check-ssh-agent.sh`](scripts/check-ssh-agent.sh) wired into SessionStart. Loud stderr warning when `ssh-add -l` returns no identities — prevents the documented W1 silent-sign-hang failure mode. Disable: `CLAUDE_W1_DISABLE_SSH_CHECK=1`.

**Nice-to-have batch (PR #365):**

6. **Weekly dependency audit** — [`.github/workflows/dependency-audit-weekly.yml`](.github/workflows/dependency-audit-weekly.yml) (Mondays 06:00 UTC, 1h after framework-status-weekly). Runs `npm audit --omit=dev` across root + `website` + `dashboard` subdirs + counts Swift Package.resolved pins. Producer: [`scripts/aggregate-dependency-audit.py`](scripts/aggregate-dependency-audit.py). Opens an issue on any HIGH or CRITICAL. Complements Dependabot (which opens per-bump PRs) by surfacing a rolling weekly total.

7. **Daily stale-branch + orphan-worktree warning** — appended to `scripts/daily-integrity-checkpoint.py` output. Lists local branches whose remote is gone (`[gone]`) + any isolated worktrees on disk in `.claude/worktrees/`. Suggests `commit-commands:clean_gone` skill for cleanup.

8. **Daily open-PRs-idle-24h babysit** — same script. Calls `gh pr list` for FT2 + fitme-story; filters to PRs idle >24h (oldest first). Silent no-op when `gh` unavailable.

**MUST-have follow-up tracker:** [`.claude/shared/must-have-cadence-followups.md`](.claude/shared/must-have-cadence-followups.md) — single ledger for calendar-anchored verifications (B1 v7.9 freeze 2026-05-21, B2 post-v7.9 baseline 2026-05-28, B4/B5 quarterly test audit) + feature-scope MUST items (C1 F14/F15 dispatch tests, C2 T6 web PR gate RICE 200.0, C3 T2 Sentry test). Daily checkpoint surfaces upcoming items ≤14d.

**Spec / case study:** the v7.8.6 work ships against the existing infra-master-plan §4.1 calendar; no separate spec because every addition is a read-only observability surface (the spec/PRD requirement applies to enforcement gates). PR bodies (#363, #365) serve as the case-study source.

## v7.9 Promotion Release (shipped 2026-05-21)

v7.9 is the **enforcement-flip release** for the three v7.8.1 advisory gates that completed their 14-day Mechanism A telemetry window on 2026-05-21. No new gate code; no new schema fields; no new observability surfaces. The single change is `BRANCH_ISOLATION_ADVISORY_MODE = True → False` at [`scripts/check-state-schema.py:149`](scripts/check-state-schema.py), which controls all three gates simultaneously.

**Promotion decision criteria (per [infra master plan §2.2](docs/master-plan/infra-master-plan-2026-05-12.md)):** all four required for each candidate.

| Criterion | Result |
|---|---|
| 1. Coverage emitted — ≥7 days of `{candidates, checked, skipped}` rows | ✓ 14 days (2026-05-07 → 2026-05-21) |
| 2. No false positives — every `failure` row maps to a legitimate violation | ✓ 0 false positives across 18 + 13 + 13 firings |
| 3. No silent skips — skip counts track real reasons (not bugs) | ✓ All skip reasons: `not_infra_commit_level`, `not_complete_transition`, `opt_out_false_or_absent` |
| 4. Reversibility — advisory mode restorable in <5 min | ✓ Single-line revert |

**Gates promoted (3 advisory → 3 enforced):**

| Gate | 14d telemetry | Skip reasons (legit) |
|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B (infra commit-level) | 18 rows | `not_infra_commit_level` × 13 |
| `BRANCH_ISOLATION_VIOLATION` Mode C (per-state.json) | 13 rows | (separate emission key) |
| `FEATURE_CLOSURE_COMPLETENESS` (write-time) | 13 rows | `not_complete_transition` × 11, `no_phase_change` × 1 |

**Gates already enforced (no v7.9 action):**

- `ISOLATION_OPT_OUT_REASON_MISSING` — enforced at v7.8.1 ship (2026-05-07)
- Mechanism A coverage gates + Mechanism C session-attribution — calibration window already met, enforced at v7.8
- `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (V2) — enforced at v7.8.3 Phase 0 (2026-05-11)
- Mechanism E custom merge driver (V9) — enforced at v7.8.3 Phase 0

**Gates that stay advisory by design:** `BRANCH_ISOLATION_HISTORICAL` cycle-time (T17 forward-only audit), `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time (T18 macOS-only), `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror (T19 `--no-verify` bypass catcher).

**Post-promotion calendar (Phase E validation 2026-05-21 → 2026-06-04):**

- **2026-05-22** — B11 UCC hardening T+3d check; new feature work resumes (no new gates this window)
- **2026-05-23** — B8 parent UCC T+7d kill-criteria evaluation
- **2026-05-27** — B12 hardening T+7d kill-criteria → complete
- **2026-05-28** — B2 post-v7.9 baseline snapshot via `make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation`
- **~2026-06-04** — Phase E exit; v7.9.1 build window opens

**Reversibility runbook:** if a regression surfaces during Phase E soak, flip back via single-line edit at [`scripts/check-state-schema.py:149`](scripts/check-state-schema.py) (`BRANCH_ISOLATION_ADVISORY_MODE = True`), commit on `chore/v7-9-rollback`, merge to main. <5 min end-to-end.

**Case study:** [`docs/case-studies/framework-v7-9-promotion-case-study.md`](docs/case-studies/framework-v7-9-promotion-case-study.md).
**Cold-start entrypoint:** [`.claude/entrypoints/framework-v7-9.md`](.claude/entrypoints/framework-v7-9.md).
**Honesty ledger entry:** [FT2-FH-003](docs/case-studies/framework-honesty-ledger.md#ft2-fh-003).
**Per-PR provenance:** PR (TBD) on `feature/v7-9-promotion`.

## v7.9.1 Build Window (shipped 2026-06-04 — 8 ships, 14 PRs)

v7.9.1 is a **single-day build window** that opened at v7.9 Phase E exit (2026-06-04) and closed the same day. **0 new enforcement gates** were added — the window respected Phase E exit discipline (no new gates for the first 14 days post-promotion). All 8 ships are observability surfaces, doc updates, reusable substrates, or warn-only CI workflows.

**Synthesis case study:** [`docs/case-studies/framework-v7-9-1-promotion-case-study.md`](docs/case-studies/framework-v7-9-1-promotion-case-study.md). Per-feature case studies remain authoritative for each gate audit (FEATURE_CLOSURE_COMPLETENESS requirement); this synthesis is the navigation + cross-cutting-theme layer (per the v7.9 promotion case study pattern).

**What shipped** (in cascade order; each subsection below has its own detail):

| Ship | Theme | PR(s) |
|---|---|---|
| F16 try-repo harness | Gate-test depth (Layer 3) | #607–#612 |
| F17 last_fired_at index | Derived telemetry materialization | #617 |
| F2 Phase 0 reality-check | Defense vs post-squash-merge state drift | #618 |
| Dev-env Track B (R7+R8+R12 lint trio) | Operator-side lint integration | #619 |
| F-LAUNCHD-DRIFT-EXTENSION (b)+(c) | Cron-context phantom-finding suppression | #621 (+#622 closure) |
| F-LAUNCHD-DRIFT-EXTENSION (a) | Plist path-resolution health checks | #623 (+#624 closure) |
| Observed-patterns W29-W32 catalog batch | v7.8.5 mandatory rule | #620 |
| F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE | Soak-window adoption-metric discipline | #625 |
| R9 Track B coverage aggregator | iOS Slather + Python pytest-cov CI telemetry | #626 |
| Dev-env R11+R13+R14+R17+R18 batch | gitleaks + pip-audit + SBOM + commitlint + shellcheck | #627 |
| F-DEPLOYED-URL-PROBE (FT2 substrate) | W18 og:image + W19 GA_ID encoded-newline silent-pass | #628 |

**Quantitative roll-up:**

| Dimension | Pre-2026-06-04 | Post-2026-06-04 |
|---|---|---|
| Write-time gates | 12 | 12 (no new) |
| Cycle-time gates | 13 + 3 advisories | 13 + 3 advisories (no new) |
| CI workflows | 8 baseline | **14** baseline (+6) |
| Observed-patterns W-entries | W1-W28 | **W1-W32** (+4) |
| v7.9.1 docket open | 7 candidates | **2** (fitme-story-side only) |
| FT2 dev-env open R-items | 7 | **0** |
| Reusable shell substrates | 0 | 1 (`scripts/probe-deployed-url.sh`) |

**Calendar-anchored follow-ups:**

- **2026-06-11** — T+7d verification of F-LAUNCHD-DRIFT-EXTENSION + F-DEPLOYED-URL-PROBE
- **2026-06-12** — External Audit #2 (operator-driven)
- **2026-06-18** — F16 T11 advisory→enforced flip (calibration window ends)
- **2026-07-04** — R9 Track B 30-day coverage data read → v8.0 `GATE_TEST_MISSING` calibration

**Cross-repo follow-ups (fitme-story-side, separate session):**

- F-AUTH-LATENCY-SERVER-METRIC (`duration_ms_server` field on WebAuthn audit event)
- F-CONTRACT-FIXTURE-SAMPLING (consumer-side adoption + `make sample-contract-fixtures`)
- F-DEPLOYED-URL-PROBE workflow integration (post-deploy GH Action calling the FT2 substrate)

## v7.9.1 F17 — Per-gate `last_fired_at` Index (shipped 2026-06-04)

`.claude/shared/gate-last-fired.json` is a derived per-gate index of Mechanism A telemetry. For each gate that ever produced a row in `.claude/logs/gate-coverage.jsonl`, the index records `last_fired_at` (most recent timestamp where `checked >= 1`), `last_checked_at` (most recent of any candidate row), `last_skipped_at` (most recent skip), `first_seen_at`, `total_firings`, `total_skips`, and `total_candidates`.

**Producer:** `scripts/refresh-gate-last-fired.py` — reads the JSONL line-by-line, aggregates per-gate, writes the index. Empirical wall-clock <1s for ~2k rows. Schema-versioned at 1; readers can detect future format drift via `schema_version`.

**Invocation points:**
- `make gate-last-fired` (direct, on-demand)
- `make integrity-check` (chained before integrity scan)
- `scripts/daily-integrity-checkpoint.py` (inherits via integrity-check)
- `.github/workflows/framework-status-weekly.yml` (nightly index materialization)

**Pattern reference:** AWS Config Rules `LastSuccessfulInvocationTime` — derive a small index from a large append-only stream so consumers query "when did X last happen?" in O(1).

**Why it matters:** the planned v7.10 `GATE_COVERAGE_ZERO` meta-check (which catches gates that have stopped firing despite producing prior telemetry) can now be O(1) per gate instead of O(records × gates). The same index supports the quarterly Data Freshness Audit (next: 2026-08-12).

**Spec:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](docs/master-plan/infra-master-plan-2026-05-12.md) §3.1 Theme G F17 (RICE 66.7 — highest of all v7.9.1 items).

## v7.9.1 F16 — Try-repo Pre-commit Harness (shipped 2026-06-04)

The framework now has **3 layers of gate testing** instead of 2:

1. **Unit** (`scripts/tests/test_check_state_schema.py` per-function) — fastest, narrowest. Catches wrong field-name logic, wrong regex.
2. **Dispatch** (F14 PR #317 pattern — monkey-patched `main()` end-to-end via `monkeypatch.setattr(_mod, ...)`) — catches wrong gate registration, wrong skip semantics, wrong Mechanism A row emission.
3. **Try-repo** (F16, this section) — spawns a throwaway git repo at `pytest tmp_path`, stages canonical positive/negative fixtures from `tests/fixtures/<GATE_ID>/{positive,negative}/`, runs the **real** `.githooks/pre-commit` shell script via subprocess, asserts the exit code + stderr match the fixture's intent. **Catches the integration-surface bugs the monkey-patch pattern architecturally cannot see** — hook composition, env-var inheritance, real `git status --porcelain` interaction, HOME pollution.

**Empirically proven:** during T4 development, F16 caught two real architectural bugs in the framework's own infrastructure that F14 had not surfaced — `GATE_COVERAGE_LEDGER` was a module-level constant not an env-var (Q5 finding), and `REPO_ROOT` was hardcoded to where the .py file lived (Q6 finding, closed via PR #611's `REPO_ROOT_OVERRIDE` env-var support). T7 (`scripts/tests/test_try_repo_regression_proof.py`) is the deliberate-regression test that PROVES the value claim by construction.

**Coverage:** 15 of 16 write-time gates covered end-to-end. 1 documented skip (STATE_OWNER_LOCATION_MISMATCH — the gate skips with `path_neutral` when the throwaway repo is not under `/FitTracker2[-/]` or `/fitme-story/`; deferred to F16.1).

**Discipline for new gates:** every gate added going forward MUST ship with a try-repo fixture pair under `tests/fixtures/<GATE_ID>/{positive,negative}/state.overrides.json` PLUS a per-gate test in the appropriate bucket file (`test_try_repo_*_gates.py`). The fixture overrides merge with `tests/fixtures/_baseline/state.json` via `make_state_json()`. Positive fixture: gate must fire (rc != 0). Negative fixture: gate must pass (rc == 0). See [`docs/architecture/dev-guide-v1-to-v7-7.md`](docs/architecture/dev-guide-v1-to-v7-7.md) §4 for the gate-catalog try-repo column.

**CI integration:** the `try-repo-harness` job in [`.github/workflows/pr-integrity-check.yml`](.github/workflows/pr-integrity-check.yml) runs the full F16 suite on every PR. Empirical wall-clock: ~15s for 59 tests + 1 skip (budget: <60s).

**PR provenance:** #607 (Phase 0+1+2 scoping) + #608 (T2+T3 baseline + harness scaffold) + #610 (T4a fixtures + Q6 finding) + #611 (REPO_ROOT_OVERRIDE fix) + #612 (T4a unblock + T4b/c/d + T6 CI + T7 regression proof).

## v7.9.1 F2 — Phase 0 Reality-Check Sub-step (shipped 2026-06-04)

`/pm-workflow` Phase 0 gains a new MANDATORY sub-step (Phase 0.1) right after Phase 0.0's unified preflight. For the active feature, run:

```bash
make phase-0-reality-check FEATURE=<name>
```

The check reads `state.json::tasks` and cross-checks each `pending` / `in_progress` / `open` task against the last 30 days of evidence in the codebase:

- **Git log subjects** — has anyone shipped a matching commit?
- **Merged PR titles** (FT2 + fitme-story) — has either repo merged a matching PR?
- **Tier 2.2 log events** in `.claude/logs/<feature>.log.json` — has anyone logged an implementation event mentioning the task ID or its keywords?

Output: stdout summary + structured JSON at `.claude/shared/phase-0-reality-check.json`. Advisories surface as "**this task may already be done**" — never blocking, always operator-judgment.

**Why F2 is load-bearing.** The post-squash-merge state-drift pattern was documented across 5 confirmed instances in 2026-06-01 → 2026-06-04 alone (C5 → D1 → C2/C3/C5/C6 batch → trend-alerts-hrv → multiple F16 closure attempts). Each time, `state.json::tasks` said `pending` but the file changes were already on `main` via a prior PR. Without Phase 0.1, the next Phase 0 schedules new work on top of stale state. **F2 is the mechanical defense** — surface the drift BEFORE scheduling, so the task list gets reconciled first (likely via `make close-feature FEATURE=<name>`) and Phase 0 starts against accurate state.

**Threshold:** the gate requires ≥2 distinct evidence items (across git + PRs + log events) to flag a task. Single-item matches are silent — keeps false-positive rate manageable. Words like "the", "test", "implement" are filtered as noise.

**Block phase advancement** if Phase 0.1 flags ≥1 advisory AND the operator has not explicitly acknowledged the finding (via `state.json::phase_0_reality_check_acknowledged: ["T3 reviewed — not the same scope"]` or by flipping the affected task's status).

**Spec:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](docs/master-plan/infra-master-plan-2026-05-12.md) §3.1 Theme A F2 (RICE 42.7).

## v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fixes (b)+(c) — Cron-context phantom-finding suppression (shipped 2026-06-04)

Closes the W11.b silent-pass class — launchd-cron context where the `gh` CLI cannot reach the macOS keychain ⇒ `refresh-pr-cache.py` produces an empty cache ⇒ every PR citation looks broken ⇒ 319 phantom `BROKEN_PR_CITATION` + `PR_NUMBER_UNRESOLVED` findings on 2026-05-24. Same context caused 5 silently-broken cron days after the 2026-05-19 SSD migration before the drift was noticed.

Three cooperating changes ship together (sub-fix (a) — `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory→enforced — deferred to a follow-on PR per spec §3 "any subset can ship independently"):

1. **`scripts/ensure-pr-cache-fresh.py`** detects cron context via `LAUNCHD_LABEL` env (set by every launchd job), `CRON_CONTEXT=1` manual override, or `XPC_SERVICE_NAME` containing both `fittracker` and `daily`. When ALL of (cron context, refresh subprocess failure) hold, it writes a JSON sentinel at `.claude/shared/pr-cache-refresh-failed.flag` (`{ts, reason, context}`). The flag-write itself is best-effort — `OSError` is swallowed so the script's existing exit code remains the only failure signal.

2. **`scripts/integrity-check.py`** reads the sentinel at startup via `pr_cache_refresh_failed_recently()`. If the flag exists AND `ts` is within the last 1 hour, the run SKIPS `BROKEN_PR_CITATION` + `PR_NUMBER_UNRESOLVED` and emits a single `PR_CACHE_REFRESH_FAILED` advisory carrying the failure reason and timestamp. Stale flags (>1h old) are ignored — Kill criterion #3 enforcement (the flag cannot indefinitely suppress real findings). Malformed JSON in the flag also falls back to "no skip."

3. **`scripts/daily-integrity-checkpoint.py::precheck_cron_context()`** pre-validates `gh auth status` BEFORE invoking `make integrity-check`. Under cron context + auth missing, it exits 78 (`EX_CONFIG` from `sysexits(3)`) — what launchd interprets as a config error worth surfacing in `launchctl list <label>` without retry-backoff drama. Interactive sessions never trigger this branch.

**Test coverage:** [`scripts/tests/test_launchd_drift_extension.py`](scripts/tests/test_launchd_drift_extension.py) — 16 tests covering interactive happy path, all 3 cron-context detection signals, fresh/stale/malformed flag handling, OSError swallow on flag-write, and the exit-78 paths in `precheck_cron_context`. Runs in 0.05s.

**Failure-mode posture:** the flag-skip mechanism is fail-safer-than-status-quo — under cron auth failure it now produces ONE clearly-labeled advisory instead of 300+ phantoms. Under any other failure mode (write OSError, JSON malformed, ts stale) the system falls back to the pre-v7.9.1 behavior. No new enforcement gates; no advisory window needed.

**Spec:** [`.claude/shared/v7-9-1-candidates.md`](.claude/shared/v7-9-1-candidates.md) F-LAUNCHD-DRIFT-EXTENSION + [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md) E-14. **Case study:** [`docs/case-studies/f-launchd-drift-extension-case-study.md`](docs/case-studies/f-launchd-drift-extension-case-study.md).

## v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (a) — Plist path-resolution health checks (shipped 2026-06-04)

Closes the third sub-fix of F-LAUNCHD-DRIFT-EXTENSION. The `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time advisory in [`scripts/integrity-check.py`](scripts/integrity-check.py) gains 3 path-resolution health checks fired against any FT2-related plist (detected via filename heuristic + `ProgramArguments` + `WorkingDirectory` pattern):

1. **WorkingDirectory exists** — emits advisory if the plist's `WorkingDirectory` does not resolve to an extant directory on the current filesystem. Catches the 2026-05-19 SSD-migration class (`/Volumes/DevSSD 1/...` vs canonical `/Volumes/DevSSD/...` after mount swap) on day 1 instead of day 5.

2. **ProgramArguments[0] script exists** — strips an interpreter prefix (`/bin/bash`, `python3`, `/usr/bin/env`, etc.) and checks that the resolved script path exists as a file. Catches plists whose script moved during a refactor. Relative paths (`scripts/foo.py`) are out of scope since they rely on PATH resolution at fire time.

3. **StandardOutPath / StandardErrorPath parent dir is writable** — emits advisory if either the parent directory is missing OR the current user lacks write permission. Without this, cron failures become invisible because launchd cannot capture stdout/stderr.

The new sub-checks ship in **ADVISORY mode** — no calibration window because they are additive on top of an existing advisory; false positives don't break anything and the operator can ignore them. The pre-existing T18 feature-attached `WorkingDirectory` mismatch check (HADF Phase 2 incident class) is unchanged and runs alongside the new checks in the same gate function.

**Empirical coverage:** unrelated plists (Spotlight, etc.) are explicitly NOT scanned via `_plist_references_ft2()` heuristic — keeps the operator surface clean.

**Test coverage:** [`scripts/tests/test_launchd_drift_extension_sub_a.py`](scripts/tests/test_launchd_drift_extension_sub_a.py) — 14 tests covering Linux-skip, 4 heuristic cases (filename / program-args / workdir / unrelated-ignore), all 3 sub-checks (fire + no-fire), compound plist with multiple problems, and the unrelated-plist negative. Runs in 0.28s.

**F-LAUNCHD-DRIFT-EXTENSION fully closed.** Sub-fixes (b)+(c) shipped via PR #621 (`ed20cbf`, 2026-06-04); sub-fix (a) shipped this PR. All three reinforce the same posture: cron context is a different execution environment than interactive — make its failures loud, bounded, and self-diagnostic.

## Deployed-URL probe (v7.9.1+)

Closes the silent-pass class where **what the deployed HTML SAYS is the URL ≠ what the receiving service can actually fetch + process**. Trigger incidents: W18 (`<meta property="og:image">` pointed at a 404 path for 6 days; LinkedIn/Twitter/HN got no rich preview) + W19 (GA measurement ID had a trailing `\n` from env-var paste residue; Google Measurement Protocol rejected every event silently for 6 days).

Both bugs passed local dev + Vercel preview-deploy inspection because neither runs the receiving-service round-trip. Both manifested only in production.

**Reusable substrate at [`scripts/probe-deployed-url.sh`](scripts/probe-deployed-url.sh).** Bash helper invokable from any GH Actions workflow's `run:` block. 4 assertion modes:

```bash
# W18 — og:image is reachable
scripts/probe-deployed-url.sh https://fitme.dev/og.png \
    --status 200 --content-type "image/"

# W19 — gtag URL has no encoded newline
scripts/probe-deployed-url.sh "https://www.googletagmanager.com/gtag/js?id=$GA_ID" \
    --status 200 --body-not-contains "%0A"

# Canonical / sitemap / robots reachability
scripts/probe-deployed-url.sh https://fitme.dev/sitemap.xml --status 200 --content-type "xml"
scripts/probe-deployed-url.sh https://fitme.dev/robots.txt --status 200 --body-contains "Sitemap:"
```

**Exit codes:** 0 (all assertions pass) / 1 (assertion failed) / 2 (usage error) / 3 (curl/network error).

**Test coverage:** [`scripts/tests/test_probe_deployed_url.py`](scripts/tests/test_probe_deployed_url.py) — 12 tests covering all 4 assertion modes + the W18 status-mismatch reproducer + the W19 body-not-contains reproducer + curl-error fallback. Runs in ~1.6s against a stdlib `http.server`-backed test harness (no external network).

**fitme-story integration ships separately.** The shell helper is repo-agnostic; the fitme-story workflow YAML that calls it on each successful Vercel deploy is a fitme-story-side PR (not in scope for the FT2 substrate PR).

## Soak-window discipline (v7.9.1+)

During any framework-version soak window (Phase E for v7.X, Phase Y for future versions), new features that ship during the soak MUST either (a) freeze adoption metric collection until soak exit, OR (b) backfill adoption metrics in the same PR that introduces the feature's `state.json`.

**Why this rule exists.** v7.9 Phase E (2026-05-21 → 2026-05-28) added 9 new features to `.claude/features/*/` without backfilling their adoption metrics (`cache_hits`, `cu_v2`, `timing_wall_time`, `per_phase_timing`). `make integrity-diff` against the 2026-05-14 anchor consequently surfaced 3 measured regressions purely from **denominator dilution**:

| Metric | 2026-05-14 | 2026-05-28 | Δ |
|---|---|---|---|
| `adoption_pct_post_v6` | 8.3% | 6.7% | −1.6 pp |
| `timing_wall_time_pct_post_v6` | 47.2% | 37.8% | −9.4 pp |
| `cache_hits_pct_post_v6` | 52.8% | 51.1% | −1.7 pp |

These were **process regressions** — added features moved into the denominator while their numerator stayed empty (no adoption-metric backfill in the same PR). They were NOT v7.9 kill criteria; the kill criteria targeted false positives + rollbacks, both `not_fired`. v7.9 promoted regardless. But the **weekly trend-scan alerts** the regressions triggered are real noise that the next soak window will repeat without this discipline.

**Two ways to comply** when shipping a feature during a soak window:

1. **Freeze** — explicitly mark the feature's `state.json` with `soak_window_freeze: <version>` (e.g., `"v7.9"`). The weekly trend-scan and `make integrity-diff` will skip frozen features when computing percentage metrics.
2. **Backfill** — populate `cache_hits[]`, `cu_v2.factors`, `cu_v2.total`, `cu_v2.tier_class`, `timing.phases.<phase>.{started_at,ended_at}`, and `timing.wall_time_seconds` in the SAME PR that introduces the feature. The percentage metric stays stable.

**Enforcement posture.** Advisory at v7.9.1 ship (operator-attention; the weekly trend-scan emails will flag any soak-window dilution >1pp on any post-v6 percentage metric). Promotes to enforced (write-time gate `SOAK_WINDOW_FREEZE_OR_BACKFILL`) if 2 consecutive soak windows show >5 pp regression on any post-v6 percentage metric. Promotion criterion is built into the spec so the rule never silently sticks at advisory.

**See also.** [v7.9 promotion case study §99.4 lesson 2](docs/case-studies/framework-v7-9-promotion-case-study.md) for the original measurement; [`f-phase-e-adoption-freeze-discipline-case-study.md`](docs/case-studies/f-phase-e-adoption-freeze-discipline-case-study.md) for this rule's source case study.

**Mechanical complement (2026-06-10).** Denominator dilution is now *measured around*, not just disciplined against. `make integrity-multi-anchor` ([`scripts/integrity-multi-anchor.py`](scripts/integrity-multi-anchor.py)) classifies every adoption-% delta vs the **canonical 2026-05-14 anchor** as `REAL_REGRESSION` / `dilution` / `improved` using a cohort-intersection + absolute-numerator rule (`classify_delta`), so corpus growth no longer raises phantom regressions. `make integrity-diff` and `daily-integrity-checkpoint.py` regression verdicts consume the same rule (raw deltas still printed for transparency; only `REAL_REGRESSION` gates). `make measurement-adoption` reports an **instrumented-vs-derived** provenance split so a backfill-derived value never masquerades as contemporaneous T1 instrumentation. `make integrity-data-lake` ([`scripts/integrity-data-lake.py`](scripts/integrity-data-lake.py)) layers ALL telemetry (ledgers, crons, snapshots, anchors) into one read-only cross-source reconciliation + dilution-normalized digest (stdlib-first; optional local DuckDB, not cloud BigQuery). The 2026-05-14 anchor stays canonical (non-superseding) per [data-integrity sub-plan §2.6/§2.7](docs/master-plan/data-integrity-and-rollback-2026-05-14.md). Source: honesty ledger [FT2-FH-004](docs/case-studies/framework-honesty-ledger.md).

## Platform-test parity — `platforms_tested` field (T14, shipped advisory 2026-06-07, **enforced 2026-06-21**)

`state.json` carries a `platforms_tested: {ios, web, backend, ai}` boolean object recording **which platforms a feature's tests actually exercised** — making platform-test parity a queryable, gate-able property of every completed feature (not just "tests passed somewhere"). Platform semantics: `ios`=SwiftUI app, `web`=fitme-story/website/dashboard, `backend`=sync/Supabase/Railway, `ai`=ai-engine cohort. A sibling `platforms_tested_provenance` string records origin (`authored` / `backfill-heuristic-<date>` / `backfill-heuristic-low-confidence` / `exempt:framework_meta`).

**Gate (enforced 2026-06-21):** the `PLATFORMS_TESTED` write-time sub-check (in [`scripts/check-state-schema.py`](scripts/check-state-schema.py)) fires on `current_phase=complete` transitions when no platform key is `true`, and validates field shape at any phase. It uses its own `PLATFORMS_TESTED_ADVISORY_MODE` flag (flipped `True → False` on 2026-06-21 via PR #781, squash `6ac372b`) + an isolated Mechanism A coverage key, so the promotion was a single independent line that does not affect the `FEATURE_CLOSURE_COMPLETENESS` gate it fires alongside. **Promotion (cadence B15):** all four §2.2 criteria held over the 14-day window (advisory ship 2026-06-07 PR #662 → enforced 2026-06-21) — ≥7d coverage (9 emission days / 12-day span), 0 false positives across 16 real complete-transition checks (1470 legit skips), reversible single-flag. Findings now route to `errors[]` and block the commit; existing complete features do not re-transition so none fail retroactively (integrity-check reports 0 findings post-flip). Q2-exempt features still skip. Reversibility: flip the flag back on `chore/t14-rollback` (<5 min).

**Q2 exemption:** framework-meta features (`work_type=chore` / `work_subtype=framework_feature` / `provenance exempt:*`) are skipped — they ship no product-platform code.

**Backfill:** [`scripts/backfill-platforms-tested.py`](scripts/backfill-platforms-tested.py) populated all pre-T14 complete features from offline text signals (25 exempt, 61 inferred, 8 low-confidence flagged for optional spot-check; 0 mandatory review). **Out of scope:** per-platform coverage *percentages* (T15+, gated on R9 Track B data). Spec: `docs/master-plan/test-coverage-master-plan-2026-05-13.md` §4 T14. Source case study: [`docs/case-studies/t14-platform-parity-state-field-case-study.md`](docs/case-studies/t14-platform-parity-state-field-case-study.md).

## v7.10 — GATE_COVERAGE_ZERO observability + field-rename closure (shipped 2026-06-10)

v7.10 hardens the *observability of the gates themselves* — the meta-layer that watches whether each gate is actually running. No new product-facing gates; the change is making the silent-pass detector see the checks it previously couldn't.

**Shipped to main (2026-06-10):**

- **`GATE_COVERAGE_ZERO` meta-check** (built v7.9.1 #673; extended at v7.10 via PR #689, **advisory**) — reads the F17 [`gate-last-fired.json`](.claude/shared/gate-last-fired.json) index and flags a gate that went silent relative to the active corpus. v7.10 added a **0-candidate mis-wire detector**: a gate registered in the index but with every counter zero (`candidates==checked==skipped==0`) has a check site that runs but never reaches a candidate — the `cache_hits`-keying / unreachable-loop bug class. This is distinct from a *healthy* zero-firing gate (e.g. `STATE_OWNER_MISSING`: 1936 candidates, 0 violations — has candidates, stays silent).
- **Cycle-time coverage emission** (PR #689) — three cycle-time checks (`BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `PATTERN_SKILL_UNMAPPED`) previously emitted **no** Mechanism A coverage, so the F17 index + `GATE_COVERAGE_ZERO` were blind to them. They now emit `mode="cycle"` coverage via the shared `GateCoverage` tracker (live: 127/127/56 candidates). If one silently stops, the meta-check now catches it.
- **Field-rename silent-pass closure** (observed-patterns pattern **#24**) — the 2026-06-10 data-integrity audit found two READER/INDEX field-mismatches of the `created`/`created_at` (#7/#9) class: `measurement-adoption-report.py::has_cu_v2` read only the legacy `complexity.cu_version` (15 feats) not the canonical top-level `cu_v2` object (12 feats), halving adoption — **fixed PR #687** (post-v6 fully-adopted 3→6); and `refresh-gate-last-fired.py` read only `timestamp`, dropping 30 `w9.auto_isolate` rows keyed `ts` — **fixed PR #688** (18 gates indexed, 0 malformed). Pattern #24 generalizes #7/#9 to the measurement layer (no failing gate surfaces it — the lesson: grep every reader when you rename a field).

**In flight (open PRs as of 2026-06-10):**

- **Self-test meta-analysis + verify-local ergonomics** (PR #690) — the second what-if meta-analysis ran the v7.10 framework against every layer (iOS BUILD SUCCEEDED + 672 tests, ai-engine 34/34, web 286/289, framework 0 findings). Headline fix: `tokens-check` / `verify-web` / `verify-ai` now **skip cleanly** with a loud `⚠ … SKIPPING locally — CI enforces this gate.` message when deps are absent (matching the `lint-*`/`coverage-*` convention) instead of crashing cryptically. CI still enforces. Artifact: [`docs/case-studies/meta-analysis/2026-06-10-second-what-if-self-test-all-layers.md`](docs/case-studies/meta-analysis/2026-06-10-second-what-if-self-test-all-layers.md).
- **T10 — AI golden-set eval harness** (PR #691) — closes the test-coverage plan's "biggest layer gap". Scoping reframe: the FitMe AI is **deterministic** (`InsightService` rule engine), not generative (LLM path gated behind an unset `LLM_API_KEY`/DPA), so a deterministic golden set is *better* (zero flake, no key, hard PR gate). 24 golden cases + parametrized harness in `ai-engine/tests/golden/`; full ai-engine suite 60 pass / 1 skip; negative-control proven. Feature `ai-golden-set-evals`. Source case study: [`docs/case-studies/ai-golden-set-evals-case-study.md`](docs/case-studies/ai-golden-set-evals-case-study.md).

**Calibration ladder (date-gated):** ~~F16 advisory→enforced flip 2026-06-18~~ ✅ **enforced 2026-06-17** (1d early, PR #764) · ~~`PLATFORMS_TESTED` (T14) 2026-06-21~~ ✅ **enforced 2026-06-21** (PR #781, `6ac372b`) · W9 2026-06-28 (reset from 06-20 by the 2026-06-14 session-id-keying fix; clock restarts on the `w9.concurrency` key) · F4 `FRAMEWORK_VERSION_STALE` advisory→enforced ~2026-06-30 · R9 Track B 30-day coverage read 2026-07-04 (feeds `GATE_TEST_MISSING`) · `GATE_TEST_MISSING` (T1) gated on F14 Phase E 2026-08-22. **F18 mutation testing** remains v8.0 (depends on F14+F16 Phase E). **Un-ticketed test gaps:** Supabase Edge Functions (0 tests); the gated live-LLM eval body (lands with the LLM-escalation feature).

## Post-v7.10 framework additions (2026-06-29)

Five framework items shipped 2026-06-29 (no version bump — v7.10 chores). Canonical counts: [`docs/FRAMEWORK-FACTS.md`](docs/FRAMEWORK-FACTS.md). Gate count **30 → 32**; feature count **118 → 121**.

- **Cross-layer item naming convention (FIT-200)** — every trackable item carries a **slug** (canonical = the `.claude/features/<slug>/` dir), a **`state.json.linear_id`** (`FIT-NNN`, the cross-tool join key), and **scheme-prefixed thematic codes** (`FW-` framework / `TC-` test-coverage / `DE-` dev-env / `HADF-` / `AN-` analytics / `PROD-` product) that kill the bare-number collisions (two `R14`s, two `R9`s). `make crosswalk` → [`.claude/shared/item-registry.json`](.claude/shared/item-registry.json) builds the slug↔linear_id join + an advisory for features missing the join. Shared status vocabulary: Backlog → Planned → In Progress → Blocked → Done → Won't-Do. **Repo (`state.json.current_phase`) is the source of truth; Linear/Notion/backlog/plans are mirrors** (the W40 lesson). Spec: [`docs/process/cross-layer-item-naming-convention.md`](docs/process/cross-layer-item-naming-convention.md).
- **`state.json.schema_version` (DE-R18)** — every state.json carries an integer `schema_version` (current = **1**, all 121 backfilled) + an ordered migration runner [`scripts/migrate-state-schema.py`](scripts/migrate-state-schema.py) (`make migrate-state-schema`) so the schema can evolve forward safely (closes the `created`/`created_at` field-rename incident class). To bump: append a `(n, n+1, transform)` step to `MIGRATIONS` + raise `CURRENT_SCHEMA_VERSION`.
- **`CSV_TAXONOMY_DRIFT` (AN-1B.1, advisory)** — write-time gate: when `AnalyticsProvider.swift` is staged and an `AnalyticsEvent` constant's raw value has no row in `docs/product/analytics-taxonomy.csv` (and isn't `csv_taxonomy_exempt: [{constant, reason}]`), emits an advisory. Baseline drift 27→0 burned down 2026-06-29; advisory→enforced review **~2026-07-13** (cadence B16). Spec: analytics-master-plan §8.2.
- **`GA4_MCP_DISCONNECTED` (AN-1B.2, advisory-ONLY by design)** — write-time gate: when analytics-affecting code is staged and GA4 MCP is unreachable via env (`GA4_PROPERTY_ID` + `GOOGLE_APPLICATION_CREDENTIALS` file), emits an advisory. **Never blocks, even when "promoted"** (per §8.3) — no calibration ladder. Pre-launch the env is typically unset, so the advisory is the expected signal. With AN-1B.1, **analytics Phase 1.B is complete.**
- **integrity-check parallelization (DE-R14)** — `scripts/integrity-check.py --jobs <N>` (default `min(8,cpu)`; `--jobs 1` = serial) + memoized `first_commit_date`. **9.4s → 1.84s (5.1×)**, output identical.
- **Observed pattern W40** — cross-layer tracker lag / stale-open (item open in Linear/Notion/backlog while already shipped in the repo). Verify-first against the repo before starting any tracked item; the crosswalk mechanizes the detection. See [`.claude/integrity/observed-patterns.md`](.claude/integrity/observed-patterns.md) W40.

## Known Mechanical Limits

v7.6 promoted 4 silent gaps to pre-commit failures and added 3 recurring CI defenses. v7.8 PR-1 ships **Mechanism C** (PostToolUse:Read hook + `scripts/observe-cache-hit.py`) which moves Gap 1 from Class B → A in advisory mode (capture only); v7.9 promotes the writer-path to enforced once 7+ days of session-ledger data calibrate the threshold. Four gaps remain mechanically unclosable:

1. ~~`cache_hits[]` writer-path adoption — agent must remember to log it (issue #140).~~ **Auto-collected in v7.8 advisory** via `PostToolUse:Read` hook (`.claude/settings.json`) → `scripts/observe-cache-hit.py` → `.claude/logs/_session-<id>.events.jsonl`. v7.9 promotes to enforced. Pre-Mechanism-C features (`created_at < 2026-05-02`) are exempt from `CACHE_HITS_EMPTY_POST_V6` — the auto-instrumentation didn't exist for them.
2. `cu_v2` factor *correctness* — judgment-based; we check presence, not magnitude.
3. T1/T2/T3 tag *correctness* — preflight checks presence on post-2026-04-21 case studies, not whether the tag is right.
4. Tier 2.1 real-provider auth checklist — requires a human at a simulator.
5. Tier 3.3 external replication — requires an external operator.

Authoritative reference: [`docs/case-studies/meta-analysis/unclosable-gaps.md`](docs/case-studies/meta-analysis/unclosable-gaps.md). A system that knows what it cannot check is more trustworthy than one that pretends every check is a check.

## Concurrent Dispatch Hygiene

Parallel subagent dispatch is **currently blocked** at the framework layer (F6–F9). Serial dispatch is the working pattern until upstream patches land.

- **Before invoking `superpowers:dispatching-parallel-agents`:** check [`docs/framework-bugs/concurrent-dispatch-blockers.md`](docs/framework-bugs/concurrent-dispatch-blockers.md). If F6–F9 are still active there, default to serial.
- **Declare all required permissions in `.claude/settings.json`** (or `settings.local.json`) BEFORE dispatching any subagent — mid-session UI-accepted grants do NOT propagate to children (F9).
- **Expect re-prompts** on children for Edit/Write/Read even when parent has explicit allow entries (F6, F7). Accept them; don't try to debug as config issues.
- **Re-validation gate** for parallel dispatch: after upstream patches land, run the 2-parallel-agents test in [`docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md`](docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md) before resuming parallel work.

## CI Pipeline

- Token check: `make tokens-check` (design system drift detection)
- UI audit: `make ui-audit` (per-view design-system compliance scanner — see "Design System" section)
- Build: `xcodebuild build` (iOS Simulator, no code signing)
- Test: `xcodebuild test` (XCTest suite)
- All four must pass before any merge to main. The original 27-P0 baseline burndown completed (verified 2026-05-05: `make ui-audit` reports P0=0). `ui-audit` is now a hard gate within `verify-local` alongside tokens-check, build, and test. Fix-as-you-touch policy continues for P1 findings (current drift: +5 from 103 baseline → 108).
- **UI test coverage strategy (codified 2026-05-08 per iOS audit finding E-2):** UI test coverage is **intentionally thin** (~7 UI test files vs. 49 unit test files / 440 test methods total). Reason: the parallel-clone simulator hang env-flake (per `docs/case-studies/m-4-xcuitest-infrastructure-case-study.md`) makes UI tests a high-cost, high-flake surface on hosted CI. Unit + analytics tests carry the load instead. Expansion is **deferred** until the env-flake root cause is resolved (tracked in `docs/product/backlog.md` under "CI parallel-clone simulator hang"). Two surgical XCTSkipIf quarantines (`HomeReadinessUITests`, `OnboardingUITests`) remain in place as the live workaround.

## Data-Driven Development

This app is data-driven at every level:
- **System-wide guardrails** (must not degrade for any feature):
  - Crash-free rate > 99.5%
  - Cold start < 2s
  - Sync success rate > 99%
  - CI pass rate > 95%
  - Cross-feature WAU (North Star) trending up or flat
- **Every feature** has a metrics section in its PRD with kill criteria
- **Post-launch** reviews happen at the cadence defined in the PRD
- **Every quantitative metric is tiered** — T1 (Instrumented), T2 (Declared), or T3 (Narrative). Case studies, PRDs, and meta-analyses must tag each reported number with its tier. A T3 metric quoted as if it were T1 is a bug. Full convention: [`docs/case-studies/data-quality-tiers.md`](docs/case-studies/data-quality-tiers.md). Introduced 2026-04-21 per Gemini independent audit Tier 2.3.

## Design System (Living Framework)

The design system is a **living, evolving framework** — not a static constraint. It should serve the product.

- ~175 semantic tokens in `FitTracker/Services/AppTheme.swift`
- 17 reusable components in `FitTracker/DesignSystem/`
- Token pipeline: `design-tokens/tokens.json` → Style Dictionary → `DesignTokens.swift`
- CI gate: `make tokens-check` prevents token drift
- Always use semantic tokens (AppColor, AppText, AppSpacing) — never raw literals

**Evolution rules:**

- New tokens/components are proposed on feature branches, never directly on main
- Phase 3 compliance gateway validates every UI feature against the design system
- If a feature needs to deviate, the user chooses: fix, evolve the system, or override with justification
- Approved changes merge to main with the feature and become part of the system
- All changes documented in `docs/design-system/feature-memory.md`

### v4.X Skill-layer gates (added 2026-05-06)

Phase 3 + Phase 6 of the PM workflow now mechanically gate the spec ↔ code ↔ Figma chain. Skipping any gate is no longer possible without explicit user override:

- **`/ux preflight`** — verifies every token/component/pattern named in `ux-spec.md` exists in the codebase. Caught 4 P0 spec errors during the import-training-plan resume; saves 2-4h of "no such symbol" Phase 4 rework per feature on average.
- **`/design preflight`** — extends `/ux preflight` with Figma MCP liveness + Figma library accessibility check. Writes `figma-bridge-status.json`. Failure → spec NOT approvable.
- **`/design build`** — auto-dispatched at Phase 3.j. Pushes screens into the FitMe Design System Library (`0Ai7s3fCFqR5JXDW8JvgmD`) via Figma MCP, falls back to portable prompt at `docs/prompts/ui/{date}-{feature}-design-build.md` when MCP unreachable. Writes captured Figma node IDs back to `state.json.figma_node_ids` AND adds row to `figma-code-sync-status.md`.
- **`/ux pre-merge-review`** — Phase 6 gate. Heuristic re-check of shipped code vs approved spec. Sets `state.json.pre_merge_review.ux`. BLOCK halts Phase 7.
- **`/design pre-merge-review`** — Phase 6 gate. `make ui-audit` P0=0 + `state.json.figma_node_ids` populated + PR description references those node IDs (CLAUDE.md "Synced" definition mandates this). Sets `state.json.pre_merge_review.design`. BLOCK halts Phase 7.
- **`make skill-preflight SKILL=<name>`** (v7.9.1, pattern↔skill overlay) — at any skill's activation, probes the Observed-Patterns-Catalog patterns mapped to that skill's work (`.claude/shared/pattern-skill-map.json`) — mechanized ones probed live, manual ones surfaced as a checklist — so blockers clear BEFORE work begins. `make gen-skill-preflight` regenerates the per-skill tables in each SKILL.md. See [`docs/skills/pattern-skill-overlay.md`](docs/skills/pattern-skill-overlay.md).

**PR description requirement (enforced):** every UI-touching PR must reference the Figma node IDs of the screens it touches. The IDs come from `state.json.figma_node_ids` (populated by `/design build`) and are validated by `/design pre-merge-review`. See `docs/skills/design.md` for the full `figma_node_ids` schema.

**Folder convention:** `docs/prompts/ux/` for `/ux prompt` outputs, `docs/prompts/ui/` for `/design prompt` outputs, `docs/prompts/_legacy/` for hand-authored historical prompts.

Full documentation: [`docs/skills/evolution.md`](docs/skills/evolution.md) §26.

### v4.X+CC Cross-repo Code Connect bridge (added 2026-05-09 → 2026-05-10; ⛔ DISABLED 2026-06-15)

> ⛔ **DISABLED 2026-06-15 — Code Connect is not operational.** A full design-system audit found the
> Code Connect publish bridge has **failed on every real run since 2026-05-10** in both repos. Root
> cause: Figma Code Connect requires an **Organization/Enterprise** plan; this account is **Pro**
> (iOS publish → 403 "Invalid scope(s)"; web publish → W14, page-frame mappings `31-3`/`31-106`
> abort validation). The Figma library files are also empty/partial, so the node IDs cited in this
> section do not exist live. Both `figma-code-connect-publish.yml` workflows are now disabled stubs.
> The `.figma.{swift,tsx}` mappings + configs remain in-tree but **inert**. **Code is the source of
> truth.** Decision + rebuild plan: [`docs/design-system/figma-source-of-truth-plan-2026-06-15.md`](docs/design-system/figma-source-of-truth-plan-2026-06-15.md);
> honesty ledger [FT2-FH-005](docs/case-studies/framework-honesty-ledger.md). The historical record below is retained for context.

Closes the loop in the OTHER direction: `/design build` pushes screens INTO Figma; the Code Connect bridge maps Figma library frames BACK to source code so Dev Mode shows the actual React/SwiftUI snippet for each component. Cross-repo, both web and iOS.

**Foundation:**

- **Web (fitme-story):** `.figma.tsx` mapping files → file `fsjHfFLAHELACZHku8Rfcl` (FitMe Story Web — Design System). Parsed by `@figma/code-connect` npm package directly. Foundation: fitme-story PR #75 (T20 of `fitme-story-public-enhancements` rollup) shipped 17 component node IDs + 4 new primitives (Button, Tag, CaseStudyCard, FrameworkVersionCard) + 12 mapping files; PR #80 fixed parser issues (inline URL literals, broader include glob, drop `figma.string()` props for components without named text properties).
- **iOS (FitTracker2):** `.figma.swift` mapping files → file `0Ai7s3fCFqR5JXDW8JvgmD` (FitTracker-Design-System-Library). Foundation: FT2 PR #277 (`ios-code-connect` chore feature T1+T2+T3+T5) shipped `Figma.toml` + 5 mapping files covering 6 screen-level node IDs sourced from existing shipped features. Build-safety wrapper `#if canImport(Figma)` keeps Xcode green without the Swift package installed.

**3-layer automation** (chore feature `code-connect-automation`, shipped via PRs #278/#279/#280/#281/#283 + fitme-story #77/#79):

- **Layer A — scaffold scripts.** `scripts/scaffold-figma-mapping.py` (FT2) + `scripts/scaffold-figma-mapping.mjs` (fitme-story) auto-generate `.figma.{swift,tsx}` template files from any feature's `state.json::figma_node_ids` block. Coalesces multi-state variants of the same View/component into one mapping file. Override block `figma_node_ids.code_mapping` for keys that don't match the snake_case → PascalCase heuristic.
- **Layer B — `/design build` skill extension.** After `figma_node_ids` is populated, the skill auto-invokes the scaffold script for the active repo. Closes the "manual mapping author per new UI feature" gap.
- **Layer C — CI publish workflows.** `.github/workflows/figma-code-connect-publish.yml` in BOTH repos auto-runs `figma connect publish` on push to main when `*.figma.{swift,tsx}` or config changes. Web: ubuntu runner + `npx figma connect publish`. iOS: macos-15 runner + SPM cache + `npx figma connect publish` with `figma.config.json::swiftPackagePath` pointing at `.figma-cc-tools/Package.swift` (SPM wrapper subdir; the npm CLI calls `swift run --package-path .figma-cc-tools figma-swift` as a subprocess to parse `.figma.swift` files since the npm parser doesn't natively support Swift). Both gated on `FIGMA_ACCESS_TOKEN` repo secret (operator one-time setup); skip with clear log if missing.

**Two new mechanical gates added 2026-05-10 to `/design` skill (PR #280):**

- **`/design preflight` Step 3.5 — Code Connect write-access gate.** Verifies the publish path works end-to-end (not just MCP read access). Token presence check (local env + `gh api` for repo secret in BOTH repos) + publish dry-run probe (catches missing `Code Connect Write` scope or `file_dev_resources:write`). Records to `figma-bridge-status.json::code_connect_access`. Auth-failure → P1 advisory; token absent everywhere → P2 advisory.
- **`/design pre-merge-review` Step 3.5 — Spec ↔ build parity check.** Verifies what was built matches what the spec said. Enumerates spec surfaces (parses `ux-spec.md` / `integration-spec.md`) and build surfaces (`state.json::figma_node_ids` + `.figma.{swift,tsx}` files), then cross-matches each spec surface (`complete` / `figma_only` / `mapping_only` / `missing`). BLOCK on `missing` or `mapping_only` (build incomplete). Records to `state.json.pre_merge_review.design_parity`.

**Operator setup (one-time, both repos):** generate Figma Personal Access Token at <https://www.figma.com/settings> → Security → Personal access tokens. **Required scopes:** `file_content:read` + `file_dev_resources:read` + `file_dev_resources:write` (Code Connect mappings ARE dev resources in Figma's data model — there's no explicit "Code Connect" scope). `library_content:read` is recommended for team-library design systems. Add the token as `FIGMA_ACCESS_TOKEN` repo secret in BOTH `Regevba/FitTracker2` and `Regevba/fitme-story`. Until set, both publish workflows skip cleanly.

**Companion docs:**

- iOS operator runbook: [`docs/design-system/ios-code-connect-workflow.md`](docs/design-system/ios-code-connect-workflow.md)
- Web architecture: [`docs/design-system/fitme-story-design-architecture.md`](docs/design-system/fitme-story-design-architecture.md)
- Figma↔code matrix + Code Connect verification contract: [`docs/design-system/figma-code-sync-status.md`](docs/design-system/figma-code-sync-status.md)
- Public showcase: fitme-story `/pm-flow` page §`#code-connect`

**Manual steps per new UI feature:** the code-side automation (scaffold + skill hook) shipped, but the **publish step never worked** — operator setup did *not* complete operationally (the `code_connect:write` scope is not grantable on Pro). The "2 → 0" target was **not** achieved; effective state is "Code Connect publishing unavailable on this plan." Tracked feature: [`code-connect-automation`](.claude/features/code-connect-automation/) — T1-T4 code shipped, T5 (E2E publish) permanently blocked by plan tier; bridge decommissioned 2026-06-15 (see plan above).

### Verification Layer (added 2026-04-20)

Per-PR review and `tokens-check` only catch token-definition drift. The
verification layer below catches the more common failure modes — raw
literals slipped into views, magic numbers, missing accessibility, and
the silent-fallback bug where `Color("name")` references a non-existent
colorset.

- **`make ui-audit`** — runs `scripts/ui-audit.py` across every `.swift`
  file under `FitTracker/Views` and `FitTracker/DesignSystem`. Skips
  HISTORICAL v1 files and token-definition files automatically. Exits 1
  on any P0 finding.
- **Rules:** `DS-RAW-COLOR-{MEMBER,SHORTHAND,LITERAL,UIKIT}`,
  `DS-RAW-ANIMATION`, `DS-RAW-FONT-{SYSTEM,SHORTHAND}`,
  `DS-MAGIC-{PADDING,FRAME}`, `DS-A11Y-BUTTON`, `DS-MISSING-ASSET`
  (Gap-A: `Color("name")` in AppTheme without a backing colorset).
- **Baseline:** `docs/design-system/ui-audit-baseline.md` (regenerate
  with `make ui-audit-baseline`). Baseline snapshot: 0 P0 + 103 P1
  (P0 burndown completed 2026-05-05); current live: 0 P0 + 0 P1
  (P1 burndown fully completed since baseline; verify with `make ui-audit`).
- **Fix-as-you-touch rule:** any PR touching a file with findings should
  clear that file's findings as part of the change. `ui-audit` is now a
  hard gate within `verify-local` (achieved 2026-05-05 once P0 baseline
  reached 0).
- **Verification contract:** `docs/design-system/figma-code-sync-status.md`
  Verification Contract section defines what is automatically vs
  manually verified, plus plans for closing the snapshot-test and
  Figma-API gaps.
- **Definition of "Synced"** for any screen in the Figma↔code matrix:
  no P0 findings + all assets resolve + recent verification date +
  Figma node ID referenced in the merging PR's description.

**When introducing a new `Color("name")` token in `AppTheme.swift`:**
add the matching `.colorset` directory under
`FitTracker/Assets.xcassets/Colors/...` AND a corresponding entry in
`design-tokens/tokens.json` AND the generated line in
`FitTracker/DesignSystem/DesignTokens.swift` IN THE SAME COMMIT. The
`make ui-audit` `DS-MISSING-ASSET` rule + `make tokens-check`
together enforce this; both must pass.

## UI Refactoring & V2 Rule

When a UI screen or feature needs a UX Foundations alignment pass (or any
substantial refactor against `docs/design-system/ux-foundations.md`):

1. **Create a `v2/` subdirectory next to the v1 file.** Each feature's v2
   work lives in its own `v2/` subdirectory under the same parent group.
   File names stay the same — only the directory differs:
   - `FitTracker/Views/Main/MainScreenView.swift` (v1, historical)
   - `FitTracker/Views/Main/v2/MainScreenView.swift` (v2, source of truth)
   - `FitTracker/Views/Onboarding/OnboardingWelcomeView.swift` (v1)
   - `FitTracker/Views/Onboarding/v2/OnboardingWelcomeView.swift` (v2)

   This keeps v1 and v2 next to each other for diffing while preserving
   the original file names so imports/types don't collide. Both files
   define the same Swift type (e.g. `MainScreenView`) — the build target
   only references one of them at a time.

2. **Update `FitTracker.xcodeproj/project.pbxproj`** in the same commit
   that creates the first v2 file in a new `v2/` subdirectory. The v2
   directory becomes a new PBXGroup, the v2 file becomes a PBXFileReference
   + PBXBuildFile, and the v1 file is REMOVED from the Sources build phase
   (but stays as a PBXFileReference so it shows in the file navigator and
   git history). v1 lives on as a reviewable historical artifact, not as
   compiled dead code.

3. **Build the v2 file bottom-up** from the design system foundations
   (tokens, components, ux-foundations principles) — do **not** patch the
   v1 file in place. v1 is read-only during the refactor. Use the
   `docs/design-system/v2-refactor-checklist.md` to track what's been
   verified.

4. **Wire the v2 file in** at its parent (e.g. `RootTabView.swift` keeps
   instantiating `MainScreenView()` — same type name — but the symbol now
   resolves to the v2 file because v1 has been removed from the build
   sources). No call-site change needed in parent views since the type
   name is identical; the swap happens at the project.pbxproj layer.

5. **Mark v1 as historical** with a header comment when the swap lands:
   ```swift
   // HISTORICAL — superseded by v2/{ScreenName}.swift on {date} per
   // UX Foundations alignment pass. See
   // .claude/features/{name}/v2-audit-report.md for the gap analysis.
   // This file is no longer in the build target; it stays in the repo
   // as a reviewable reference for the v1 → v2 diff.
   ```

   **Retention policy (codified 2026-05-08 per iOS audit finding F-1):** HISTORICAL v1 files are retained **indefinitely by default**. The V2 Rule's first anniversary (**2027-04-09**) is the scheduled review point for whether to introduce a year+1 prune policy (e.g., "drop HISTORICAL files older than 1 year; rely on git history"). Until then, all HISTORICAL files stay in the repo as on-disk reviewable references. As of 2026-05-05, 16 HISTORICAL files (~5K LoC) sit alongside their v2 counterparts.

6. **One v2 split per surface.** A second alignment pass on the same
   screen does not become a `v3/` directory — it patches v2 in place.
   The v1 → v2 split exists exactly to capture the *first* deliberate
   foundations-aligned rewrite of a pre-PM-workflow surface. v3+ would
   indicate the refactor methodology itself failed.

**For new UI features built from scratch** (no v1 to refactor):
- File lives at the canonical path (no `v2/` subdirectory — there's
  nothing to refactor against).
- The Phase 3 (UX) gateway is **non-skippable** — every new UI feature
  must produce a `ux-spec.md` and pass the design system compliance
  gateway before any view code is written.
- Phase 4 (Implement) starts with the `ux-foundations.md` checklist
  applied to the spec, then the view code. No "build first, audit later".

**Verification checklist:** Every v2 refactor walks through
`docs/design-system/v2-refactor-checklist.md` before requesting Phase 5
(Test) approval. The checklist covers token compliance, component reuse,
state coverage, accessibility, motion, analytics, and project.pbxproj
hygiene. State.json `phases.ux_or_integration.checklist_completed` must
be `true` before Phase 4 advances.

**Backward compatibility note:** Onboarding v2 (PR #59) was the pilot
alignment pass and shipped *before* this rule existed. It used the older
"patch v1 in place" approach. It will be retroactively refactored into
the `v2/` subdirectory convention as a follow-up to the Home v2 pass,
mostly to validate that the rule scales to a feature with multiple
screens. Tracked in the per-screen UX alignment plan in `backlog.md`.

## Analytics Naming Convention

> Established 2026-04-08 as a project-wide rule during the home-today-screen v2 audit (see `.claude/features/home-today-screen/v2-audit-report.md` Decisions Log → OQ-9).

**Every analytics event that tracks an action or interaction on a specific screen MUST include that screen name as a prefix in the event name.**

The point: when looking at an event in GA4 or any analytics dashboard, the source screen should be obvious without checking the source code. Funnel analysis, regression isolation, and per-screen metric tracking all become dramatically faster.

### Naming pattern

| Screen | Event prefix | Example events |
|---|---|---|
| Home | `home_` | `home_action_tap`, `home_metric_tile_tap`, `home_empty_state_shown` |
| Nutrition | `nutrition_` | `nutrition_meal_logged`, `nutrition_macro_viewed`, `nutrition_scanner_opened` |
| Training | `training_` | `training_workout_start`, `training_set_completed`, `training_exercise_viewed` |
| Stats | `stats_` | `stats_period_changed`, `stats_chart_interaction`, `stats_metric_drill_down` |
| Settings | `settings_` | `settings_consent_updated`, `settings_account_deleted`, `settings_export_requested` |
| Onboarding | `onboarding_` | `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped` |
| Auth | `auth_` | `auth_signin_started`, `auth_signin_completed`, `auth_passkey_registered` |

### What this rule does NOT cover

- **Cross-screen lifecycle events** stay unprefixed: `app_open`, `session_start`, `sign_in`, `sign_up`. These are global, not screen-scoped.
- **GA4 recommended events** keep their dictated names: `tutorial_begin`, `tutorial_complete`, `select_content`, `share`, `login`. GA4 dashboards depend on these.

### Enforcement

1. **PM workflow Phase 1 Analytics Spec gate** validates every new event for screen-prefix compliance when the event is tied to a screen. Non-compliant events block the PRD from approval.
2. **`/analytics spec`** sub-command checks for violations and refuses to write a spec that contains them.
3. **`docs/product/analytics-taxonomy.csv`** has a `screen_scope` column. Either a screen name (`home`, `nutrition`, etc.) or `global` for cross-screen events.
4. **`/analytics validate`** sub-command runs a periodic audit of existing events. Non-conforming events get flagged and renamed via a migration plan that preserves historical dashboards.

### Backwards compatibility

The rule applies prospectively from 2026-04-08. Existing events that pre-date the rule will be renamed during the next `/analytics validate` pass, with migration handled via GA4 event aliases (so historical dashboards keep working).

## Key Paths

### Glossaries

- **Dev-process basics (for non-developers):** [`docs/glossary-dev-basics.md`](docs/glossary-dev-basics.md) — plain-English definitions of git / CI / shell terms (commit, push, PR, grep, pre-commit hook, etc.) plus a "how a feature reaches Done" walkthrough.
- **Framework vocabulary (T1/T2/T3 tiers, Class A/B/C gates, validity closure, integrity check codes, …):** rendered at [fitme-story.vercel.app/glossary](https://fitme-story.vercel.app/glossary), source at `fitme-story/src/lib/glossary.ts`.

### Product
- PRD: `docs/product/PRD.md`
- Per-feature PRDs: `docs/product/prd/`
- Metrics: `docs/product/metrics-framework.md`
- Backlog: `docs/product/backlog.md`
- Feature state: `.claude/features/{name}/state.json`

### Master plan & handoffs
- Master plan: `docs/master-plan/master-plan-2026-04-15.md` (current; `master-plan-2026-04-06.md` retained as historical predecessor)
- RICE roadmap: `docs/master-plan/master-backlog-roadmap.md`
- Handoff archive: `docs/master-plan/` (all session summaries, stabilization reports, branch reviews)

### Skills ecosystem
- **DEV-only framework guide (v1.0 → v7.9.1):** [`docs/architecture/dev-guide-v1-to-v7-7.md`](docs/architecture/dev-guide-v1-to-v7-7.md) — start here if you are a developer onboarding to the framework. Covers the 4 enforcement layers, `state.json` schema, phase lifecycle, dispatch model, cache architecture, measurement protocol, integrity check codes, §2.4 bridge mechanisms (A–F), and operational walkthroughs (adding a feature, extending a check code, bumping the framework version). Filename retained at `-v7-7` for ref-stability across 16+ cross-references in FT2 + fitme-story; content tracks v7.9.1. **Current framework state is v7.10 (shipped 2026-06-10); for canonical, machine-derived gate counts always defer to [`docs/FRAMEWORK-FACTS.md`](docs/FRAMEWORK-FACTS.md)** — the per-version count prose scattered through this file is an accurate record of each era, not necessarily current state.
- **Lifecycle event catalog (companion to dev-guide):** [`docs/architecture/feature-lifecycle-event-catalog.md`](docs/architecture/feature-lifecycle-event-catalog.md) — answers "at any point in a feature's lifecycle, what should be triggered, logged, measured, and persisted, and which gate enforces it?" 12 sections + 2 mermaid flow diagrams (L0 phase lifecycle + per-commit fan-out across all 4 loops). Authoritative spec source for the planned `FEATURE_CLOSURE_COMPLETENESS` gate ([`framework-v7-8-branch-isolation`](.claude/features/framework-v7-8-branch-isolation/state.json)).
- Skills one-pager: `docs/skills/README.md`
- Skills architecture deep-dive: `docs/skills/architecture.md` (merged from former skills-ecosystem.md + skills-ecosystem-analysis.md)
- Ecosystem evolution history: `docs/skills/evolution.md` (v1.0 → v1.2 → v2.0 → v3.0 → v4.0 → v4.1)
- Per-skill docs: `docs/skills/{name}.md` (pm-workflow, ux, design, dev, qa, analytics, cx, marketing, research, ops, release)
- Agent-facing prompts: `.claude/skills/{name}/SKILL.md`
- Integration adapters: `.claude/integrations/{service}/` (ga4, app-store-connect, sentry, firecrawl, axe, security-audit)
- Learning cache: `.claude/cache/` (L1 per-skill, L2 `_shared/`, L3 `_project/`)
- Validation gate config: `.claude/shared/skill-routing.json` (`validation_gate` section)
- **Operations control room (in-flight migration, UCC):** the operator dashboard that surfaces every framework gate, every cycle snapshot, every measurement-adoption ledger, and the case-study feed. Currently lives at `dashboard/` (Astro 6 + React 19, deployed at `fit-tracker2.vercel.app`); migrating to `fitme-story/src/{app,components,lib}/control-room/` (Next.js 16, deployed at `fitme-story.vercel.app/control-room/*`, basic-auth gated). Pre-build sync at `fitme-story/scripts/sync-from-fittracker2.ts` mirrors `.claude/shared/*.json`, `.claude/features/*/state.json`, and the canonical doc tree. Migration is extraction-ready: see [`fitme-story/EXTRACTION-RECIPE.md`](https://github.com/Regevba/fitme-story/blob/main/EXTRACTION-RECIPE.md) for the 7-step playbook. Per-feature state for the migration: `.claude/features/unified-control-center/`. The framework-health page at `/control-room/framework` (PR #7, fitme-story) is the first UCC route shipped; remaining UCC tasks tracked in `state.json.tasks[]`.

### Design system
- UX foundations: `docs/design-system/ux-foundations.md` (13 principles)
- V2 refactor checklist: `docs/design-system/v2-refactor-checklist.md`
- Feature memory: `docs/design-system/feature-memory.md`
- Feature development gateway: `docs/design-system/feature-development-gateway.md`
- Tokens: `FitTracker/Services/AppTheme.swift` + `design-tokens/tokens.json`
- Components: `FitTracker/DesignSystem/AppComponents.swift`
- UI audit scanner: `scripts/ui-audit.py` (run via `make ui-audit`)
- UI audit baseline: `docs/design-system/ui-audit-baseline.md`
- Figma↔code matrix + Verification Contract: `docs/design-system/figma-code-sync-status.md`
- **Per-surface design-system architecture (source-of-truth + Figma-mirror layering):** iOS [`docs/design-system/ios-design-system-architecture.md`](docs/design-system/ios-design-system-architecture.md) · web [`docs/design-system/fitme-story-design-architecture.md`](docs/design-system/fitme-story-design-architecture.md). Both mirrors verified live 2026-06-18 (iOS file `0Ai7s3fCFqR5JXDW8JvgmD`, web file `fsjHfFLAHELACZHku8Rfcl`) — **code is canonical; Figma is a manually-maintained mirror** (Code Connect publish disabled on Pro plan).
- **Figma-mirror governance:** maintenance protocol [`docs/design-system/figma-mirror-maintenance-protocol.md`](docs/design-system/figma-mirror-maintenance-protocol.md) + advisory drift check `make figma-mirror-staleness` (`scripts/figma-mirror-staleness.py`, snapshot `.claude/shared/figma-mirror-snapshot.json`). Closes FT2-FH-005 Gap D.

### Handoff prompts
- UX/UI build prompts (auto-generated + hand-authored): `docs/prompts/`
- Auto-generation contracts: `/ux prompt {feature}` + `/design prompt {feature}` (see `docs/skills/ux.md` and `docs/skills/design.md`)

### Case studies
- Narrative showcases of the PM workflow running on real features: `docs/case-studies/`
- Pilot case study (Onboarding v2): `docs/case-studies/pm-workflow-showcase-onboarding.md`
- Data quality tiers convention: `docs/case-studies/data-quality-tiers.md` (T1/T2/T3 labeling, est. 2026-04-21)
- Meta-analyses + independent audits: `docs/case-studies/meta-analysis/`
- External audit substrate: [`docs/audits/prompts/`](docs/audits/prompts/) — two operator-facing prompts + `scripts/audit/build_bundle.py` deterministic bundle helper. Powers the External Audits (2026-05-22, 2026-06-12, 2026-08-05, 2026-10-08) + quarterly Data Freshness Audits (2026-08-12, 2026-11-12, 2027-02-12, 2027-05-12) per infra master plan §5. Spec: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md).
- **Publication + chronological-order rule (est. 2026-04-30):** every feature that transitions to `complete` MUST have BOTH a source case study at `docs/case-studies/<feature>-case-study.md` AND a published showcase MDX at `fitme-story/content/04-case-studies/`. The showcase's slot-number filename prefix AND `timeline_position.order` MUST reflect the framework version under which the feature shipped — not the publication date. A v5.1 feature published retroactively still slots in chronologically: use a fractional `order` (e.g. `8.5`) and an intercalating filename prefix (e.g. `08a-`) so existing slots don't get renumbered. At PR review, a showcase MDX claiming `version: '5.1'` placed below a `version: '6.0'` slot is a review block. Publication is verified via the `case_study_showcase` field in `state.json` pointing at a real MDX in fitme-story (the existing `STATE_NO_CASE_STUDY_LINK` write-time gate enforces the source case study; chronological position is enforced at PR review for now).

### Process docs (Gemini audit Tier groundwork)
- Index: `docs/process/README.md`
- Runtime smoke gates (Tier 2.1): `docs/process/runtime-smoke-gates.md` + `make runtime-smoke PROFILE=<id> MODE=<local|staging>`
- Contemporaneous logging (Tier 2.2): `docs/process/contemporaneous-logging.md` + `scripts/append-feature-log.py` + `.claude/logs/<feature>.log.json`
- Documentation-debt dashboard (Tier 3.2): `docs/process/documentation-debt-dashboard.md` + `make documentation-debt` + `.claude/shared/documentation-debt.json`
- Auth-runtime verification playbook: `docs/setup/auth-runtime-verification-playbook.md`
- Pre-commit state.json schema enforcement (Tier 1.3): `.githooks/pre-commit` + `make install-hooks` + `scripts/check-state-schema.py`
- Independent-audit remediation tracker: `trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`

### Setup guides
- One-time environment + service setup: `docs/setup/`
- SSD layout: `docs/setup/ssd-setup-guide.md`
- Firebase Analytics: `docs/setup/firebase-setup-guide.md`
- Dashboard activation: `docs/setup/dashboard-activation.md`
- Integrations setup: `docs/setup/integrations-setup-guide.md`
- Auth runtime verification: `docs/setup/auth-runtime-verification-playbook.md`
- UCC passkey auth (going-live runbook): `docs/setup/ucc-passkey-auth-setup-guide.md`
