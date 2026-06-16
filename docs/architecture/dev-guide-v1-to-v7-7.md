# PM Framework — Developer Guide (v1.0 → v7.10)

> **Audience:** developers landing in this codebase who need to understand how the PM framework actually works — not the marketing narrative, not the case-study story arc, but the wiring. If you are about to add a new feature, extend a check code, fix a CI workflow, or bump the framework version, start here.
>
> **Current version:** **v7.10** (shipped 2026-06-10) — observability hardening of the gates themselves: the `GATE_COVERAGE_ZERO` meta-check gained a 0-candidate mis-wire detector, three cycle-time checks (`BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `PATTERN_SKILL_UNMAPPED`) now emit Mechanism A coverage so the F17 index can see them, and a field-rename silent-pass class was closed in the measurement layer (observed-patterns #24). T10 AI golden-set evals also shipped. **0 new product-facing enforcement gates.** Predecessor v7.9.1 (single-day build window, 8 observability ships across 14 PRs, closed 2026-06-04) is the most recent gate-shipping window; synthesis case study: [`framework-v7-9-1-promotion-case-study.md`](../case-studies/framework-v7-9-1-promotion-case-study.md). For v7.9 (the enforcement-flip release shipped 2026-05-21 — 3 advisory gates → enforced via single-flag flip at `scripts/check-state-schema.py:149`) see [§2.0](#20-predecessor-snapshot-v79-shipped-2026-05-21). For canonical current gate counts always defer to [`docs/FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md). For prior versions see [§12 timeline](#12-compressed-evolution-timeline-v10--v710).
> **Filename note:** the file stays `dev-guide-v1-to-v7-7.md` for ref-stability across 16+ cross-references in FT2 + fitme-story. Content tracks the latest framework version (v7.10).
> **Companion docs:** [`docs/architecture/feature-lifecycle-event-catalog.md`](./feature-lifecycle-event-catalog.md) (event/log/gate catalog with mermaid flow diagrams), [`docs/skills/architecture.md`](../skills/architecture.md) (skill-by-skill anatomy), [`docs/skills/evolution.md`](../skills/evolution.md) (full version-by-version history), [`CLAUDE.md`](../../CLAUDE.md) (project rules, fastest reference).
> **Reading order:** §0 is a 90-second tour. §1 is audience and reading hints. §1.5 is the glossary. §§ 2–3 give you the mental model. §§ 4–8 are the schemas and contracts you'll edit against. §§ 9–11 are the integrity layer (where failures get caught). § 12 is the compressed timeline. §§ 13–15 are operational walkthroughs. § 16 is the cross-repo Code Connect bridge. § 17 is references.

---

## Table of Contents

- [§0. TL;DR — 90-second tour](#0-tldr--90-second-tour)
- [§1. Audience and how to read](#1-audience-and-how-to-read)
- [§1.5 Glossary](#15-glossary)
- [§2. Big picture (current state — v7.10, shipped 2026-06-10)](#2-big-picture-current-state--v710-shipped-2026-06-10)
- [§3. Where the code lives](#3-where-the-code-lives)
- [§4. The skill ecosystem (hub + 11 spokes)](#4-the-skill-ecosystem-hub--11-spokes)
- [§5. `state.json` — the canonical per-feature contract](#5-statejson--the-canonical-per-feature-contract)
- [§6. Phase lifecycle (9 phases × 4 work types)](#6-phase-lifecycle-9-phases--4-work-types)
- [§7. Dispatch model — how skills get invoked](#7-dispatch-model--how-skills-get-invoked)
- [§8. Cache architecture (L1 per-skill, L2 shared, L3 project)](#8-cache-architecture-l1-per-skill-l2-shared-l3-project)
- [§9. Measurement protocol (CU formula, cache_hits, timing)](#9-measurement-protocol-cu-formula-cache_hits-timing)
- [§10. Integrity layer — write-time + per-PR + cycle-time + weekly](#10-integrity-layer--write-time--per-pr--cycle-time--weekly)
- [§11. Pre-commit hooks and GitHub Actions](#11-pre-commit-hooks-and-github-actions)
- [§12. Compressed evolution timeline (v1.0 → v7.10)](#12-compressed-evolution-timeline-v10--v710)
- [§13. Operational walkthrough — adding a new feature](#13-operational-walkthrough--adding-a-new-feature)
- [§14. Operational walkthrough — extending an integrity check code](#14-operational-walkthrough--extending-an-integrity-check-code)
- [§15. Operational walkthrough — bumping the framework version](#15-operational-walkthrough--bumping-the-framework-version)
- [§16. Cross-repo Code Connect bridge (orthogonal capability)](#16-cross-repo-code-connect-bridge-orthogonal-capability)
- [§17. References](#17-references)

---

## 0. TL;DR — 90-second tour

**What this framework does.** Every feature passes through a 9-phase lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs) and is gated by automated checks at four cadences. Drift between code and documentation is caught fast.

**The 4 enforcement layers (§2.2):**

| Layer | Cadence | Where it lives |
|---|---|---|
| 1. Write-time | every `git commit` (~3-5s) | `.githooks/pre-commit` |
| 2. Per-PR | every push to a PR (~1-3min) | `.github/workflows/pr-integrity-check.yml` |
| 3. 72h cycle | cron, every 3 days at 04:00 UTC | `.github/workflows/integrity-cycle.yml` |
| 4. Weekly | cron, Mondays 05:00 UTC | `.github/workflows/framework-status-weekly.yml` |

**The 1 file you touch most.** [`.claude/features/<name>/state.json`](#5-statejson--the-canonical-per-feature-contract) — your feature's lifecycle contract. Schema is enforced at write-time.

**The 1 command you run most.** `/pm-workflow <feature-name>` — creates state.json, drives phase transitions, dispatches the right skill per phase, gates each transition.

**Where to next.**
- New to the framework? → §1 (audience) → §1.5 (glossary) → §2 (big picture) → §3 (where the code lives)
- Writing a feature? → §13 walkthrough
- Adding a check code? → §14 walkthrough
- Bumping the framework version? → §15 walkthrough (and: don't forget to bump THIS doc — see §15's "what NOT to skip" callout)

---

## 1. Audience and how to read

This guide is for **developers**. If you are a PM looking for product workflow, read [`docs/skills/pm-workflow.md`](../skills/pm-workflow.md). If you are reading the project as evidence of an AI workflow approach, start with [`docs/case-studies/`](../case-studies/) (start at `01-onboarding-pilot.mdx` on the `fitme-story` showcase).

The framework is not a single library you import. It is a set of conventions implemented across:
- **Markdown documents** that describe each skill (`.claude/skills/<name>/SKILL.md`) and shared state (`.claude/shared/*.json`).
- **Python scripts** that enforce or measure invariants (`scripts/*.py`).
- **GitHub Actions workflows** that run the scripts on schedules and on every PR (`.github/workflows/*.yml`).
- **A pre-commit hook** that runs the same scripts locally before any commit lands (`.githooks/pre-commit`).
- **Per-feature state files** that track each in-flight feature's lifecycle (`.claude/features/<name>/state.json`).

There is **no compiled binary**. The framework is the union of the conventions above, the scripts that enforce them, and the agents (Claude Code, Claude Desktop, Codex, etc.) that follow them.

---

## 1.5 Glossary

Cross-cutting terms used throughout this guide and in commit messages, PR descriptions, and case studies. If a term is unfamiliar in §§ 2–15, look it up here first.

| Term | Definition |
|---|---|
| **Mechanism A–F** | The six v7.8 bridge mechanisms (§2.4). A = coverage-asserting gates (`gate-coverage.jsonl`). B = schema field-rename detection + dual-read. C = `PostToolUse:Read` attribution (auto-captures cache hits). D = pre-commit hook header self-audit. E = custom git merge driver for append-only ledgers. F = membrane status advisory (`make membrane-status`). |
| **T1 / T2 / T3** | Data quality tiers for every quantitative claim in a PRD, case study, or meta-analysis. T1 = Instrumented (live metric). T2 = Declared (PRD target / pre-registered). T3 = Narrative (estimate). Convention: [`docs/case-studies/data-quality-tiers.md`](../case-studies/data-quality-tiers.md). |
| **Class A / B / C** | Gate categorization. Class A = mechanically enforced. Class B = mechanically unclosable (requires judgment, external operator, or physical device — see §2.3, currently 4 gaps). Class C = advisory en route to enforced after a calibration window. |
| **Advisory vs enforced** | An advisory gate emits a finding but does NOT block a commit. An enforced gate blocks. Most v7.8 mechanisms ship advisory, then promote to enforced after ≥7 days of Mechanism A telemetry shows zero false positives. v7.9 promoted 3 advisories to enforced via a single-flag flip (§2.0). |
| **Write-time / Per-PR / Cycle-time / Weekly** | The 4 enforcement layers (§2.2). Write-time = pre-commit (every commit). Per-PR = GitHub Actions on every push. Cycle-time = 72h cron. Weekly = Mondays 05:00 UTC, observational. |
| **CU (Composite Units)** | The v6.0 measurement protocol's normalized "size of work" score. CU formula v2 has 4 continuous factors: complexity, blast_radius, novelty, verification_difficulty. See §9.1. |
| **Gate vs check code** | A gate is the mechanism (a script that runs at a given cadence). A check code is the finding type the gate emits (e.g., `SCHEMA_DRIFT`, `PHASE_LIE`). One gate emits multiple check codes. |
| **Skill / spoke / hub** | The framework runs as 12 skills. `pm-workflow` is the hub (always loaded). The other 11 are spokes (loaded on demand based on the active phase per `skill-routing.json`). See §4. |
| **Phase E** | A post-promotion validation soak (typically 14 days) where no new gates ship and the operator watches `gate-coverage.jsonl` for unexpected `failure` rows. v7.9 Phase E ran 2026-05-21 → 2026-06-04. |
| **state.json** | Per-feature canonical contract at `.claude/features/<name>/state.json`. The single source of truth for that feature's lifecycle. See §5. |
| **`/pm-workflow`** | The agent command that creates state.json, drives phase transitions, dispatches the right skill per phase. The 1 command you run most. |
| **Observed Patterns Catalog** | [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) (v7.8.5). The canonical manifest of gate-firing patterns — 23 gate patterns + 32 workflow (W1–W32). When a gate fires, consult it FIRST (§10.5). `make observed-patterns`. |
| **`make preflight`** | The unified pre-work aggregator (v7.8.6). `make preflight WORK_TYPE=<feature\|enhancement\|fix\|chore>` runs every pre-work check (ssh-agent, PR-cache freshness, branch isolation, integrity findings, drift-vs-anchor, doc-debt, adoption, W20 freshness) into `preflight-cache.json`. Mandatory Phase 0.0 step (§10.6). |
| **`state_owner`** | Required top-level state.json enum (`{ft2, fitme-story}`, v7.8.3) declaring which repo holds the canonical state file. Enforced by the `STATE_OWNER_*` gates. |
| **snapshot-phase / integrity-diff** | `make snapshot-phase` (v7.8.3) writes a per-phase off-SSD backup; `make integrity-diff` (v7.8.6) diffs current platform state vs the 2026-05-14 baseline anchor. |

---

## 2. Big picture (current state — v7.10, shipped 2026-06-10)

### Current version snapshot (v7.10, shipped 2026-06-10)

**v7.10 hardens the observability of the gates themselves** — the meta-layer that watches whether each gate is actually running. No new product-facing gates. Three changes: (1) `GATE_COVERAGE_ZERO` (built v7.9.1 #673, extended #689) gained a 0-candidate mis-wire detector — a gate registered in the F17 index with `candidates==checked==skipped==0` runs but never reaches a candidate (the `cache_hits`-keying / unreachable-loop class), distinct from a healthy zero-firing gate; (2) three cycle-time checks (`BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `PATTERN_SKILL_UNMAPPED`) now emit `mode="cycle"` Mechanism A coverage (#689) — previously the F17 index was blind to them; (3) observed-patterns #24 closed a field-rename silent-pass in the measurement layer (#687/#688). T10 AI golden-set evals also shipped (#691). For canonical current gate counts defer to [`docs/FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md).

**Predecessor — v7.9.1 was a single-day build window** that opened at v7.9 Phase E exit (2026-06-04) and closed the same day. **0 new enforcement gates** added — Phase E exit discipline preserved (no new gates for the first 14 days post-promotion). 8 ships across 14 PRs, all observability surfaces, doc updates, reusable substrates, or warn-only CI workflows.

**Ships (cascade order, grouped by theme):**

| Theme | Ships | PRs |
|---|---|---|
| **Gate-test depth (Layer 3)** | F16 try-repo harness | #607-#612 |
| **Derived telemetry materialization** | F17 last_fired_at index | #617 |
| **Defense against post-squash-merge state drift** | F2 Phase 0 reality-check sub-step | #618 |
| **Operator-side lint integration (Track B)** | R7 SwiftLint + R8 ruff + R12 markdownlint (Makefile + lint.yml CI workflow) | #619 |
| **Silent-pass closures** (5 ships) | F-LAUNCHD-DRIFT-EXTENSION (b)+(c) + (a) (cron-context); F-DEPLOYED-URL-PROBE FT2 substrate (W18 og:image + W19 GA_ID); F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE (soak-window denominator dilution); W29-W32 observed-patterns batch | #620 + #621 + #622 + #623 + #624 + #625 + #628 |
| **Coverage CI telemetry** | R9 Track B (Slather + pytest-cov + coverage.yml) | #626 |
| **Dev-env hygiene batch** | R11 gitleaks + R13 pip-audit + R14 SBOM + R17 commitlint + R18 shellcheck | #627 |

**Quantitative roll-up:**

| Dimension | Pre-2026-06-04 | Post-2026-06-04 |
|---|---|---|
| Write-time gates | 12 enforced | 12 enforced (no new) |
| Cycle-time gates | 13 enforced + 3 advisories | 13 + 3 (no new) |
| **CI workflows baseline** | **8** | **14 (+6)** |
| **Observed-patterns** | **W1-W28 (28 workflow patterns)** | **W1-W32 (32, +4)** |
| FT2 dev-env open R-items (Tier 2-3) | 7 | **0** |
| Reusable shell substrates | 0 | 1 (`scripts/probe-deployed-url.sh`) |
| v7.9.1 docket open candidates | 7 | **2** (both fitme-story-side) |

**Calendar-anchored follow-ups:**

- **2026-06-11** — T+7d verification of F-LAUNCHD-DRIFT-EXTENSION + F-DEPLOYED-URL-PROBE (fault-injection)
- **2026-06-12** — External Audit #2 (operator-driven; audit pack includes today's gitleaks + pip-audit JSON artifacts + future SBOM)
- **2026-06-18** — F16 T11 advisory→enforced flip (calibration window ends; same single-line-flip pattern as v7.9)
- **2026-07-04** — R9 Track B 30-day coverage data read → v8.0 `GATE_TEST_MISSING` calibration

**Cross-references:**

- **Synthesis case study:** [`framework-v7-9-1-promotion-case-study.md`](../case-studies/framework-v7-9-1-promotion-case-study.md) — full §0-§99 narrative including cross-cutting themes (silent-pass closures, post-Phase-E cadence, cascading rebase rhythm), risk register, lessons codified
- **Per-feature case studies (preserved for FEATURE_CLOSURE_COMPLETENESS gate):** `f16-try-repo-harness-case-study.md`, `f17-last-fired-at-index-case-study.md`, `f2-phase-0-reality-check-case-study.md`, `f-launchd-drift-extension-case-study.md`, `f-launchd-drift-extension-sub-a-case-study.md`, `f-phase-e-adoption-freeze-discipline-case-study.md`, `r9-track-b-coverage-aggregator-case-study.md`, `dev-env-r11-r13-r14-r17-r18-batch-case-study.md`, `f-deployed-url-probe-ft2-case-study.md`
- **Observed-patterns additions:** [`observed-patterns.md`](../../.claude/integrity/observed-patterns.md) W29 (inline MDX import no-op under compileMDX) + W30 (Q6 PR-list parity gate YAML parser quirk) + W31 (workflow delivery anomaly) + W32 (close-feature.py --force-incomplete)
- **CLAUDE.md anchor:** `## v7.9.1 Build Window (shipped 2026-06-04 — 8 ships, 14 PRs)` section

### 2.0 Predecessor snapshot (v7.9, shipped 2026-05-21)

v7.9 is the **enforcement-flip release**. No new gate code, no new schema fields, no new observability surfaces. A single-line edit at [`scripts/check-state-schema.py:138`](../../scripts/check-state-schema.py) flipped `BRANCH_ISOLATION_ADVISORY_MODE` from `True` to `False`, promoting 3 v7.8.1 advisory gates simultaneously to enforced.

**Gates promoted (3 advisory → 3 enforced):**

| Gate | 14d telemetry | Skip reasons (all legit) |
|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B (infra commit-level) | 18 firings, 0 zero-candidate | `not_infra_commit_level` × 13 |
| `BRANCH_ISOLATION_VIOLATION` Mode C (per-state.json) | 13 firings, 0 zero-candidate | separate emission key |
| `FEATURE_CLOSURE_COMPLETENESS` (write-time) | 13 firings, 0 zero-candidate | `not_complete_transition` × 11, `no_phase_change` × 1 |

All four §2.2 promotion criteria (coverage ≥ 7d, no false positives, no silent skips, reversibility < 5 min) were met. Phase E validation soak runs 2026-05-21 → 2026-06-04.

**Gates that stay advisory by design (NOT promoted at v7.9):**

| Gate | Why |
|---|---|
| `BRANCH_ISOLATION_HISTORICAL` cycle-time | T17 forward-only audit — historical features predating the gate cannot retroactively pass |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time | T18 macOS-only — environment-specific |
| `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror | T19 `--no-verify` bypass catcher — fires when the write-time gate is bypassed |

**Reversibility:** single-line revert + commit + merge to main = < 5 min. Documented in [`.claude/entrypoints/framework-v7-9.md`](../../.claude/entrypoints/framework-v7-9.md) reversibility-runbook section.

**Full lineage:** [v7.9 case study](../case-studies/framework-v7-9-promotion-case-study.md) | [v7.9 entrypoint](../../.claude/entrypoints/framework-v7-9.md) | [FT2-FH-003 honesty ledger entry](../case-studies/framework-honesty-ledger.md#ft2-fh-003).

### 2.1 What the framework does, in one sentence

It enforces that every feature passes through a defined lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs), records its state and timing in a machine-readable file, and is gated by automated checks at write-time, per-PR, and on a 72h schedule so that drift between code and documentation is caught fast.

### 2.2 The four enforcement layers (v7.9 — 3 advisories promoted to enforced 2026-05-21)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 1 — WRITE-TIME (pre-commit hooks, ~3-5s)                     │
│  Fires on every `git commit`. Blocks the commit if it fails.        │
│  Scripts: scripts/check-state-schema.py + check-case-study-preflight │
│  Check codes: SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED,                    │
│               PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING,   │
│               BROKEN_PR_CITATION (write-time),                       │
│               CASE_STUDY_MISSING_TIER_TAGS                           │
└─────────────────────────────────────────────────────────────────────┘
              │                                     ▲
              │ commit lands                        │ also runs as
              ▼                                     │ rear-guard
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 2 — PER-PR (GitHub Actions, ~1-3min per push)                │
│  Workflow: .github/workflows/pr-integrity-check.yml                 │
│  Compares PR HEAD findings vs origin/main baseline (worktree).      │
│  Status check: pm-framework/pr-integrity → required for merge.      │
└─────────────────────────────────────────────────────────────────────┘
              │ PR merges to main
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 3 — 72h CYCLE (GitHub Actions cron, every 3 days at 04:00Z)  │
│  Workflow: .github/workflows/integrity-cycle.yml                    │
│  Script: scripts/integrity-check.py (13 cycle-time + 3 advisories)  │
│  Snapshots ledger to .claude/integrity/snapshots/.                  │
│  Opens issue on regression vs prior snapshot.                       │
└─────────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 4 — WEEKLY (GitHub Actions cron, Mondays 05:00Z)             │
│  Workflow: .github/workflows/framework-status-weekly.yml            │
│  Snapshots measurement-adoption-history.json + documentation-debt.  │
│  Opens issue on adoption regression. OBSERVATIONAL (does not block).│
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 The 4 mechanically unclosable Class B gaps (Gap 1 promoted to enforced at v7.9)

The four layers above catch what a deterministic script can catch. Five gaps remain Class B (agent-attention, judgment, or external-dependency) at v7.7. v7.8 closed Gap 1 (`cache_hits[]` writer-path) in advisory mode via Mechanism C — capture is automatic, but writer-path adoption is not yet enforced. v7.9 promotes that to enforced once 7+ days of session-ledger data calibrate the threshold (window opens 2026-05-11). The list is documented in [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md):

1. **`cache_hits[]` writer-path adoption** — **✅ CLOSED at v7.9** (was issue #140, agent-must-remember-to-log-hits, the original Class B gap). Closed via the v7.8 advisory `PostToolUse:Read` hook (Mechanism C) → promoted to enforced at v7.9 via `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`. Pre-Mechanism-C features (`created_at < 2026-05-02`) remain exempt from `CACHE_HITS_EMPTY_POST_V6`.
2. `cu_v2` factor *correctness* — magnitudes are judgment-based.
3. T1/T2/T3 tag *correctness* — preflight checks presence, not whether the tag is right.
4. Tier 2.1 real-provider auth — physical device required.
5. Tier 3.3 external replication — external operator required.

If you are a developer reading this guide, your code rarely needs to reason about Class B gaps directly — they exist as documented exceptions to the "everything is mechanical" framing. But if you are *adding* a check code, ask: "is what I'm checking deterministic, or am I trying to mechanize a judgment?" The latter belongs in the Class B inventory, not in `check-state-schema.py`.

### 2.4 The v7.8 bridge mechanisms (A–F)

v7.8 (shipped 2026-05-04 across 9 PRs: #173 + #185–#189 + #193–#195) added six cooperating mechanisms that close silent-pass and inter-agent context-handoff gaps without yet promoting them to Class A. All ship advisory; v7.9 (measurement window opens 2026-05-11) promotes the proven ones to enforced.

| Mech | Name | What it does | Where the data lands |
|------|------|--------------|----------------------|
| **A** | Coverage-asserting gates | Every write-time gate emits `{candidates, checked, skipped, skip_reasons}` per run; `GATE_COVERAGE_ZERO` advisory fires when a gate stays at `checked=0` for 7+ days | [`.claude/logs/gate-coverage.jsonl`](../../.claude/logs/gate-coverage.jsonl) |
| **B** | Schema field-rename detection + dual-read | `created` ∪ `created_at` dual-read for migration window; canonical `framework_version` field on all features; `agent_manifest` + `_meta.deprecation_warnings` schema bridges populated but un-validated until v7.9 | [`scripts/migrate-state-v7-8-bridge.py`](../../scripts/migrate-state-v7-8-bridge.py) |
| **C** | PostToolUse:Read attribution | Auto-captures Read events with active-feature tag; advisory `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` fires when session ledger has Reads but `state.json::cache_hits[]` is empty | [`.claude/logs/_session-<id>.events.jsonl`](../../.claude/logs/) + [`.claude/active-feature`](../../.claude/) lockfile |
| **D** | Pre-commit hook header self-audit | Validates the hook header matches the implementation (catches drift between docstring and code) | [`make pre-commit-self-test`](../../Makefile) → `scripts/pre-commit-self-test.py` |
| **E** | Custom git merge driver | Auto-resolves merge conflicts on append-only ledgers (`measurement-adoption-history.json`, `documentation-debt.json`) via union-dedup-by-key | [`scripts/merge-driver-dedup.py`](../../scripts/merge-driver-dedup.py); registered by `make install-hooks`; `.gitattributes` opts in |
| **F** | Membrane status advisory | Single readout: active feature + recent gate firings + dispatch-blocker state — closes inter-agent context-handoff gap | [`make membrane-status`](../../Makefile) → `scripts/membrane-status.py`; surfaced via SessionStart hook |

Full design: [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md). Live append-only journal: [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md).

**The v7.8 design principle:** every new mechanism ships with a coverage ledger (Mechanism A) so we can measure its effective coverage before promoting to enforced. v7.7's `CACHE_HITS_EMPTY_POST_V6` shipped at 0/46 effective coverage for 4 days because the gate read `created_at` while 43/46 features used the legacy `created` key — a silent-pass that Mechanism A would have caught immediately. v7.8's lesson is that we don't trust a gate until its coverage ledger says it's actually firing.

> The v7.9 promotion outcome — gate-by-gate telemetry, reversibility runbook, and the Phase E calendar — moved to [§2.0 Current version snapshot](#20-current-version-snapshot-v79-2026-05-21) above so it surfaces as the first thing inside §2 instead of being buried at §2.4.1. The content is identical.

---

## 3. Where the code lives

```
FitTracker2/
├── .claude/
│   ├── features/<feature-name>/state.json   ← per-feature state (1 per feature)
│   ├── logs/<feature-name>.log.json         ← per-feature contemporaneous log
│   ├── shared/                              ← shared cross-feature state
│   │   ├── framework-manifest.json           ← framework version + capabilities
│   │   ├── feature-registry.json             ← list of all features
│   │   ├── change-log.json                   ← cross-feature change events
│   │   ├── measurement-adoption.json         ← v6.0 adoption ledger (current)
│   │   ├── measurement-adoption-history.json ← v6.0 adoption (append-only)
│   │   ├── documentation-debt.json           ← Tier 3.2 debt ledger
│   │   ├── case-study-monitoring.json        ← case-study health
│   │   ├── skill-routing.json                ← skill phase routing config
│   │   └── … (~24 shared state files total)
│   ├── skills/<skill-name>/SKILL.md         ← agent-facing skill prompt (12 skills since 2026-05-14; was 11 through v7.8.4)
│   ├── integrations/<service>/              ← per-service adapters (ga4, sentry…)
│   ├── cache/                                ← learning cache (L1 + L2 _shared/ + L3 _project/)
│   └── integrity/
│       ├── README.md                         ← integrity layer canonical entry
│       ├── observed-patterns.md              ← gate-firing pattern catalog (v7.8.5; `make observed-patterns`)
│       └── snapshots/                        ← 72h cycle snapshots (committed)
├── scripts/
│   ├── check-state-schema.py                 ← write-time + cycle (state.json gates incl. branch-isolation + state_owner)
│   ├── check-case-study-preflight.py         ← write-time (case studies)
│   ├── integrity-check.py                    ← cycle-time check codes + advisories
│   ├── ensure-pr-cache-fresh.py              ← PR_CACHE_STALE auto-refresh (v7.8.4)
│   ├── observe-cache-hit.py                  ← Mechanism C PostToolUse:Read capture (v7.8)
│   ├── check-branch-drift.py                 ← W9 branch-drift PostToolUse:Bash alert (v7.8.5)
│   ├── check-ssh-agent.sh                    ← W1 ssh-agent SessionStart preflight (v7.8.6)
│   ├── membrane-status.py                    ← Mechanism F membrane readout
│   ├── preflight.py                          ← unified pre-work aggregator (v7.8.6)
│   ├── cross-layer-freshness.py              ← W20 freshness scan (v7.8.6)
│   ├── daily-integrity-checkpoint.py         ← daily launchd cron job
│   ├── integrity-diff.py                     ← diff vs baseline anchor (v7.8.6)
│   ├── snapshot-phase-completion.sh          ← per-phase off-SSD backup (v7.8.3)
│   ├── merge-driver-dedup.py                 ← Mechanism E ledger merge driver
│   ├── measurement-adoption-report.py        ← Tier 1.1 ledger generator
│   ├── append-feature-log.py                 ← contemporaneous log writer
│   ├── documentation-debt-report.py          ← Tier 3.2 ledger generator
│   ├── runtime-smoke-gate.py                 ← Tier 2.1 smoke runner
│   └── test-v7-5-pipeline.sh                 ← mechanical-enforcement regression test
├── .githooks/pre-commit                       ← orchestrates write-time checks
├── .github/workflows/
│   ├── ci.yml                                ← Xcode build + test
│   ├── integrity-cycle.yml                   ← 72h cycle (cron 0 4 */3 * *)
│   ├── pr-integrity-check.yml                ← per-PR (v7.6 Phase 2a)
│   └── framework-status-weekly.yml           ← weekly cron (v7.6 Phase 2c)
├── docs/
│   ├── architecture/
│   │   └── dev-guide-v1-to-v7-7.md          ← THIS FILE
│   ├── skills/
│   │   ├── architecture.md                   ← skill-by-skill anatomy
│   │   ├── evolution.md                      ← full version-by-version history
│   │   └── pm-workflow.md                    ← user-facing PM workflow doc
│   ├── case-studies/                         ← all shipped case studies
│   │   ├── data-integrity-framework-v7.5-case-study.md
│   │   ├── mechanical-enforcement-v7-6-case-study.md
│   │   └── meta-analysis/unclosable-gaps.md
│   ├── process/                              ← process docs (Tier groundwork)
│   ├── product/                              ← PRDs, metrics, backlog
│   └── design-system/                        ← UX foundations + component memory
├── trust/
│   └── audits/2026-04-21-gemini/             ← independent audit + remediation
└── CLAUDE.md                                 ← project rules (fastest reference)
```

**Companion repo (separate git):** `/Volumes/DevSSD/fitme-story` — Next.js showcase site. Trust page (`/trust/audits/2026-04-21-gemini`) and case-studies index live there. The fitme-story repo cross-links to the main repo's case studies via raw GitHub URLs.

---

## 4. The skill ecosystem (hub + 11 spokes)

The framework runs as **12 skills** (since 2026-05-14; was 11 through v7.8.4) following a hub-and-spoke pattern:

- **Hub:** `pm-workflow` — owns the lifecycle, dispatches work to spokes, gates phase transitions.
- **Spokes (11):** `brainstorm-pm` (added 2026-05-14, P1.0b — Phase 0 default new-feature entry point; 5 modes since 2026-06-03 — added Three-Option Trade-Off Mode via PR #597), `research`, `ux`, `design`, `dev`, `qa`, `analytics`, `cx`, `marketing`, `release`, `ops` — each owns a phase or cross-cutting responsibility.

Each skill has:
- An **agent-facing prompt** at `.claude/skills/<name>/SKILL.md`. The agent reads this when the skill is loaded.
- A **markdown doc** at `docs/skills/<name>.md` for human reference.
- A **routing config entry** in `.claude/shared/skill-routing.json` declaring which phases load this skill on demand (v5.0 skill-on-demand optimization).

### 4.1 Skill loading model (v5.0+)

Before v5.0, all 11 skills (the v2.0–v7.8.4 baseline) loaded into context on every session. After v5.0:
- The `pm-workflow` hub always loads.
- Spokes load **on demand** based on `phase_skills` in `skill-routing.json`.
- Each spoke has a `compressed_view` field in its cache entry (~200 words) loaded by default; full expansion happens when the agent calls the skill.
- Net savings: ~54K tokens per session vs. v4.x.

### 4.2 Adding a new skill

1. Create `.claude/skills/<name>/SKILL.md` with the agent-facing prompt.
2. Create `docs/skills/<name>.md` for human reference.
3. Add an entry to `.claude/shared/skill-routing.json`:
   ```json
   {
     "phase_skills": {
       "<phase>": ["<existing-skills>", "<name>"]
     },
     "compressed_views": {
       "<name>": "≤200-word summary of what the skill does"
     }
   }
   ```
4. Bump `framework-manifest.json.structure.spoke_skills` (currently 10).

---

## 5. `state.json` — the canonical per-feature contract

Every feature has a `.claude/features/<name>/state.json` file. This file is the **single source of truth** for that feature's lifecycle state. The integrity layer reads it; the dashboard reads it; the case study links to it.

### 5.1 Required top-level fields

| Field | Type | Notes |
|---|---|---|
| `name` | string | Feature slug, must match directory name |
| `work_type` | enum | `"feature"`, `"enhancement"`, `"fix"`, `"chore"`, `"framework"`, `"refactor"` |
| `current_phase` | enum | One of: `research`, `prd`, `tasks`, `ux_or_integration`, `implement`, `test`, `review`, `merge`, `docs`, `complete`. **DO NOT use `phase`** — that key is rejected by `SCHEMA_DRIFT` (canonical is `current_phase`). |
| `created` | ISO 8601 timestamp | Used by `measurement-adoption-report.py` to bucket pre/post-v6.0 features |
| `phases` | object | One key per phase entered, with `started_at` (ISO 8601). Phase `M` adds `ended_at` when leaving for phase `N>M`. |
| `tasks` | array | Task list for Phase 3 (`tasks` phase) onward |
| `complexity` | object | v6.0 protocol: `cu_version`, `factors_applied[]`, `view_count`, etc. (see § 9.1) |
| `timing` | object | v6.0 protocol: `session_start`, `total_wall_time_minutes`, per-phase `started_at`/`ended_at` |
| `cache_hits` | array | v6.0 protocol: each entry is `{timestamp, level, key, type, skill, event_type, phase}` |
| `platforms_tested` | object | **T14 (2026-06-07).** `{ios, web, backend, ai}` booleans recording which platforms a feature's tests exercised. "Non-empty" = ≥1 key `true`. Validated by the advisory `PLATFORMS_TESTED` sub-check at `current_phase=complete`. Framework-meta features (`work_type=chore` / `work_subtype=framework_feature`) are exempt. See §5.4. |
| `platforms_tested_provenance` | string | T14 provenance marker: `authored` \| `backfill-heuristic-<date>` \| `backfill-heuristic-low-confidence` \| `exempt:framework_meta`. |

### 5.2 Phase-specific sub-fields

Each entered phase typically also has:
- `phases.<phase>.completed_at` — when the phase finished (set on transition out)
- `phases.<phase>.gate_passed` — boolean if a hard gate (e.g., review approval) was required
- `phases.merge.pr_number` — set during the merge phase; verified by the `PR_NUMBER_UNRESOLVED` check

### 5.3 Schema enforcement

`scripts/check-state-schema.py` reads each staged `state.json` (or, with `--all`, every state.json in the repo) and emits findings:
- `SCHEMA_DRIFT` — legacy `phase` key present
- `NO_PHASE` — neither `current_phase` nor `phase` present
- `INVALID_JSON` — file does not parse
- `PHASE_TRANSITION_NO_LOG` (v7.6) — phase changed but no log entry within last 15 min
- `PHASE_TRANSITION_NO_TIMING` (v7.6) — phase changed but no `timing.phases.<new>.started_at` and/or old-phase `ended_at` update

The `--staged` flag scopes the check to staged files (used by the pre-commit hook). The `FORCE_TRANSITION_CHECKS=1` env var unscopes for testing.

### 5.4 `platforms_tested` parity (T14, 2026-06-07)

`platforms_tested` records which platforms a feature's tests exercised, so platform-test parity is a queryable property of every completed feature (not just "tests passed somewhere"). Shape: `{"ios": bool, "web": bool, "backend": bool, "ai": bool}` (semantics: `ios`=SwiftUI app, `web`=fitme-story/website/dashboard, `backend`=sync/Supabase/Railway, `ai`=ai-engine cohort).

- **Gate:** the advisory `PLATFORMS_TESTED` sub-check (in `check-state-schema.py`) fires on `current_phase=complete` transitions and reports when no platform key is `true`. It has its own `PLATFORMS_TESTED_ADVISORY_MODE` flag + isolated Mechanism A coverage key, so its advisory→enforced flip (~v7.10, after a 14-day calibration window) is independent of the enforced `FEATURE_CLOSURE_COMPLETENESS` gate it fires alongside.
- **Q2 exemption:** framework-meta features (`work_type=chore` or `work_subtype=framework_feature`, or `platforms_tested_provenance` starting `exempt:`) are skipped — they ship no product-platform code, so an all-`false` record would be meaningless.
- **Backfill:** `scripts/backfill-platforms-tested.py` populated all pre-T14 complete features from offline text signals, tagging each with a `platforms_tested_provenance` marker; low-confidence inferences are flagged for optional operator spot-check (0 mandatory review).
- **Out of scope:** per-platform coverage *percentages* (T15+, depends on R9 Track B coverage data).

---

## 6. Phase lifecycle (9 phases × 4 work types)

The PM framework defines a **9-phase pipeline** for full features. Smaller work types skip subsets of phases.

| Phase | Skill driver | Output | Required for |
|---|---|---|---|
| 1. `research` | `brainstorm-pm` (Phase 0 discovery, runs first) → `research` | `docs/product/research/<name>.md` + `state.json::brainstorm` | Feature |
| 2. `prd` | `pm-workflow` | `docs/product/prd/<name>.md` | Feature, Enhancement |
| 3. `tasks` | `pm-workflow` | `state.json.tasks[]` | Feature, Enhancement |
| 4. `ux_or_integration` | `ux` + `design` | `docs/design-system/<name>-spec.md` | Feature (UI), or skipped + recorded as `work_type:fix` etc. |
| 5. `implement` | `dev` | code | All work types |
| 6. `test` | `qa` | XCTest + CI green | All except `chore` |
| 7. `review` | reviewer + `qa` | Approved PR | Feature, Enhancement |
| 8. `merge` | `release` | Commit on main + `pr_number` set | All |
| 9. `docs` | `pm-workflow` + `cx` | Case study + state.json closed | Feature, Enhancement |

### 6.1 Work types

Defined in `CLAUDE.md` (Work Item Types section):
- **Feature** — full 9-phase. New capabilities. Weight 1.0 in CU formula.
- **Enhancement** — 4-phase (Tasks → Implement → Test → Merge). Improvements to shipped features. Weight 0.8.
- **Fix** — 2-phase (Implement → Test). Bug fixes. Weight 0.5.
- **Chore** — 1-phase (Implement). Docs, config. Weight 0.3.
- **Refactor (v2)** — like Feature but v1 exists as reference. Weight 0.9.
- **Framework** — internal infrastructure (e.g., this dev guide, v7.6 itself). No fixed weight; choose nearest analog.

### 6.2 The "v2/" subdirectory rule

When refactoring a UI screen, the v2 file lives at `<parent>/v2/<ScreenName>.swift`. Same Swift type name; v1 stays in repo as historical artifact (removed from build target via `project.pbxproj`). Full rule: `CLAUDE.md` → "## UI Refactoring & V2 Rule".

---

## 7. Dispatch model — how skills get invoked

The agent (Claude Code, Codex, etc.) interacts with the framework primarily via **slash commands** that invoke skills:

```
/pm-workflow <feature-name>      ← hub: starts/resumes a feature
/brainstorm-pm <feature-name>    ← spoke: Phase 0 problem framing (5 modes — problem/solution/assumption/strategy + three-option trade-off matrix; runs before research)
/dev                              ← spoke: implementation work
/qa                               ← spoke: test work
/design / /ux                     ← spoke: design + UX
/analytics / /cx / /research      ← spoke: cross-cutting
/marketing / /release / /ops      ← spoke: support
```

When the user types a slash command, the runtime looks up the corresponding `SKILL.md` and loads its content into the agent's context. The agent then follows the skill's instructions.

### 7.1 Routing logic (v5.2 Dispatch Intelligence)

`scripts/dispatch-intelligence.py` and `.claude/shared/dispatch-intelligence.json` define a 3-stage dispatch pipeline:
1. **Tool budget check** — does the requested skill fit within the per-session tool budget?
2. **Hardware affinity** (v7.0 HADF) — does the current device profile favor a particular skill variant?
3. **Skill execution** — invoke the skill with appropriate cache pre-load.

For most local Claude Code sessions, the dispatch pipeline is invisible — it just makes routing decisions before the agent picks up the work.

### 7.2 Concurrent dispatch hygiene

Per `CLAUDE.md` "## Concurrent Dispatch Hygiene": parallel subagent dispatch is **currently blocked** at the framework layer (F6–F9 framework bugs). Default to serial. Re-validation gate after upstream patches: `docs/superpowers/plans/f6-f9-reproducer/proof-of-fix-tests.md`.

---

## 8. Cache architecture (L1 per-skill, L2 shared, L3 project)

The framework treats agent reasoning as a cache hierarchy:

| Level | Scope | Location | Lifetime |
|---|---|---|---|
| **L1** | Per-skill | `.claude/cache/<skill>/` | Session-scoped; skill-internal |
| **L2** | Cross-skill (shared) | `.claude/cache/_shared/` | Session-scoped; multiple skills can read |
| **L3** | Project-wide | `.claude/cache/_project/` | Persistent across sessions |

### 8.1 Cache hits — the writer path

When an agent reuses a piece of prior knowledge (a skill output, a doc snippet, a prior plan, a memory entry) instead of re-deriving it, that's a **cache hit**. The agent logs it via:

```bash
python3 scripts/append-feature-log.py \
  --feature <feature-name> \
  --event-type code_change \
  --summary "<what changed>" \
  --artifact "<file>" \
  --cache-hit L2 \
  --cache-key "<a stable key>" \
  --cache-hit-type {adapted,exact,miss} \
  --cache-skill "<source skill or pattern reused>"
```

The script writes the entry to `.claude/logs/<feature>.log.json` AND appends to `state.json.cache_hits[]`. The dual-write is intentional: logs are flat-file event streams, state.json is the canonical roll-up.

### 8.2 What the framework can and cannot mechanize

- **Mechanizable:** the writer path (CLI accepts the flags, schema validates the entry, count rolls up to `measurement-adoption.json`).
- **Not mechanizable:** the *recognition* that something is a cache hit. This is Class B Gap 1. The framework provides the infrastructure; the agent must remember to use it.

---

## 9. Measurement protocol (CU formula, cache_hits, timing)

Shipped at v6.0 (2026-04-16). Hardened across v7.5 → v7.6. Canonical doc: [`docs/case-studies/normalization-framework.md`](../case-studies/normalization-framework.md).

### 9.1 The CU formula (v6.0)

```
CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))
```

**Work-type weights:**
| Type | Weight |
|---|---|
| Feature | 1.0 |
| Enhancement | 0.8 |
| Fix | 0.5 |
| Chore | 0.3 |
| Refactor (v2) | 0.9 |
| Framework | (choose nearest analog; commonly 0.9) |

**Complexity factors (additive):**

| Factor | Value | Source |
|---|---|---|
| Has UI (1 view) | +0.15 | `state.json.complexity.view_count` |
| Has UI (2-3 views) | +0.30 | same |
| Has UI (4+ views) | +0.45 | same |
| Design Iteration (text) | +0.10 per round | `state.json.complexity.design_iteration_details[]` |
| Design Iteration (layout) | +0.15 per round | same |
| Design Iteration (interaction) | +0.20 per round | same |
| Design Iteration (full redesign) | +0.25 per round | same |
| New Model/Service (1-2 types) | +0.1 | `state.json.complexity.new_types_count` |
| New Model/Service (3-5) | +0.2 | same |
| New Model/Service (6+) | +0.3 | same |
| Auth/External (binary) | +0.5 | binary flag |
| Runtime Testing (binary) | +0.4 | binary flag |
| Cross-Feature (binary) | +0.2 | binary flag |
| Architectural Novelty (binary) | +0.2 | `state.json.complexity.is_first_of_kind` |

The agent **declares** factors in `state.json.complexity.factors_applied[]` with a `reason` string per factor. The script does not auto-derive magnitudes — that's Class B Gap 2.

### 9.2 Velocity reporting

After phase completion, `state.json.timing.total_wall_time_minutes` should be set. Velocity = `total_wall_time_minutes / CU`. The v6.0 protocol requires three baseline comparisons:
- vs Historical (Onboarding v2 = 15.2 min/CU)
- vs Rolling (mean of last 5 features)
- vs Same-Type (mean of last 3 same work_type)

`scripts/measurement-adoption-report.py` reports per-feature adoption status across 4 dimensions: `timing_wall_time`, `per_phase_timing`, `cache_hits`, `cu_v2`. A feature is "fully adopted" only when all 4 dimensions are populated.

### 9.3 Tier tags (T1/T2/T3)

Every quantitative claim in a case study, PRD, or meta-analysis should carry a tier tag:
- **T1 (Instrumented)** — pulled from a JSON file or deterministic command output.
- **T2 (Declared)** — declared by the author from a non-instrumented source (e.g., human-counted from `git log`).
- **T3 (Narrative)** — narrative inference; should be avoided in v7.6+ case studies.

Forward-only: case studies dated `>= 2026-04-21` get file-level tag-presence enforcement at write-time (`CASE_STUDY_MISSING_TIER_TAGS`). The preflight checks that at least one T1/T2/T3 tag exists in the scoped file. Tag exhaustiveness and correctness are Class B Gap 3 — code review still checks whether each metric has the right tag.

---

## 10. Integrity layer — write-time + per-PR + cycle-time + weekly

### 10.1 Check codes (write-time + cycle-time, current through v7.10, 2026-06-10)

> The table below enumerates every check code emitted by the enforcement scripts. The v7.8.1 branch-isolation + feature-closure family and the v7.8.3 cross-repo `state_owner` family were promoted/added after the original §10.1 table was written; they are now included. When debugging a gate that fired, **check the [Observed Patterns Catalog](#105-observed-patterns-catalog-v785) (§10.5) first** — most fire-patterns are documented there with a signal-vs-noise rule and a silence path.

| Code | Layer | Script | What it checks |
|---|---|---|---|
| `SCHEMA_DRIFT` | Write + cycle | `check-state-schema.py` | Legacy `phase` key present (canonical is `current_phase`) |
| `NO_PHASE` | Write + cycle | `check-state-schema.py` | Neither `current_phase` nor `phase` present |
| `INVALID_JSON` | Write + cycle | `check-state-schema.py` | File does not parse |
| `PR_NUMBER_UNRESOLVED` | Write + cycle | `check-state-schema.py` + `integrity-check.py` | `phases.merge.pr_number` does not resolve in the cached `gh pr list` result (skipped gracefully when `gh` is unavailable) |
| `PHASE_TRANSITION_NO_LOG` (v7.6) | Write | `check-state-schema.py` | Staged phase change without log entry within 15 min |
| `PHASE_TRANSITION_NO_TIMING` (v7.6) | Write | `check-state-schema.py` | Staged phase change without `timing.phases.<new>.started_at` and old-phase `ended_at` fields |
| `PHASE_LIE` | Cycle | `integrity-check.py` | `current_phase=complete` but state.json contradicts |
| `TASK_LIE` | Cycle | `integrity-check.py` | Tasks marked complete that contradict commits |
| `NO_CS_LINK` | Cycle | `integrity-check.py` | Shipped feature has no case-study link |
| `V2_FILE_MISSING` | Cycle | `integrity-check.py` | v2/ subdirectory missing for refactored screen |
| `PARTIAL_SHIP_TERMINAL` | Cycle | `integrity-check.py` | Marked shipped but only some sub-tasks done |
| `NO_STATE` | Cycle | `integrity-check.py` | Feature in registry has no state.json |
| `BROKEN_PR_CITATION` (v7.6 write-time, v7.5 cycle) | Write + cycle | `check-case-study-preflight.py` (write) + `integrity-check.py` (cycle) | PR # in case study does not resolve |
| `CASE_STUDY_MISSING_TIER_TAGS` (v7.6) | Write + cycle | `check-case-study-preflight.py` (write) + `integrity-check.py` (cycle) | Scoped case study has no T1/T2/T3 tag at all (forward-only ≥ 2026-04-21); presence only, not exhaustiveness |
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (v7.7 as `CACHE_HITS_EMPTY_POST_V6`; **renamed v7.8.3**, enforced) | Write | `check-state-schema.py` | Post-v6 feature reaches `current_phase=complete` with empty `cache_hits[]`. Pairs with `scripts/log-cache-hit.py` wrapper that auto-discovers the active feature and dual-writes state.json + events log. Closes #140 (the v6 writer-path adoption gap). Pre-Mechanism-C features (`created_at < 2026-05-02`) are auto-exempt. |
| `CU_V2_INVALID` (v7.7) | Write + cycle | `check-state-schema.py` + `integrity-check.py` | `cu_v2` schema invalid: missing factor (complexity/blast_radius/novelty/verification_difficulty), out-of-range value, total mismatch with sum(factors), or invalid tier_class. Pre-v6 features without `cu_v2` are exempt. Validates STRUCTURE only — magnitude correctness stays a documented Class B gap. |
| `STATE_NO_CASE_STUDY_LINK` (v7.7) | Write | `check-state-schema.py` | `current_phase=complete` without `case_study` link OR `parent_case_study` link OR `case_study_type` exempt tag (`no_case_study_required` / `pre_pm_workflow_backfill` / `roundup`). Mirrors the cycle-time `NO_CS_LINK` at write-time. |
| `CASE_STUDY_MISSING_FIELDS` (v7.7) | Write | `check-case-study-preflight.py` | Forward-only ≥ 2026-04-28: case study missing one or more of `work_type`, `success_metrics`, `kill_criteria`, `dispatch_pattern` in frontmatter. |
| **`TIER_TAG_LIKELY_INCORRECT` (v7.7 advisory)** | Cycle (advisory) | `validate-tier-tags.py` + `integrity-check.py` | Heuristic regex extracts T1-tagged quantitative claims and cross-references against ledger numbers. **Advisory severity — does not gate.** Kill criterion 2 fired at baseline (FP rate 100% n=1; root cause: regex pattern designed for `**T1**:` prefix style, live corpus uses `\| value \| T1 \|` table-column format). Ships advisory permanent. v7.8 redesign documented in `docs/case-studies/meta-analysis/tier-tag-checker-baseline.md`. |
| `SCHEMA_DRIFT_LEGACY_CREATED` (2026-05-01 honesty-fixes patch, PR #169) | Write | `check-state-schema.py` | Legacy `created` key on state.json (canonical: `created_at`). Closes the silent-pass that left v7.7 `CACHE_HITS_EMPTY_POST_V6` at 0/46 effective coverage when 43/46 features used the legacy field name. |
| `FRAMEWORK_VERSION_FORMAT` (2026-05-01 honesty-fixes patch, PR #169) | Write | `check-state-schema.py` | When `framework_version` is set, must match `(pre-)?v<major>.<minor>`. Presence-required deferred to v7.9 backfill. |
| **`CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (v7.8 advisory, Mechanism C)** | Cycle (advisory) | `integrity-check.py` | Session ledger (`.claude/logs/_session-<id>.events.jsonl`) attributes Read events to a feature, but `state.json::cache_hits[]` is empty/absent. Mechanism C captures session events; state.json::cache_hits requires manual `scripts/log-cache-hit.py` until v7.9 promotes `observe-cache-hit.py` to dual-write. **Advisory only** in v7.8; v7.9 promotes to enforced. |
| **`GATE_COVERAGE_ZERO` (built v7.9.1 #673; extended v7.10 #689, advisory)** | Cycle (advisory) | `integrity-check.py` | Reads the F17 `gate-last-fired.json` index and flags a gate that went silent relative to the active corpus. v7.10 added a **0-candidate mis-wire detector**: a gate in the index with `candidates==checked==skipped==0` has a check site that runs but never reaches a candidate (the `cache_hits`-keying / unreachable-loop class) — distinct from a healthy zero-firing gate (e.g. `STATE_OWNER_MISSING`: many candidates, 0 violations). Coverage lands in `.claude/logs/gate-coverage.jsonl` per Mechanism A. **Remains advisory.** |
| `BRANCH_ISOLATION_VIOLATION` Mode B (v7.8.1 advisory → **enforced v7.9**, 2026-05-21) | Write | `check-state-schema.py` | Infra-path commit (`.githooks/*`, `.github/workflows/*`, `scripts/*`, `.claude/skills/*`, `.claude/shared/*`, `CLAUDE.md`, `docs/architecture/*`, `Makefile`, OR `work_subtype: framework_feature` / `work_type: chore`) on a non-feature branch. Per-feature `isolation_opt_out` does NOT bypass Mode B (Q3 infra override). Auto-isolation dispatches `scripts/create-isolated-worktree.py`. |
| `BRANCH_ISOLATION_VIOLATION` Mode C (v7.8.1 advisory → **enforced v7.9**) | Write | `check-state-schema.py` (`BRANCH_ISOLATION_VIOLATION_MODE_C`) | `state.json::current_phase` mutation from a non-feature branch. Per-feature `isolation_opt_out: true` + reason bypasses Mode C only. |
| `ISOLATION_OPT_OUT_REASON_MISSING` (v7.8.1, **enforced at ship**) | Write | `check-state-schema.py` | `isolation_opt_out: true` with empty/missing `isolation_opt_out_reason`. |
| `FEATURE_CLOSURE_COMPLETENESS` (v7.8.1 advisory → **enforced v7.9**; cycle mirror stays advisory) | Write + cycle | `check-state-schema.py` (write) + `integrity-check.py` (cycle mirror) | `current_phase=complete` transition: validates 7 required case-study frontmatter fields + Q7 (`kill_criteria_resolution` when `kill_criteria` set) + Q6 bidirectional PR-list parity (state.json ↔ case study). Cycle mirror catches `--no-verify` bypasses. Override: `pr_citation_exempt` / `case_study_type` exemption. |
| `STATE_OWNER_MISSING` / `STATE_OWNER_INVALID` / `STATE_OWNER_LOCATION_MISMATCH` (v7.8.3) | Write | `check-state-schema.py` | Cross-repo state ownership: `state_owner` ∈ `{ft2, fitme-story}` required + valid enum + file location must match the value (reverse-sync mirrors with `state_owner_sync_origin` ending `-reverse` exempt from LOCATION_MISMATCH). |
| `BRANCH_ISOLATION_HISTORICAL` (v7.8.1 cycle advisory — **stays advisory by design**) | Cycle (advisory) | `integrity-check.py` | T17 forward-only audit — feature files first appear on `main` with no `feature/*`/`chore/*` branch attribution (squash-merge + branch-cleanup artifact; see Observed Patterns #1). |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` (v7.8.1 cycle advisory — macOS-only, **stays advisory**) | Cycle (advisory) | `integrity-check.py` | T18 — launchd plist anchored to a stale repo path (the 2026-04-30 HADF Phase 2 trigger incident). |
| `PR_CACHE_STALE` (v7.8.4 operability) | Pre-check | `ensure-pr-cache-fresh.py` | `.cache/gh-pr-cache.json` empty/missing/>24h → auto-refresh runs before `make integrity-check` + inside `integrity-cycle.yml`. Refresh failure logs but does NOT abort. Closes the 33-finding empty-cache false-positive incident (2026-05-12; see Observed Patterns #12 + W11). |
| `PLATFORMS_TESTED` (T14, **advisory**; advisory→enforced ~v7.10) | Write | `check-state-schema.py` | `current_phase=complete` transition with no platform set to `true` in `platforms_tested`. Own `PLATFORMS_TESTED_ADVISORY_MODE` flag + isolated coverage key (independent flip from FEATURE_CLOSURE_COMPLETENESS). Q2-exempt: `work_type=chore` / `work_subtype=framework_feature` / `provenance exempt:*`. Also validates field shape any phase. See §5.4. |
| `TRACKING_DRIFT_OPEN_BUT_SHIPPED` (2026-06-07, advisory) | On-demand | `tracking-drift-check.py` (`make tracking-drift-check`) | Planning rows that claim OPEN (`[ ]` / un-struck RICE row) while their feature `state.json` is `complete` or the row's own title carries a ship marker. Advisory only. |
| `PR_NUMBER_UNRESOLVED` window (raised 500 → 2000, 2026-06-07) | Write | `check-state-schema.py` `_load_pr_cache` | `gh pr list --limit 2000` (was 500): a commit touching an OLD complete feature re-validates its merge pr_number, so the window must span full PR history (same W34 truncation class PR #631 closed for the integrity-check reader). |

### 10.2 The 72h cycle

Defined in `.github/workflows/integrity-cycle.yml`. Cron: `0 4 */3 * *` (every 3 days at 04:00 UTC). Steps:
1. Checkout repo with `fetch-depth: 0`.
2. Run `integrity-check.py --snapshot <new> --compare-to <prev> --snapshot-trigger scheduled_cycle`.
3. Commit the new snapshot to `.claude/integrity/snapshots/`.
4. If a regression is detected, open a `regression`-labeled issue.

### 10.3 The per-PR layer

Defined in `.github/workflows/pr-integrity-check.yml` (v7.6 Phase 2a). Steps:
1. Checkout PR HEAD.
2. Run schema check + integrity check + measurement-adoption against PR HEAD.
3. Capture `origin/main` baseline via `git worktree add /tmp/main-tree origin/main`.
4. Compute `delta = pr_findings - main_findings`.
5. Set `pm-framework/pr-integrity` commit status to `failure` if any required command exits non-zero or if `delta > 0`.
6. Sticky comment with marker `<!-- pm-framework-pr-integrity-bot -->` updates in place and reports command exit codes.

### 10.4 The weekly cycle

Defined in `.github/workflows/framework-status-weekly.yml` (v7.6 Phase 2c). Cron: `0 5 * * 1` (Mondays 05:00 UTC, 1h after the 72h cycle to avoid runner queue contention). Steps:
1. Snapshot measurement-adoption history with `--snapshot-trigger weekly_status`.
2. Compare current vs prior history snapshot.
3. Open issue if `fully_adopted` or `any_adopted` decreased.
4. **Observational only** — never blocks merges.

### 10.5 Observed Patterns Catalog (v7.8.5)

When a gate fires, the finding alone does not tell you whether it is a real problem or an expected artifact (a squash-merge leaving no branch attribution, an empty PR cache, a heuristic over-trigger, etc.). The **Observed Patterns Catalog** at [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) is the canonical manifest of every recognized fire-pattern. Each entry carries a **trigger**, a **why-expected** classification (by-design / cleanup-artifact / silent-pass-then-fixed / heuristic-FP / schema-drift), a **distinguishing-real-signal** rule, and a **silence path**.

- **Coverage (current):** 24 gate-firing patterns (Section 1, `#1`–`#24`) + workflow/operational patterns through `W36` (Section 2; `W33` is the pattern↔skill preflight overlay self-doc entry). See `.claude/integrity/observed-patterns.md` for the live ceiling — this number advances every time a novel pattern is appended.
- **CLI:** `make observed-patterns`.
- **Preflight-loaded** by `/pm-workflow` and referenced by all spoke skills.
- **Operator obligation (mandatory):** when any framework gate or advisory fires, the FIRST step is to consult this catalog. Apply the documented remediation if the pattern matches; investigate only if novel; and **append a new entry** to the catalog before the feature that surfaced the novel pattern is closed. The catalog is append-only-by-default.

The catalog is the human-facing companion to the Mechanism A coverage ledger (§2.4): Mechanism A tells you a gate *fired*; the catalog tells you what the firing *means*.

### 10.5a Pattern↔skill preflight overlay (v7.9.1, shipped 2026-06-04)

The Observed Patterns Catalog became **operational** at v7.9.1: each of the 55 work-blocking patterns now carries an explicit `skills[]` mapping in [`.claude/shared/pattern-skill-map.json`](../../.claude/shared/pattern-skill-map.json), and every one of the 12 skill `SKILL.md` files now ships an auto-generated `<!-- BEGIN pattern-preflight (generated) -->` block listing its relevant patterns with detector + remediation + autoheal flags. The wiring is **bidirectional** (catalog ↔ skill), **dual-purpose** (dev-process preempt + 3D Universe overlay input), and **self-auditing** (catalog drift surfaces as a `PATTERN_SKILL_UNMAPPED` advisory in `make integrity-check`).

**Goal:** instead of operators discovering blockers reactively mid-task when a gate fires, each skill **proactively probes its relevant patterns at activation** so blockers clear before work begins.

**Three operator surfaces:**

| Surface | What it does | Producer |
|---|---|---|
| `make skill-preflight SKILL=<name>` | Runs the mechanized probes for `<name>`'s relevant patterns + emits awareness checklists for the manual/discipline ones; writes an additive `skill_overlay.<name>` block to `.claude/shared/preflight-cache.json`. Exit codes: 0 (clean) / 1 (blocker probed) / 2 (usage error). | [`scripts/skill-preflight.py`](../../scripts/skill-preflight.py) |
| `make gen-skill-preflight` | Idempotently regenerates the `<!-- BEGIN/END pattern-preflight (generated) -->` block inside each `SKILL.md` from the map. Re-run produces no diff. | [`scripts/generate-skill-preflight-sections.py`](../../scripts/generate-skill-preflight-sections.py) |
| `PATTERN_SKILL_UNMAPPED` advisory | Cycle-time check: every pattern ID in `observed-patterns.md` (except `W33` self-doc) must be present in `pattern-skill-map.json` with ≥1 skill. Catches the case where a new W-pattern is appended to the catalog without a corresponding map entry. | [`scripts/integrity-check.py::check_pattern_skill_unmapped`](../../scripts/integrity-check.py) |

**HYBRID detection model:**

| Kind | Count | Treatment |
|---|---|---|
| **Mechanized** — a script detects it live | ~23 | `make skill-preflight` runs the detector (e.g. `check-ssh-agent.sh` for W1, `check-branch-drift.py` for W9, `ensure-pr-cache-fresh.py` for #12 + W11) |
| **Manual / compile-time / discipline** | ~32 | Emitted as an awareness checklist — the operator reads it but no script can probe (e.g. W2 publish-verbatim, W6 measurement impartiality, W24 pbxproj merge conflicts) |
| **Self-doc** | 1 (W33) | Documents the overlay tool itself; exempt from `PATTERN_SKILL_UNMAPPED` via `SELF_DOC_EXEMPT` |

**Per-skill `SKILL.md` integration:** every spoke + the hub now contains a section like:

```markdown
<!-- BEGIN pattern-preflight (generated) -->
## Patterns relevant to /<skill>

| ID | Title | Detector | Blocker | Skills |
|---|---|---|---|---|
| #6 | FEATURE_CLOSURE_COMPLETENESS | scripts/check-state-schema.py | ✗ | pm-workflow, cx, ux |
| W1 | SSH signing requires loaded agent | scripts/check-ssh-agent.sh | ✓ | pm-workflow, dev, ops |
| ...
<!-- END pattern-preflight (generated) -->
```

The block is **regenerated** from `pattern-skill-map.json` by `make gen-skill-preflight`. Operators do not hand-edit it.

**Mandatory operator discipline when adding a NEW catalog pattern:**

1. Append the entry to `.claude/integrity/observed-patterns.md` (existing v7.8.5 rule).
2. Add it to `.claude/shared/pattern-skill-map.json` with `≥1` `skills[]` entry.
3. Run `make gen-skill-preflight` to refresh the 12 `SKILL.md` blocks.
4. Confirm `make integrity-check` shows no new `PATTERN_SKILL_UNMAPPED` advisory.

The `PATTERN_SKILL_UNMAPPED` advisory is the safety net for step 2 — it surfaces a catalog ID that has no corresponding map entry.

**Full reference:** [`docs/skills/pattern-skill-overlay.md`](../skills/pattern-skill-overlay.md) (137-LOC schema + how-to). **Self-doc:** [`observed-patterns.md` W33](../../.claude/integrity/observed-patterns.md#w33--pattern-skill-preflight-overlay-catalog-patterns-mapped-per-skill--probed-at-activation-2026-06-04). **PR provenance:** [#615](https://github.com/Regevba/FitTracker2/pull/615) (originally opened 10:29 UTC by a scheduled remote agent; rebased + extended with W29-W32 mapping + W33 self-doc renumber + 3D PRD CHANGELOG block; merged 19:01 UTC via admin override after W31 stuck-queue blocked the standard merge path).

### 10.6 Real-time + daily observability surfaces (v7.8.5 → v7.8.6)

Beyond the four scheduled enforcement layers, the framework runs several lightweight read/warn surfaces:

| Surface | Cadence | What it does | Producer |
|---|---|---|---|
| **W9 branch-drift alert** | `PostToolUse:Bash` hook (every Bash call) | Warns when the git branch changed unexpectedly between tool calls (concurrent-session `git checkout` collision). Disable: `CLAUDE_W9_DISABLE_DRIFT_CHECK=1` | [`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py) |
| **W1 ssh-agent preflight** | `SessionStart` hook | Loud stderr warning when `ssh-add -l` shows no identities (prevents the silent sign-hang). Disable: `CLAUDE_W1_DISABLE_SSH_CHECK=1` | [`scripts/check-ssh-agent.sh`](../../scripts/check-ssh-agent.sh) |
| **Mechanism C cache-hit capture** | `PostToolUse:Read` hook | Auto-captures Read events into the session ledger (existence-guarded so it no-ops in cross-repo cwd, per v7.8.2) | [`scripts/observe-cache-hit.py`](../../scripts/observe-cache-hit.py) |
| **Membrane status (Mechanism F)** | `make membrane-status` + SessionStart | Active feature + recent gate firings + dispatch-blocker state in one readout | [`scripts/membrane-status.py`](../../scripts/membrane-status.py) |
| **Daily integrity checkpoint** | launchd cron (daily) | Appends an integrity snapshot to the checkpoint ledger + surfaces stale `[gone]` branches (W10), orphan worktrees, idle-PR babysit. SessionStart surfaces the regression flag | [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py) → `make daily-checkpoint` |
| **Preflight aggregator** | `make preflight WORK_TYPE=… [FEATURE=…]` | Mandatory Phase 0.0 step: aggregates W1 ssh-agent, PR-cache freshness, branch isolation, integrity findings, drift-vs-anchor, doc-debt, adoption baseline + auto-chains `make freshness-check` (W20) into `.claude/shared/preflight-cache.json` | [`scripts/preflight.py`](../../scripts/preflight.py) + [`scripts/cross-layer-freshness.py`](../../scripts/cross-layer-freshness.py) |
| **Integrity diff vs anchor** | `make integrity-diff` | Compares current platform state vs the 2026-05-14 pre-v7.9 baseline anchor; `EXIT_ON_REGRESSION=1` for CI | [`scripts/integrity-diff.py`](../../scripts/integrity-diff.py) |

---

## 11. Pre-commit hooks and GitHub Actions

### 11.1 Installing the pre-commit hook

```bash
make install-hooks   # symlinks .githooks/pre-commit to .git/hooks/pre-commit
```

### 11.2 What the hook runs

```bash
python3 scripts/check-state-schema.py --staged || exit 1
python3 scripts/check-case-study-preflight.py --staged || exit 1
```

Both scripts exit non-zero on findings. Emergency bypass: `git commit --no-verify`. The cycle layer still catches the issue 0–72h later, so bypass is not silent.

### 11.3 GitHub Actions inventory

> **Count:** 8 baseline through v7.8.6 → **14 baseline at v7.9.1** (+6 shipped 2026-06-04). All v7.9.1 additions are warn-only (`continue-on-error: true`) per Phase E exit discipline.

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | push, PR | Xcode build + XCTest + tokens-check + ui-audit |
| `ci-docs-skip.yml` | PR (docs-only paths) | Skips the iOS build for docs-only PRs (10-15min → instant) |
| `integrity-cycle.yml` | cron `0 4 */3 * *` + workflow_dispatch | 72h state.json + case-study audit; snapshots ledger; regression issue |
| `pr-integrity-check.yml` | pull_request (opened, sync, reopen) | Per-PR delta vs main; sets `pm-framework/pr-integrity` status |
| `framework-status-weekly.yml` | cron `0 5 * * 1` (Mon 05:00Z) + workflow_dispatch | Weekly measurement-adoption + documentation-debt snapshot + Mechanism A gate-coverage zero-drift scan (v7.8.6) + per-dimension adoption trend nudge; regression issue |
| `dependency-audit-weekly.yml` (v7.8.6) | cron `0 6 * * 1` (Mon 06:00Z) | `npm audit --omit=dev` across root + website + dashboard + Swift pin count; issue on HIGH/CRITICAL |
| `audit-prompts-weekly.yml` | cron `0 6 * * 1` (Mon 06:00Z) | Rebuilds the external-audit prompt substrate bundle |
| `audit-bundle-on-tag.yml` | tag push | Builds a deterministic audit bundle on release tags |
| `ucc-audit-log-sync.yml` | cron `17 5 * * *` (daily) | Syncs the UCC passkey-auth audit log (Redis → ledger) |
| `weekly-backup.yml` | cron `0 2 * * 0` (Sun 02:00Z) | Weekly off-repo backup snapshot |
| `figma-code-connect-publish.yml` | push to main (`*.figma.{swift,tsx}` / config) | Publishes Code Connect mappings (see §16) |
| `lint.yml` (v7.9.1, PR #619) | PR + push to main + workflow_dispatch | R7 SwiftLint (macos-15) + R8 ruff (ubuntu) + R12 markdownlint (ubuntu) — 3 independent jobs, all `continue-on-error: true` |
| `coverage.yml` (v7.9.1, PR #626) | PR (path-filtered to FT2 iOS / ai-engine / Makefile / .slather.yml) + push to main + workflow_dispatch | R9 Track B — iOS Slather (macos-15) + Python pytest-cov (ubuntu) — both `continue-on-error: true`; `coverage.xml` uploaded as 14-day-retention artifact for v8.0 `GATE_TEST_MISSING` calibration |
| `gitleaks.yml` (v7.9.1, PR #627) | PR + push to main + cron `0 3 * * 0` (Sun 03:00Z) + workflow_dispatch | R11 — `gitleaks/gitleaks-action@v2` with `.gitleaks.toml` allowlist; full-history fetch; `continue-on-error: true` |
| `pip-audit.yml` (v7.9.1, PR #627) | PR (path-filtered `ai-engine/**`) + cron `0 7 * * 1` (Mon 07:00Z) + workflow_dispatch | R13 — `pip-audit` against ai-engine; columns + JSON output; 14-day artifact retention; `continue-on-error: true` |
| `sbom.yml` (v7.9.1, PR #627) | `push.tags: v*` + workflow_dispatch | R14 — `anchore/sbom-action@v0` generates both SPDX-JSON and CycloneDX-JSON on release tags; dormant until first `v*` tag |
| `commitlint.yml` (v7.9.1, PR #627) | PR | R17 — `@commitlint/cli` + `@commitlint/config-conventional` lints every commit in PR range; relaxed header (150) + body line length (200); `continue-on-error: true` |
| `shellcheck.yml` (v7.9.1, PR #627) | PR (path-filtered `scripts/**` + `.githooks/**`) + push to main + workflow_dispatch | R18 — `ludeeus/action-shellcheck@master` with severity=warning; `continue-on-error: true` |

**Local (launchd) cron — not a GitHub Action:**

| Job | Cadence | Purpose |
|---|---|---|
| `com.fittracker.daily-integrity-checkpoint.plist` | daily | Runs `scripts/daily-integrity-checkpoint.py` (§10.6) — daily integrity snapshot + stale-branch / orphan-worktree / idle-PR surfaces. Install via `make install-daily-cron`. macOS-specific; see `feedback_hadf_launchd_setup_checklist.md` for the exit-78 gotchas. |

### 11.4 Security note for workflow files

All dynamic values used inside `run:` blocks **MUST** be routed through the `env:` block, never via `${{ }}` interpolation directly into shell. This prevents the GitHub Actions injection vector (see [github.blog reference](https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/)). The pre-commit hook for workflow files (`security_reminder_hook.py`) blocks writes that violate this. Both v7.6 workflows (`pr-integrity-check.yml`, `framework-status-weekly.yml`) follow this pattern.

---

## 12. Compressed evolution timeline (v1.0 → v7.10)

Full per-version detail: [`docs/skills/evolution.md`](../skills/evolution.md). This section is the compressed dev-only summary — what each version changed structurally.

| Version | Date | Structural change | Why it matters to a dev today |
|---|---|---|---|
| v1.0 | 2026-03-16 | Single-track serial pipeline (Research → ... → Docs). All work types ran the full 9 phases. | The legacy structure; replaced in v2.0. Files predating v2.0 may show signs of "every change passed through PRD." |
| v2.0 | 2026-03-25 | Work-type tiering (Feature / Enhancement / Fix / Chore). Reduced phase counts per type. | Why a `fix` PR doesn't have a PRD — it's not laziness, it's the work-type contract. |
| v3.0 | 2026-04-09 | External integrations (GA4, Sentry, App Store Connect, Firecrawl, Axe), screen audits, multi-screen v2. | The `.claude/integrations/` directory dates from here. |
| v4.0 | 2026-04-10 | Reactive data mesh + learning cache. L1/L2/L3 cache levels introduced. | The `_shared/` and `_project/` cache directories. |
| v4.1 | 2026-04-10 | Skill internal lifecycle (each skill has `init`, `do`, `report`, `learn` stages internally). | Why every SKILL.md has the same outline. |
| v4.2 | 2026-04-10 | Self-healing hub with integrity verification. First seed cache (5 L1 + 5 L2/L3). | The cache verification logic in `scripts/cache-integrity.py`. |
| v4.3 | 2026-04-11 | Operations Control Room + case-study monitoring. `case-study-monitoring.json`. | The dashboard route on fitme-story (`/`) is built on this data. |
| v4.4 | 2026-04-13 | Eval-driven development. Skill `learn` stage now runs evals against historical sessions. | `.claude/cache/_shared/skill-evals/` directory. |
| v5.0 | 2026-04-14 | SoC-on-software part 1: skill-on-demand loading + cache compression. **54K tokens saved per session**. | Why only `pm-workflow` is in context until you call a spoke. |
| v5.1 | 2026-04-14 | SoC-on-software part 2: 8 SoC items (batch dispatch, result forwarding, model tiering, speculative preload, systolic chains, complexity gate, etc.). | The performance gains came from these — see `docs/skills/architecture.md` §3 for inspiration analogs (Apple ANE, TPU, ARM big.LITTLE). |
| v5.2 | 2026-04-16 | Dispatch Intelligence (3-stage dispatch pipeline) + Parallel Write Safety (3-tier mirror extraction). | The `.claude/shared/dispatch-intelligence.json` config + the parallel-write guards in spoke skills. |
| v6.0 | 2026-04-16 | Framework Measurement Protocol. CU formula v2 (continuous factors), L1/L2/L3 cache hit tracking, eval coverage gates, monitoring auto-sync, 79K tokens measured, rolling baselines, serial/parallel velocity decomposition. | This is when `state.json.timing` and `state.json.cache_hits` schemas became canonical. **Most of v7.5/v7.6's "retroactive backfill" was about catching pre-v6.0 features up to this schema.** |
| v7.0 | 2026-04-16 | HADF (Hardware-Aware Dispatch). 5-layer architecture, 17 chip profiles, 7 cloud signatures, hardware_context block in dispatch-intelligence.json, zero-regression gate (0.4/0.7), composite optimizer. | If you see `hardware_context` in dispatch logs, this is why. Layer 4 (chip-affinity-map) is empty by design — it activates when a workload meets thresholds. |
| v7.1 | 2026-04-21 | 72h Integrity Cycle. First framework capability whose trigger is wall-clock elapsed (cron). 7 failure-mode detectors. | The `integrity-cycle.yml` workflow + `.claude/integrity/snapshots/` ledger. |
| v7.5 | 2026-04-24 | Data Integrity Framework (8 cooperating defenses). Pre-commit schema gates, PR-resolution check, runtime smoke gates, contemporaneous logging, T1/T2/T3 data quality tiers, documentation-debt + measurement-adoption ledgers, 3 new Auditor Agent check codes. Triggered by Gemini 2.5 Pro audit. | 7 of Gemini's 9 Tier 1/2/3 items shipped fully or effectively, 2 partial/pilot, 1 deferred to v7.6. The pre-commit hook and the `make` targets (`integrity-check`, `measurement-adoption`, `documentation-debt`, `runtime-smoke`) date from here. |
| v7.6 | 2026-04-25 | Mechanical Enforcement. 4 new write-time check codes (`PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `BROKEN_PR_CITATION` write-time, `CASE_STUDY_MISSING_TIER_TAGS`). Per-PR review bot with `pm-framework/pr-integrity` status check. Weekly framework-status cron. Append-only adoption history. 5 explicit Class B gaps documented in `unclosable-gaps.md`. | The point where mechanical enforcement reached steady-state. The Class B inventory crystallized here. |
| v7.7 | 2026-04-27 | Validity Closure. 5 new check codes (4 gating + 1 advisory): `CACHE_HITS_EMPTY_POST_V6` (write — closes #140 writer-path), `CU_V2_INVALID` (write+cycle — schema validator), `STATE_NO_CASE_STUDY_LINK` (write — mirrors cycle-time `NO_CS_LINK`), `CASE_STUDY_MISSING_FIELDS` (write — forward-only ≥ 2026-04-28), `TIER_TAG_LIKELY_INCORRECT` (cycle advisory permanent — kill-2 fired at baseline). Cycle-time codes 12 → 13. Linkage 95.5% → 100% (gated). Doc-debt fields 4–61% → 95.7–100% (gated forward). Framework-health dashboard live at fitme-story `/control-room/framework`. Reduces unclosable Class B gaps from 5 to 4. | The first version to gate the full closure-time chain (linkage + case-study fields + cu_v2 schema). The 2026-05-01 honesty-fixes patch (PR #169) revealed v7.7's `CACHE_HITS_EMPTY_POST_V6` had 0/46 effective coverage because the gate read `created_at` while 43/46 features used legacy `created` — surfaced the silent-pass class of failure that v7.8 set out to close. |
| v7.8 | 2026-05-04 | Bridge to v7.9 — silent-pass prevention + inter-agent awareness. Six cooperating mechanisms (A–F): coverage-asserting gates (Mech A → `gate-coverage.jsonl`), schema field-rename detection + dual-read (Mech B → `migrate-state-v7-8-bridge.py`), PostToolUse:Read attribution (Mech C → `_session-<id>.events.jsonl` + `.claude/active-feature` lockfile; closes Gap 1 in advisory), pre-commit hook header self-audit (Mech D → `pre-commit-self-test.py`), custom git merge driver for append-only ledgers (Mech E → `merge-driver-dedup.py`), membrane status advisory (Mech F → `membrane-status.py`). 2 new write-time gates (`SCHEMA_DRIFT_LEGACY_CREATED`, `FRAMEWORK_VERSION_FORMAT`). 2 new cycle-time advisories (`CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`, `GATE_COVERAGE_ZERO`). Schema bridges (`agent_manifest`, `_meta.deprecation_warnings`, `path-reducers.json`, `agent-leases.json`) ship populated but un-validated. Shipped via 9 PRs: #173 + #185–#189 + #193–#195. | **The current state.** Writing code today: expect the same v7.7 write-time gates to fire on every commit, plus 2 new gates (`SCHEMA_DRIFT_LEGACY_CREATED`, `FRAMEWORK_VERSION_FORMAT`). On every Read tool call, `PostToolUse:Read` hook captures the event into the session ledger via `scripts/observe-cache-hit.py` (Mechanism C). On every commit, every write-time gate emits coverage telemetry into `.claude/logs/gate-coverage.jsonl` (Mechanism A). v7.9 measurement window opens 2026-05-11; promotes the proven mechanisms to enforced once 7+ days of session-ledger data calibrate the threshold. The full event-and-trigger catalog: [`docs/architecture/feature-lifecycle-event-catalog.md`](./feature-lifecycle-event-catalog.md). |
| v7.8.1 | 2026-05-07 | Branch Isolation + Feature-Closure Completeness. 3 new write-time gates — `BRANCH_ISOLATION_VIOLATION` (Mode B infra / Mode C per-state.json), `FEATURE_CLOSURE_COMPLETENESS` (7 frontmatter fields + Q6 PR-parity + Q7 kill-resolution), `ISOLATION_OPT_OUT_REASON_MISSING` (enforced at ship) — plus 3 cycle-time advisories (`BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT`, `FEATURE_CLOSURE_COMPLETENESS` mirror). All advisory pending the 14-day Mechanism A window. Companions: `create-isolated-worktree.py`, `make verify-isolation`, `make feature-completeness-audit`. Shipped via PR #244 + #245. | The gates you'll most often see fire on infra/chore commits. If you commit to `scripts/*` or `.claude/shared/*` off a non-feature branch, Mode B fires — isolate first. |
| v7.8.2 | 2026-05-08 | Cross-Repo Telemetry Asymmetry — documented disposition (no new gates). Hook fix: `PostToolUse:Read` command gets a Bash existence guard so it no-ops in fitme-story cwd. Closes v7.9 candidates F7 + F8 by documented exemption (annual re-eval). Shipped via PR #258. | Why the Mechanism C hook silently no-ops when cwd is the website repo — by design, not a bug. |
| v7.8.3 | 2026-05-11 | Cross-Repo State Sync. Top-level `state_owner` enum (`{ft2, fitme-story}`) on every state.json + 3 gates (`STATE_OWNER_MISSING/INVALID/LOCATION_MISMATCH`). Promotes V2 (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`, renamed from `CACHE_HITS_EMPTY_POST_V6`) + V9 (merge driver extends to `<feature>.log.json`) to enforced. New `make snapshot-phase` + `scripts/snapshot-phase-completion.sh` for per-phase off-SSD backups. Unified cross-repo PR-cite cache (`refresh-pr-cache.py`). Shipped via PR #298/#299 (+ fitme-story #86). | `state_owner` is now a required field — `/pm-workflow` writes it; the gate blocks if absent/mismatched. |
| v7.8.4 | 2026-05-12 | Pre-v7.9 telemetry calibration + doc-debt cleanup. One operability gate: `PR_CACHE_STALE` auto-refresh (`ensure-pr-cache-fresh.py`) closing the 33-finding empty-cache false-positive. `TIER_TAG_LIKELY_INCORRECT` heuristic narrowed (3 fixes). New `case-study-t1-references.json` ledger. Baseline driven to 0 findings + 0 advisory. Shipped on `chore/framework-v7-8-4-calibration-patch`. | Why a stale/empty PR cache no longer produces a wall of phantom `BROKEN_PR_CITATION` findings. |
| v7.8.5 | 2026-05-13 | Observability layer (docs + a hook, no new gates). **Observed Patterns Catalog** ([`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md), `make observed-patterns`) — canonical manifest of gate-firing patterns; check it FIRST when a gate fires. **W9 branch-drift real-time alert** (`PostToolUse:Bash` → `check-branch-drift.py`). Shipped via PR #327/#328 + #341. | The catalog is the doc you consult when a gate fires; W9 warns you if a concurrent session flipped your branch (§10.5 + §10.6). |
| v7.8.6 | 2026-05-15 | Cadence batch — read/diff/warn surfaces closing the 96h drift window. `make integrity-diff` (vs 2026-05-14 anchor), unified `make preflight` (mandatory Phase 0.0 aggregator → `preflight-cache.json`), weekly gate-coverage zero-drift scan + per-dimension adoption trend nudge (extends `framework-status-weekly.yml`), W1 ssh-agent SessionStart preflight, `dependency-audit-weekly.yml`, daily stale-branch / orphan-worktree / idle-PR surfaces. Shipped via PR #363 + #365. | `make preflight WORK_TYPE=<type>` is the one command to run before any new work — it aggregates every pre-work check (§10.6). |
| v7.9 | 2026-05-21 | Promotion release. Single-flag flip at [`scripts/check-state-schema.py:138`](../../scripts/check-state-schema.py) (`BRANCH_ISOLATION_ADVISORY_MODE = True → False`) promotes the 3 v7.8.1 advisory gates (Mode B, Mode C, `FEATURE_CLOSURE_COMPLETENESS` write-time) to enforced after their 14-day telemetry window (0 false positives across 18 + 13 + 13 firings). No new gate code. Phase E validation soak 2026-05-21 → 2026-06-04. Shipped via PR #417. | **The current enforced state.** Those 3 gates now block commits. The 3 cycle-time advisories stay advisory by design. Reversibility: single-line revert, < 5 min (§2.0). |
| v7.9.1 | 2026-06-04 | **F16 try-repo pre-commit harness** — adds the 3rd test layer for gates (unit → dispatch → try-repo). Spawns throwaway `pytest tmp_path` git repos, stages canonical positive/negative fixtures under `tests/fixtures/<GATE_ID>/{positive,negative}/`, runs the real `.githooks/pre-commit` via subprocess, asserts exit code + stderr match fixture intent. Coverage: 15/16 write-time gates end-to-end (1 documented skip — `STATE_OWNER_LOCATION_MISMATCH` skips with `path_neutral` when the throwaway repo is not under `/FitTracker2[-/]` or `/fitme-story/`; deferred to F16.1). Empirical wall-clock: ~15s for 59 tests + 1 skip (PRD budget <60s). **F16 caught two real bugs in the framework's own infrastructure during T4 development** — `GATE_COVERAGE_LEDGER` was a module-level constant not env-var (Q5), and `REPO_ROOT` was hardcoded to where the .py file lived (Q6, fixed via `REPO_ROOT_OVERRIDE` env-var support — PR #611). T7 deliberate-regression test PROVES F16 catches what F14 architecturally cannot. **F17 per-gate `last_fired_at` index** (RICE 66.7 — highest of all v7.9.1 items) — `scripts/refresh-gate-last-fired.py` derives `.claude/shared/gate-last-fired.json` from `gate-coverage.jsonl` at wall-clock <1s for ~2k rows. Wired into `make integrity-check` + daily checkpoint + weekly cron. AWS Config Rules `LastSuccessfulInvocationTime` pattern; enables planned v7.10 `GATE_COVERAGE_ZERO` meta-check at O(1) instead of O(records × gates). **B_medium tier formalized** in [CLAUDE.md "Work Item Types"](../../CLAUDE.md) (closes F6 doc gap). **T14 platform-parity** SHIPPED 2026-06-07 at [`.claude/features/t14-platform-parity-state-field/`](../../.claude/features/t14-platform-parity-state-field/) — `platforms_tested {ios, web, backend, ai}` boolean field + advisory `PLATFORMS_TESTED` sub-check (own flag + isolated coverage key) + single-pass backfill of all 94 complete features (25 exempt / 61 inferred / 8 low-confidence flagged, 0 mandatory review); advisory→enforced flip queued for ~v7.10 after its 14-day calibration window (B15, 2026-06-21). See §5.4. Stub opened via PR #606 (F6 + T14 stub) + #607 (F16 scoping) + #608 (T2+T3) + #610 (T4a + Q6) + #611 (REPO_ROOT_OVERRIDE fix) + #612 (T4 complete + T6 CI + T7 regression + T8-T10 docs). | F16 is the discipline you adopt for any new gate going forward: add a fixture pair under `tests/fixtures/<GATE_ID>/{positive,negative}/state.overrides.json` + a parametrized test in the appropriate bucket file. See [`CLAUDE.md` "v7.9.1 F16 — Try-repo Pre-commit Harness"](../../CLAUDE.md) for the full discipline. |
| v7.10 | 2026-06-10 | **GATE_COVERAGE_ZERO observability + field-rename closure.** (a) `GATE_COVERAGE_ZERO` (shipped #673) extended (#689) with a **0-candidate mis-wire detector** — a gate in the index with `candidates==checked==skipped==0` runs but never reaches a candidate (the `cache_hits`-keying / unreachable-loop class); distinct from a healthy zero-firing gate (`STATE_OWNER_MISSING`: 1936 candidates, 0 violations). (b) **Cycle-time Mechanism A coverage** for `BROKEN_PR_CITATION` / `CASE_STUDY_MISSING_TIER_TAGS` / `PATTERN_SKILL_UNMAPPED` — ran without emitting coverage, so the F17 index was blind; now emit `mode="cycle"`. (c) Observed-patterns **pattern #24** — field-rename silent-pass in a READER/INDEX (`cu_v2` top-level-vs-`complexity.cu_version` undercount fixed #687, post-v6 fully-adopted 3→6; `w9.auto_isolate` `ts`-vs-`timestamp` drop fixed #688 — the #7/#9 class in the measurement layer). (d) **verify-local ergonomics** (#690) — `tokens-check`/`verify-web`/`verify-ai` skip cleanly when deps absent (CI still enforces). **T10 AI golden-set evals** (#691) — deterministic `InsightService` golden set; ai-engine suite 60 pass / 1 skip. | The lesson: when you rename or fork a field, grep EVERY reader (`grep -rn '.get("<oldname>"' scripts/`) in the same change. The meta-layer is now self-observing for cycle-time checks too. |

### 12.1 Version-bump policy

A major-version bump (e.g., v7.6 → v7.7) requires:
1. **A new structural capability** — not just code changes within an existing capability.
2. **A propagated update across surfaces** — manifest, CLAUDE.md, evolution doc, case study, and trust-page integration where relevant.
3. **A measurement that the change is real** — pipeline test, integrity check, or instrumented data.

Minor bumps (e.g., v7.5 hardening commits) extend an existing capability without introducing a new layer.

---

## 13. Operational walkthrough — adding a new feature

You are adding a new feature called `widget-customization`. Here's the full sequence.

### 13.0 Preflight (Phase 0.0, mandatory since v7.8.6)

Before any work, run the unified preflight aggregator:

```bash
make preflight WORK_TYPE=feature FEATURE=widget-customization
```

This runs every pre-work check (W1 ssh-agent, PR-cache freshness, branch isolation, integrity findings, drift-vs-anchor, doc-debt, adoption baseline) and auto-chains `make freshness-check` (W20 — confirms your mental model isn't stale vs `origin/main`). Results land in `.claude/shared/preflight-cache.json`, which every spoke skill reads. If preflight surfaces a blocker (e.g., you're on `main` and about to touch infra paths → branch-isolation), resolve it before starting.

### 13.1 Bootstrap

```bash
/pm-workflow widget-customization
```

The hub creates `.claude/features/widget-customization/state.json` with:
```json
{
  "name": "widget-customization",
  "work_type": "feature",
  "current_phase": "research",
  "created": "<now ISO>",
  "phases": {"research": {"started_at": "<now>"}},
  "tasks": [],
  "complexity": {"cu_version": 2, "view_count": 0, "factors_applied": []},
  "timing": {"session_start": "<now>", "phases": {"research": {"started_at": "<now>"}}},
  "cache_hits": []
}
```

It also creates `.claude/logs/widget-customization.log.json` with a `phase_started` event.

**`tasks[].experiment_outcome` (F10, v8.x — optional, advisory).** Each task in
`tasks[]` may carry an `experiment_outcome` enum recording the *disposition* of a
task whose work has concluded: `"shipped"` / `"deferred"` / `"cancelled"` /
`"superseded"`. This is orthogonal to `tasks[].status` (`pending`/`in_progress`/
`complete`) — `status` tracks execution state; `experiment_outcome` records *why*
a non-shipped task ended (a deferred task and a cancelled one are both "not
complete" but mean different things). Previously this distinction lived only in
case-study prose. The field is **optional and advisory** — no blocking gate
validates it (it is a vocabulary formalization, not a new enforcement layer).

### 13.2 Phase progression

For each phase transition (e.g., `research → prd`):
1. Run the phase-specific work (research → write `docs/product/research/widget-customization.md`).
2. Update state.json: set `phases.research.completed_at`, set `current_phase = "prd"`, add `phases.prd.started_at`.
3. Append a `phase_transition` log event via `append-feature-log.py`.
4. Commit. The pre-commit hook will:
   - Verify `current_phase` (not `phase`) — `SCHEMA_DRIFT`.
   - Verify the log entry exists within 15 min — `PHASE_TRANSITION_NO_LOG`.
   - Verify `phases.prd.started_at` is set — `PHASE_TRANSITION_NO_TIMING`.

### 13.3 During implementation

Log cache hits as you go:
```bash
python3 scripts/append-feature-log.py \
  --feature widget-customization \
  --event-type code_change \
  --summary "<what>" \
  --artifact "<file>" \
  --cache-hit L2 \
  --cache-key "<stable key>" \
  --cache-hit-type adapted \
  --cache-skill "<source>"
```

Update `state.json.complexity.factors_applied[]` as factors become known (e.g., when you add a new view, set `view_count`; if you discover a new model is needed, set `new_types_count`).

### 13.4 Merge phase

1. PR opens. The per-PR bot fires automatically.
2. If the bot fails the `pm-framework/pr-integrity` status check, fix the new findings before requesting review.
3. After merge, set `state.json.phases.merge.pr_number` to the merged PR number. The pre-commit verifies it against a cached `gh pr list` result when `gh` is available (`PR_NUMBER_UNRESOLVED`).

### 13.5 Docs phase + close

1. Write `docs/case-studies/widget-customization-case-study.md`.
2. The pre-commit will scan it for:
   - PR citations (`PR #N` or `pull/N`) — `BROKEN_PR_CITATION`.
   - Missing file-level T1/T2/T3 tag in scoped post-2026-04-21 case studies — `CASE_STUDY_MISSING_TIER_TAGS`.
3. Set `current_phase = "complete"`. Set `phases.docs.completed_at`. Set `timing.total_wall_time_minutes` (sum of per-phase elapsed).
4. Add the case study to `feature-registry.json` and to fitme-story `content/04-case-studies/<NN>-<slug>.mdx` if it's showcase-worthy.

---

## 14. Operational walkthrough — extending an integrity check code

You want to add a new check code, e.g., `MISSING_METRIC_BASELINE` (a feature in `complete` phase whose PRD has no baseline number set). Here's the sequence.

### 14.1 Decide the layer

- Should it block at write-time? (Cheap and immediate; agent corrects mid-session.)
- Should it run only on the cycle? (More expensive to surface, but catches cross-session drift.)
- Should it run per-PR? (Catches before merge; status-check enforced.)

**Most checks should be cycle-time first; promote to write-time once the false-positive rate is < 1%.**

### 14.2 Add the cycle-time check

1. Open `scripts/integrity-check.py`.
2. Add a new function:
   ```python
   def check_missing_metric_baseline(state: dict, name: str) -> list[Finding]:
       if state.get("current_phase") != "complete":
           return []
       prd_path = REPO_ROOT / "docs" / "product" / "prd" / f"{name}.md"
       if not prd_path.exists():
           return []
       prd = prd_path.read_text()
       if not re.search(r"baseline:\s*\d", prd, re.IGNORECASE):
           return [Finding("MISSING_METRIC_BASELINE", name, f"PRD has no baseline number")]
       return []
   ```
3. Call it from the main loop alongside other check fns.
4. Add a row to the check-code table in CLAUDE.md "Data Integrity Framework" section.

### 14.3 Add a synthetic-violation test

Open `scripts/test-v7-5-pipeline.sh`. Add a new assertion:
```bash
# Test N: MISSING_METRIC_BASELINE fires on PRD without baseline
echo "test N: MISSING_METRIC_BASELINE fires"
mkdir -p docs/product/prd
echo "# fake PRD without baseline" > docs/product/prd/widget-customization.md
out=$(python3 scripts/integrity-check.py --findings-only)
if echo "$out" | grep -q "MISSING_METRIC_BASELINE"; then
  echo "  ✓ fired"
else
  echo "  ✗ did not fire"; exit 1
fi
rm docs/product/prd/widget-customization.md
```

### 14.4 Promote to write-time later

Once the cycle-time check is stable, copy the check function into `scripts/check-state-schema.py`'s `validate_file()` (with `enforce_transition` semantics if appropriate), add the `--staged` invocation to `.githooks/pre-commit`, and add a write-time test assertion.

---

## 15. Operational walkthrough — bumping the framework version

You shipped a structural capability that meets §12.1 criteria. The checklist below is the full propagation sequence. Run it top-to-bottom; if you skip a step, the framework will drift between surfaces and the next operator (often you, two weeks later) will hit a confusing inconsistency.

### 15.1 The checklist (10 steps)

1. **Bump the manifest.** Edit [`.claude/shared/framework-manifest.json`](../../.claude/shared/framework-manifest.json): bump `framework_version` (e.g., `7.6 → 7.7`); update `description`; add new capability flags to `capabilities`; add a new top-level block `v<X>_<name>` mirroring the `v7_6_mechanical_enforcement` shape.
2. **Update [`CLAUDE.md`](../../CLAUDE.md).** Update the "## Data Integrity Framework" header. Add new check codes to the Write-time gates list. Add new defenses to the appropriate block. Update "## Known Mechanical Limits" if Class B gaps changed.
3. **Update [`docs/skills/evolution.md`](../skills/evolution.md).** Update the `> **Status:** v<X>` line. Add a new dated note. Add a new row to the version table at the bottom.
4. **Update THIS dev guide.** Bump the title `(v1.0 → v<X>)`. Bump the "Current version" callout at the top. Add a new row to the §12 timeline table. If the change introduced new gates, update the §10.1 check-code table AND the §2.2 layer diagram. If you promoted advisories to enforced, add an §2.0 snapshot block.
5. **Update the website-rendered guide.** Mirror the same changes into [`fitme-story/content/framework/dev-guide.md`](https://github.com/Regevba/fitme-story/blob/main/content/framework/dev-guide.md) (the Next.js render source for `/framework/dev-guide`). The FT2 → fitme-story sync script handles `src/data/docs/docs/architecture/dev-guide-v1-to-v7-7.md` automatically, but `content/framework/dev-guide.md` is independent.
6. **Write the case study.** Create `docs/case-studies/<slug>-v<X>-case-study.md`. Follow [`mechanical-enforcement-v7-6-case-study.md`](../case-studies/mechanical-enforcement-v7-6-case-study.md) as the format reference. T1/T2/T3 tier tags are required forward of 2026-04-21 — the pre-commit hook will block the commit otherwise.
7. **Update memory + mirrors.** Update repo-root `project_*.md` mirror files where relevant. Add a memory entry under `~/.claude/projects/.../memory/project_<slug>.md`. Update `MEMORY.md` index.
8. **Cross-repo.** If user-visible, add a new MDX case study slot in `fitme-story/content/04-case-studies/`. If it relates to the trust page, append a section to the appropriate trust subroute.
9. **Commit + push.** Pre-commit hooks catch tier-tag gaps in the case study and phase-transition discipline failures. Fix and re-commit if any fire.
10. **Verify.** Run `bash scripts/test-v7-5-pipeline.sh` — all assertions should pass. If you added a new check code (per §14), the count line in the script header updates.

### 15.2 What NOT to skip — the dev-guide drift trap

The most common failure mode is finishing steps 1–3 (manifest, CLAUDE.md, evolution doc) and then forgetting steps 4 + 5 (this dev guide + the website-rendered mirror). The result: CLAUDE.md says "current version v7.9," `framework-manifest.json` says `"framework_version": 7.9`, and yet the `/framework/dev-guide` page on the website still says "v1.0 → v7.8.6" in its title. Operators landing on the website think the framework is 3 days behind reality.

> **Concrete example.** The v7.9 promotion (shipped 2026-05-21 via [FT2 PR #417](https://github.com/Regevba/FitTracker2/pull/417)) bumped CLAUDE.md, the manifest, and `fitme-story/content/framework/dev-guide.md`. It missed this FT2 dev-guide canonical and its sync mirror. The drift was caught + fixed 3 days later in the same PR that introduced this callout.

**Pre-flight check (do this before pushing the bump):**

```bash
grep -nE '^# .* \(v1\.0 → ' \
  /Volumes/DevSSD/FitTracker2/docs/architecture/dev-guide-v1-to-v7-7.md \
  /Volumes/DevSSD/fitme-story/content/framework/dev-guide.md
```

Both files should show the same `v<X>` in their H1. If they diverge, finish step 4 + 5 before pushing.

### 15.3 Version-bump criteria (when does a change qualify?)

A major bump (e.g., v7.6 → v7.7) requires:

1. **A new structural capability** — not just code changes within an existing capability.
2. **A propagated update across surfaces** — manifest, CLAUDE.md, evolution doc, case study, this dev guide, the website-rendered mirror, trust-page integration where relevant.
3. **A measurement that the change is real** — pipeline test, integrity check, or instrumented data.

Minor bumps (e.g., v7.5 → v7.5.1) extend an existing capability without introducing a new layer.

---

## 16. Cross-repo Code Connect bridge (orthogonal capability)

This section documents a SKILL-LAYER capability that is orthogonal to the framework version axis (v7.8.x). It evolved on the `/design` skill (v4.X → v4.X+CC) and ships across BOTH FT2 and fitme-story. It is included in the dev guide because new UI-touching features rely on it for designer-developer feedback loop closure.

### 16.1 Why it exists

`/design build` (v4.X) closed the spec → Figma chain forward: every feature's screens get pushed into the design library, captured node IDs land in `state.json::figma_node_ids`, and the matrix in `figma-code-sync-status.md` records which Figma frame corresponds to which Swift View. v4.X+CC closes the OTHER direction — Figma library frame → "show me the actual React/SwiftUI code" — via Figma Code Connect mappings.

Without v4.X+CC, opening any frame in Figma's Dev Mode shows no code snippet. With it, the right-pane shows the actual `Button(...)`, `<HonestDisclosure>{...}</HonestDisclosure>`, etc. that renders the frame in production. Designer ↔ developer feedback loop closes.

### 16.2 Architecture (both repos)

```
.figma.{swift,tsx} mapping files    ←  authored manually (PR #277, #75) OR
                                       auto-scaffolded (Layer A, scripts/scaffold-figma-mapping.{py,mjs})
       │
       ▼
figma.config.json (web) / figma.config.json + Figma.toml (iOS)
       │
       ▼
npx @figma/code-connect figma connect publish
       │
       ├─ React parser (built into npm package) → publishes .figma.tsx
       └─ Swift: npm CLI subprocess `swift run --package-path .figma-cc-tools figma-swift`
              parses .figma.swift → JSON-RPC over stdio → npm CLI publishes
       │
       ▼
Figma Dev Mode shows the snippet for each mapped frame
```

### 16.3 The 3 automation layers

- **Layer A — scaffold scripts.** `scripts/scaffold-figma-mapping.py` (FT2) + `scripts/scaffold-figma-mapping.mjs` (fitme-story). Reads `<feature>/state.json::figma_node_ids`, generates matching `.figma.{swift,tsx}` template files alongside the SwiftUI Views / React components. Coalesces multi-state variants into one mapping file with multiple `figma.connect()` calls. Override `code_mapping` in figma_node_ids for keys that don't match the snake_case → PascalCase heuristic. PRs #279 (iOS) + fitme-story #77 (web).
- **Layer B — `/design build` skill extension.** `.claude/skills/design/SKILL.md` Step 4 appends an auto-scaffold sub-bullet: after `figma_node_ids` is populated, the skill invokes the scaffold script for the active repo. Closes the "manual mapping author per new UI feature" gap. PR #280.
- **Layer C — CI publish workflows.** `.github/workflows/figma-code-connect-publish.yml` in BOTH repos runs `npx figma connect publish` on push to main when `*.figma.{swift,tsx}` or config changes. Web: ubuntu runner, npm CLI directly. iOS: macos-15 runner + SPM cache + npm CLI with `figma.config.json::swiftPackagePath` pointing at `.figma-cc-tools/Package.swift` (SPM wrapper subdir). Gated on `FIGMA_ACCESS_TOKEN` repo secret; skips with clear log if missing. PRs #281 + #283 fix + fitme-story #79.

### 16.4 Two new mechanical gates on `/design`

| Gate | Phase | What it verifies | Block on |
|---|---|---|---|
| Code Connect write-access (Step 3.5 in `/design preflight`) | Phase 3.f | Token presence (local env + repo secret in BOTH repos) + publish dry-run probe (catches missing `file_dev_resources:write` scope) | Auth-failure → P1 advisory; token absent everywhere → P2 advisory |
| Spec ↔ build parity (Step 3.5 in `/design pre-merge-review`) | Phase 6.c | Every spec'd surface (parsed from `ux-spec.md` / `integration-spec.md`) has BOTH a `state.json::figma_node_ids` entry AND a `.figma.{swift,tsx}` mapping file | `missing` or `mapping_only` parity status (build incomplete) |

Records to `figma-bridge-status.json::code_connect_access` (preflight) + `state.json.pre_merge_review.design_parity` (pre-merge).

### 16.5 Critical Swift parser IPC discovery (worked example)

The `@figma/code-connect@1.4.4` npm package only ships React, HTML, and Storybook parsers natively. Swift parsing is delegated via subprocess to a `figma-swift` binary built from the same GitHub repo via SPM.

When `figma connect publish` is invoked from FT2:

1. npm CLI reads `figma.config.json` → finds `parser: "swift"` + `swiftPackagePath: ".figma-cc-tools/Package.swift"`
2. Calls `getSwiftParserDir()` → resolves to `.figma-cc-tools` (the wrapper subdirectory)
3. Spawns subprocess: `swift run --package-path .figma-cc-tools figma-swift`
4. Sends a JSON request over stdin to the subprocess: `{ mode: "PARSE", config: {...}, paths: [...] }`
5. `figma-swift` parses the `.figma.swift` files (SwiftSyntax-based AST walk, extracts `FigmaConnect` protocol conformances + `figmaNodeUrl` literal + `body` example) and writes JSON response to stdout
6. npm CLI receives the connections, then makes Figma API calls to publish each one

**Implementation gotcha:** The `Package.swift` wrapper MUST live in a subdirectory (`.figma-cc-tools/`) — putting it at FT2 repo root would tempt SPM to scan FT2's Xcode app sources (which depend on Xcode-only modules) and fail to compile. The subdirectory needs an `Empty.swift` placeholder source to satisfy SPM's "needs at least one target" rule, even though that target is never built.

**Failure mode caught during dry-run (2026-05-10):** without `figma.config.json` at FT2 root (only `Figma.toml`, which is the standalone Swift CLI's config format), the npm CLI fell back to the html parser, scanned 14817 files in the repo, and errored. PR #283 added the `figma.config.json` + SPM wrapper; PR #281's first attempt (ubuntu + npx-only) is the broken approach this replaces.

### 16.6 Operator setup (one-time)

1. Generate Figma Personal Access Token at <https://www.figma.com/settings> → Security → Personal access tokens
2. Required scopes: `file_content:read` + `file_dev_resources:read` + `file_dev_resources:write` (Code Connect mappings ARE dev resources in Figma's data model — there's no explicit "Code Connect" scope). `library_content:read` recommended.
3. Add as `FIGMA_ACCESS_TOKEN` repo secret in BOTH `Regevba/FitTracker2` and `Regevba/fitme-story`
4. Until set, both publish workflows skip cleanly with clear log message

**Operator setup completed 2026-05-10T06:38–06:39Z.**

### 16.7 Companion docs

- iOS operator runbook: [`docs/design-system/ios-code-connect-workflow.md`](../design-system/ios-code-connect-workflow.md)
- Web architecture: [`docs/design-system/fitme-story-design-architecture.md`](../design-system/fitme-story-design-architecture.md)
- Figma↔code matrix + Code Connect verification contract: [`docs/design-system/figma-code-sync-status.md`](../design-system/figma-code-sync-status.md)
- Skill ecosystem evolution: [`docs/skills/evolution.md`](../skills/evolution.md) §27
- Public showcase: fitme-story `/pm-flow` page §`#code-connect`

---

## 17. References

### Canonical docs
- [`CLAUDE.md`](../../CLAUDE.md) — project rules (always loaded; fastest reference)
- [`docs/architecture/feature-lifecycle-event-catalog.md`](./feature-lifecycle-event-catalog.md) — companion to this guide; the event/log/gate catalog (artifact stack, trigger stack, gate stack, phase-by-phase event matrix, mermaid flow diagrams, worked example)
- [`docs/skills/architecture.md`](../skills/architecture.md) — skill-by-skill anatomy
- [`docs/skills/evolution.md`](../skills/evolution.md) — full version-by-version history
- [`docs/skills/pm-workflow.md`](../skills/pm-workflow.md) — user-facing PM workflow
- [`.claude/integrity/README.md`](../../.claude/integrity/README.md) — integrity layer canonical entry
- [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) — Observed Patterns Catalog (gate-firing pattern manifest; consult FIRST when a gate fires; `make observed-patterns`)

### Case studies (most relevant for this guide)
- [`docs/case-studies/data-integrity-framework-v7.5-case-study.md`](../case-studies/data-integrity-framework-v7.5-case-study.md) — v7.5 narrative
- [`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`](../case-studies/mechanical-enforcement-v7-6-case-study.md) — v7.6 narrative + comprehensive CU + workload analysis
- [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](../case-studies/framework-v7-7-validity-closure-case-study.md) — v7.7 narrative
- [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../case-studies/framework-v7-8-bridge-case-study.md) — v7.8 live append-only journal (silent-pass prevention + inter-agent awareness)
- [`docs/case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md) — 5 mechanically unclosable Class B gaps (Gap 1 closed in v7.8 advisory)
- [`docs/case-studies/normalization-framework.md`](../case-studies/normalization-framework.md) — CU formula reference
- [`docs/case-studies/data-quality-tiers.md`](../case-studies/data-quality-tiers.md) — T1/T2/T3 convention

### Audit artifacts
- [`docs/case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md`](../case-studies/meta-analysis/independent-audit-2026-04-21-gemini.md) — verbatim Gemini audit
- [`trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md`](../../trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md) — remediation tracker
- [`docs/master-plan/codex-ssd-audit-2026-04-19.md`](../master-plan/codex-ssd-audit-2026-04-19.md) — Codex SSD audit (pre-v7.5 context)

### Implementation plans + specs
- [`docs/superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md`](../superpowers/plans/2026-04-25-v7-6-mechanical-enforcement-phases-2-4.md) — v7.6 plan agent output
- [`docs/superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md`](../superpowers/specs/2026-04-27-framework-v7-7-validity-closure-design.md) — v7.7 spec
- [`docs/superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md`](../superpowers/plans/2026-04-27-framework-v7-7-validity-closure.md) — v7.7 plan
- [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) — v7.8 + v7.9 bridge design

### Scripts (alphabetical)
- [`scripts/append-feature-log.py`](../../scripts/append-feature-log.py) — contemporaneous log writer
- [`scripts/check-branch-drift.py`](../../scripts/check-branch-drift.py) — W9 branch-drift PostToolUse:Bash alert (v7.8.5)
- [`scripts/check-case-study-preflight.py`](../../scripts/check-case-study-preflight.py) — write-time case study checks
- [`scripts/check-ssh-agent.sh`](../../scripts/check-ssh-agent.sh) — W1 ssh-agent SessionStart preflight (v7.8.6)
- [`scripts/check-state-schema.py`](../../scripts/check-state-schema.py) — write-time + cycle state.json checks (incl. branch-isolation + state_owner gates)
- [`scripts/create-isolated-worktree.py`](../../scripts/create-isolated-worktree.py) — branch-isolation auto-isolation (v7.8.1)
- [`scripts/cross-layer-freshness.py`](../../scripts/cross-layer-freshness.py) — W20 cross-layer freshness scan (v7.8.6)
- [`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py) — daily launchd checkpoint
- [`scripts/documentation-debt-report.py`](../../scripts/documentation-debt-report.py) — Tier 3.2 ledger
- [`scripts/ensure-pr-cache-fresh.py`](../../scripts/ensure-pr-cache-fresh.py) — PR_CACHE_STALE auto-refresh (v7.8.4)
- [`scripts/integrity-check.py`](../../scripts/integrity-check.py) — cycle-time integrity check
- [`scripts/integrity-diff.py`](../../scripts/integrity-diff.py) — diff vs baseline anchor (v7.8.6)
- [`scripts/measurement-adoption-report.py`](../../scripts/measurement-adoption-report.py) — Tier 1.1 ledger + history
- [`scripts/membrane-status.py`](../../scripts/membrane-status.py) — Mechanism F membrane readout
- [`scripts/merge-driver-dedup.py`](../../scripts/merge-driver-dedup.py) — Mechanism E append-only-ledger merge driver
- [`scripts/observe-cache-hit.py`](../../scripts/observe-cache-hit.py) — Mechanism C PostToolUse:Read capture (v7.8)
- [`scripts/preflight.py`](../../scripts/preflight.py) — unified pre-work aggregator (v7.8.6)
- [`scripts/runtime-smoke-gate.py`](../../scripts/runtime-smoke-gate.py) — Tier 2.1 smoke runner
- [`scripts/snapshot-phase-completion.sh`](../../scripts/snapshot-phase-completion.sh) — per-phase off-SSD backup (v7.8.3)
- [`scripts/test-v7-5-pipeline.sh`](../../scripts/test-v7-5-pipeline.sh) — mechanical-enforcement regression test
- [`scripts/weekly-trend-scan.py`](../../scripts/weekly-trend-scan.py) — weekly gate-coverage + adoption trend scan (v7.8.6)

### Workflows (full inventory in §11.3)
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — Xcode build + test + tokens-check + ui-audit
- [`.github/workflows/ci-docs-skip.yml`](../../.github/workflows/ci-docs-skip.yml) — skips iOS build for docs-only PRs
- [`.github/workflows/integrity-cycle.yml`](../../.github/workflows/integrity-cycle.yml) — 72h cycle (v7.1 → v7.5), cron `0 4 */3 * *`
- [`.github/workflows/pr-integrity-check.yml`](../../.github/workflows/pr-integrity-check.yml) — per-PR (v7.6 Phase 2a)
- [`.github/workflows/framework-status-weekly.yml`](../../.github/workflows/framework-status-weekly.yml) — weekly cron `0 5 * * 1` (v7.6 + v7.8.6 trend scans)
- [`.github/workflows/dependency-audit-weekly.yml`](../../.github/workflows/dependency-audit-weekly.yml) — weekly npm audit, cron `0 6 * * 1` (v7.8.6)
- [`.github/workflows/audit-prompts-weekly.yml`](../../.github/workflows/audit-prompts-weekly.yml) — external-audit prompt substrate, cron `0 6 * * 1`
- [`.github/workflows/audit-bundle-on-tag.yml`](../../.github/workflows/audit-bundle-on-tag.yml) — deterministic audit bundle on tag push
- [`.github/workflows/ucc-audit-log-sync.yml`](../../.github/workflows/ucc-audit-log-sync.yml) — UCC audit-log sync, cron `17 5 * * *`
- [`.github/workflows/weekly-backup.yml`](../../.github/workflows/weekly-backup.yml) — weekly off-repo backup, cron `0 2 * * 0`
- [`.github/workflows/figma-code-connect-publish.yml`](../../.github/workflows/figma-code-connect-publish.yml) — Code Connect publish (§16)
- Local launchd: `com.fittracker.daily-integrity-checkpoint.plist` — daily checkpoint (`make install-daily-cron`)

### External reference
- [GitHub Actions injection guide](https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/) — security pattern referenced in workflow files

---

*This guide is updated whenever the framework's structural shape changes. If you find an inaccuracy or a stale reference, file a PR — the pre-commit hook will tell you immediately if the doc is out of sync with the code.*
