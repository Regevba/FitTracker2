# Skills Review — FitTracker2 (`/.claude/skills/*`)

**Date:** 2026-05-13 · **Framework:** v7.8.5 · **Scope:** the 11 project-owned skills under `.claude/skills/` (excludes superpowers / vercel-plugin / figma vendor skills).

> Companion docs: [README.md](README.md) · [architecture.md](architecture.md) · [evolution.md](evolution.md) · [pm-hub-evolution.md](pm-hub-evolution.md)
>
> This review supersedes earlier ad-hoc audit notes. Next scheduled review: 2026-08-13 (90-day cadence) OR after first v8.x feature ships, whichever is earlier.

---

## Purpose

The skills ecosystem has accreted across 5 framework majors (v1.0 → v7.8.5) and >30 PRs. Most skills were added before the integrity-cycle, branch-isolation, and observed-patterns layers existed, so the *enforcement* layer has moved on while many `SKILL.md` files still describe behavior that pre-dates it. This document is the actionable improvement queue + per-skill scorecard generated from a 2026-05-13 systematic audit, cross-referenced against Anthropic's officially published PM skill set.

---

## 1 · Inventory (one row per skill)

| Skill | LoC | Sub-cmds | Owns (write) | External adapters | Cross-calls | Recently versioned |
|---|---:|---:|---|---|---|---|
| **pm-workflow** | 1688 + 4 sub-files | 1 (`/pm-workflow {feat}`) | `state.json` per feature | all (routed) | all 10 spokes + superpowers | v7.8.5 (W9 hook, observed-patterns preflight) |
| **ux** | 525 | 9 | `design-system.json::ux_coverage`, cache | axe (MCP) | `/design` (hand-off) | v4.X (2026-05-06) + kill-criteria-resolution check (v7.8) |
| **design** | 344 | 7 (2 deprecated) | `design-system.json`, `figma-bridge-status.json` | figma MCP, figma-use, figma-generate-design | `/ux` | v4.X+CC (2026-05-10 Code Connect bridge) |
| **cx** | 242 | 7 | `cx-signals.json` | app-store-connect, sentry | `/marketing` `/design` `/dev` `/qa` `/pm-workflow` | base |
| **analytics** | 232 | 5 | `metric-status.json` | ga4, mixpanel | `/marketing` `/pm-workflow` `/cx` `/qa` | v4.3 (case-study instr layer) |
| **marketing** | 231 | 7 | `campaign-tracker.json` | app-store-connect, firecrawl, ayrshare | `/cx` (dispatches in) `/research` | base |
| **ops** | 231 | 4 | `health-status.json`, `framework-health.json` | sentry, datadog | UCC dashboard | v4.3 (Control Room integration) |
| **research** | 230 | 7 | `context.json`, `cx-signals.json` | firecrawl, apify | `/marketing` | base |
| **release** | 187 | 4 | (reads only) | app-store-connect, fastlane | `/analytics` `/ops` | base |
| **qa** | 179 | 5 | `test-coverage.json`, `health-status.json` | xcode, codecov, axe, sentry | observed-patterns catalog | v7.8.5 (observed-patterns preflight) |
| **dev** | 173 | 5 | `health-status.json` | github CLI, security-audit | observed-patterns catalog | v7.8.5 (W1/W3/W5/W9 patterns) |

**Per-skill scorecard** (5 axes, ✅ ⚠️ ❌):

| Skill | Boundaries | Cross-refs current | Versioned/dated | Sub-cmds testable | Observed-patterns linked |
|---|:---:|:---:|:---:|:---:|:---:|
| pm-workflow | ✅ | ✅ | ✅ v6.0 + v7.8.5 | ⚠️ no dispatcher tests | ✅ |
| ux | ✅ | ✅ | ✅ v4.X | ❌ preflight tests absent | ❌ |
| design | ✅ | ✅ | ✅ v4.X+CC | ⚠️ Code Connect parity untested | ❌ |
| qa | ✅ | ✅ | ✅ v7.8.5 | ❌ self-testing skills meta-gap | ✅ |
| dev | ✅ | ✅ | ✅ v7.8.5 | ❌ no `/dev review` automation tests | ✅ |
| analytics | ✅ | ⚠️ taxonomy CSV growing stale | ⚠️ v4.3 | ❌ | ❌ |
| ops | ✅ | ⚠️ Datadog adapter unused | ⚠️ v4.3 | ❌ | ❌ |
| cx | ✅ | ⚠️ dispatch handlers unverified | ❌ undated | ❌ | ❌ |
| release | ✅ | ⚠️ Fastlane adapter unused | ❌ undated | ❌ | ❌ |
| marketing | ✅ | ⚠️ Ayrshare adapter not wired | ❌ undated | ❌ | ❌ |
| research | ✅ | ✅ | ❌ undated | ❌ | ❌ |

---

## 2 · Wiring model

- **Hub-and-spoke via shared JSON.** Skills never call each other directly. They read/write 15 files under `.claude/shared/*.json`. `skill-routing.json` (`v5.0`, `load_mode: on_demand`) maps each lifecycle phase to skills + model tier (Sonnet vs Opus) + batch operations + result-forwarding + systolic chains.
- **Validation gate** sits in front of every shared write: GREEN ≥95% / ORANGE 90–95% / RED <90% confidence; RED blocks the write until human resolves.
- **L1/L2/L3 cache.** L1 dirs exist for every spoke (session-scoped). L2 `_shared/` promotes cross-skill patterns. L3 `_project/` holds framework-level patterns. Hits logged via [scripts/append-feature-log.py](../../scripts/append-feature-log.py) → `state.json::cache_hits[]`.
- **Six integration adapters** live under `.claude/integrations/{ga4,app-store-connect,sentry,firecrawl,axe,security-audit}`. Each is `adapter.md` + `schema.json` + `mapping.json`. Four more adapters are referenced in SKILL.md but absent on disk: **mixpanel** (analytics), **datadog** (ops), **fastlane** (release), **ayrshare** (marketing).
- **Four enforcement layers** run beneath the skills: pre-commit hook (16+ write-time gates), per-PR review bot, 72h integrity cycle, weekly framework-status cron. These are *gate plumbing*, not skills, but skills assume their outputs (e.g. `/ops health` reads `framework-health.json`).

---

## 3 · Anthropic cross-reference

Anthropic publishes an official PM skill set at [`anthropics/knowledge-work-plugins/product-management/`](https://github.com/anthropics/knowledge-work-plugins/tree/main/product-management) — **7 commands + 7 skills** live on `main`. Authoring spec at [`anthropics/skills/skill-creator/SKILL.md`](https://github.com/anthropics/skills). [PR #55](https://github.com/anthropics/knowledge-work-plugins/pull/55) (OPEN) would expand to 14 + 11.

### 3A · Gap candidates from Anthropic content (don't exist in our 11 skills)

| Anthropic skill | Coverage | Maps to ours? | Gap severity |
|---|---|---|---|
| `product-brainstorming` | 4 modes (problem/solution/assumption/strategy) + HMW / JTBD / First Principles / OST + 6 anti-patterns | `superpowers:brainstorming` is generic, NOT PM-flavored | **HIGH** |
| `roadmap-management` | RICE + MoSCoW + Now/Next/Later + decision memos | We have a roadmap *file*, no codifying skill | **HIGH** |
| `metrics-tracking` (business layer) | Product-metric review cadence, OKRs | Our `analytics` is instrumentation-correctness, different concern | MEDIUM |
| `stakeholder-comms` | Update templates per audience | None (low value for solo project) | LOW |
| PR #55 candidates: `sprint-execution`, `executive-synthesis`, `release-communication` | (passive watch) | partial overlap w/ `pm-workflow` + `release` | PASSIVE |

**Not a gap:** `feature-spec` (our `pm-workflow` Phase 2 is heavier), `competitive-analysis` (covered by `research` + `marketing`).

### 3B · Quality-benchmark violations against `skill-creator`

1. **`pm-workflow` is 1688 lines; spec recommends <500.** Single biggest non-conformance. The Anthropic pattern is: thin orchestrator + `references/{topic}.md` files loaded on demand.
2. **Description fields are catalog-style, not trigger-style.** Anthropic guidance: *"Claude tends to undertrigger skills — make descriptions a little 'pushy'."* Our descriptions read like a feature catalog instead of explicit triggers ("Use when X, Y, Z").
3. **No `references/` pattern.** Anthropic skills practice progressive disclosure via reference markdown loaded on demand. Our `cache/` is for cross-session learning, not on-demand reference content. Different purpose.
4. **Commands and skills are co-mingled.** Anthropic separates thin `commands/*.md` from framework `skills/*/SKILL.md`. We embed sub-commands inside SKILL.md. Works fine privately; matters only if we publish externally.
5. **Anti-patterns sections missing.** Every Anthropic PM skill ends with "Do not..." lists. Our skills are light on these.
6. **No per-skill evals.** Anthropic ships an `eval-viewer/generate_review.py`. We have nothing comparable.

### 3C · What aligns with Anthropic's guidance (don't change)

- **11-skill cardinality** — Anthropic's live PM plugin has 7 (11 if PR #55 merges). Same order of magnitude.
- **Hub-and-spoke orchestration** — `pm-workflow` → 10 spokes mirrors Anthropic's command → references → skill chain.
- **Extra phases (Code/Test/Review/Merge)** — justified for solo iOS-native shop; Anthropic's plugin assumes engineers handle these elsewhere.
- **T1/T2/T3 tier-tagging, kill criteria, mechanical pre-commit gates, integrity-cycle, gate-coverage telemetry** — none exist in Anthropic's PM plugin. **Our edge. Keep.**
- **Cross-repo state sync, Figma MCP + Code Connect bridge, pre-merge gates** — no Anthropic equivalent. **Keep.**

---

## 4 · Themes (cross-cutting findings)

### T1 · Skill-content drift from framework reality
Several SKILL.md files describe v4.x-era behavior without mentioning v7.x bridge mechanisms (A–F), observed-patterns catalog, gate-coverage telemetry, or branch-isolation. **Affected:** cx, marketing, release, research, analytics, ops. **Symptom:** a fresh agent loading the skill won't know to consult [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) before debugging, or to write `gate-coverage.jsonl` entries.

### T2 · Adapter ghost-references
SKILL.md files name external adapters that don't exist as integration packages: `mixpanel` (analytics), `datadog` (ops), `fastlane` (release), `ayrshare` (marketing). A skill instructing the agent to "dispatch to datadog MCP" with no adapter on disk is a silent dead-end. **Severity:** low for now (no one is calling them), but each is an unhonored promise.

### T3 · Skills cannot test themselves
The `qa` skill defines test density targets for the codebase but no skill tests the skills layer. SKILL.md files have no fixtures, no dry-run mode, no `make skills-check`. PR #317 (2026-05-12) exposed `BRANCH_ISOLATION_VIOLATION` Mode B was unreachable in `main()` for 5 days — same failure-mode would catch a broken `/ux preflight` instantly if a fixture existed. **Echoes** v7.9 candidates F14–F18.

### T4 · Skills lack a versioning convention
Some SKILL.md files have `v4.X (2026-05-06)` headers, some have nothing. Across the 11 skills: 5 dated/versioned, 6 undated. No `last_updated` frontmatter, no per-skill changelog.

### T5 · Observed-patterns catalog isn't surfaced everywhere
The 23-pattern catalog ([`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md), shipped 2026-05-13 PR #328+#341) is referenced only by **dev**, **qa**, and **pm-workflow**. The other 8 skills don't know it exists.

### T6 · Sub-command testability is zero
Across 60+ documented `/skill sub-cmd` invocations, none have unit tests, no smoke tests, no fixtures. A 1-line "does this prompt still cite a file path that exists?" check would catch ~half the cross-ref rot.

### T7 · UCC / Control Room integration is hub-only
`/ops` is the only skill that writes to `framework-health.json`, which is consumed by the UCC. The other 10 skills could surface state but don't. Specifically missing: `/qa coverage`, `/analytics adoption`, `/cx sentiment` aggregates do not feed UCC panels.

### T8 · No skill governs the skills themselves
There's no `/dev skills-audit` or equivalent. The skills system is structurally a foundational layer of the framework, yet no skill is responsible for keeping it healthy.

### T9 · Conformance with Anthropic's skill-authoring spec
See §3B. Five concrete violations vs [`skill-creator`](https://github.com/anthropics/skills): pm-workflow length (1688 vs <500), catalog-style descriptions risk under-triggering, missing `references/` progressive disclosure, no anti-patterns sections, no per-skill evals. Plus a separate concern from §3A: we have no PM-flavored brainstorming skill and no roadmap-management skill.

---

## 5 · Concrete proposals

Ordered by leverage. Effort tags: **S** (≤1h), **M** (1–4h), **L** (4h+). Items marked **[ANTH]** were added after the Anthropic cross-reference (§3).

### P0 — Worth shipping this week

**P0.0 · Audit + rewrite 11 `description:` fields for trigger-richness** — **S** **[ANTH]**
*Why:* Anthropic explicitly warns Claude undertriggers skills with vague descriptions. Our descriptions are catalog-style and likely fail to fire when relevant.
*How:* Each description gets reshaped as `Use when {trigger A}, {trigger B}, or {trigger C}. {1-sentence "what it does"}.` Pattern modeled on Anthropic's PM plugin descriptions.
*Files:* all 11 [.claude/skills/{skill}/SKILL.md](../../.claude/skills/) frontmatter blocks.
*Closes:* part of T9.

**P0.1 · Add `last_updated` + `framework_version` frontmatter to every SKILL.md** — **S**
*Files:* all 11 SKILL.md.
```yaml
---
name: {skill}
description: ...
last_updated: 2026-05-13
framework_version: v7.8.5
---
```
*Closes:* T4. Lets P0.4 audit staleness mechanically.

**P0.2 · Surface observed-patterns catalog in the 8 skills that don't reference it** — **S**
*Files:* analytics, cx, design, marketing, ops, release, research, ux SKILL.md.
*Add stanza:* "Before debugging any gate fire or workflow anomaly: `make observed-patterns`. Append novel patterns BEFORE closing the feature (mandatory per CLAUDE.md §v7.8.5)."
*Closes:* T5.

**P0.3 · Delete adapter ghost-references** — **S**
Strike `mixpanel`, `datadog`, `fastlane`, `ayrshare` from the four SKILL.md files where they appear. Acknowledge GA4 + Sentry + App Store Connect + Firecrawl + Axe + security-audit as the only wired adapters.
*Closes:* T2.

**P0.4 · Add `make skills-audit` mechanical check** — **M**
*New script:* `scripts/skills-audit.py`. For each SKILL.md, verify: (1) frontmatter present (P0.1); (2) every referenced shared file exists in `.claude/shared/`; (3) every referenced adapter exists in `.claude/integrations/`; (4) every referenced script exists; (5) every cross-skill call is documented. Fail loud, exit non-zero on broken refs.
*Wire into:* `make integrity-check` — advisory in first cycle, enforced thereafter.
*Closes:* T3 + T6 + T8.

**P0.5 · Decide qa/cx/marketing/release/research bump or sunset** — **S**
For each of the 5 undated, base-version skills: is there backlog work that will exercise them in v8.x? If no — annotate `status: "stable, last-modified date"`. If yes — schedule a bump that brings them up to v7.x patterns. Empty `status` is the worst signal.

### P1 — Worth scheduling within the v8.x window

**P1.0a · Split `pm-workflow/SKILL.md` (1688 → <500) via Anthropic `references/` pattern** — **L** **[ANTH]**
*Why:* Single biggest spec violation. 1688-line skill files are unfocused; Claude has to load all of it even when it only needs Phase 4 guidance.
*Target shape:* SKILL.md shrinks to a phase-routing core (~400 lines) + `.claude/skills/pm-workflow/references/phase-{0..9}.md` holding per-phase choreography.
*Risk:* Must be tested on a live `/pm-workflow` invocation to confirm Claude correctly loads the right reference. Pair with P1.3 fixtures.
*Closes:* biggest T9 violation.

**P1.0b · Add `/brainstorm-pm` skill modeled on Anthropic `product-brainstorming`** — **M** **[ANTH]**
*Why:* `superpowers:brainstorming` is generic; Anthropic's PM variant ships 4 modes (problem / solution / assumption / strategy) + 4 PM frameworks (HMW / JTBD / First Principles / OST) + 6 anti-patterns. Maps cleanly onto our Phase 1 (Research) entry point.
*Files:* new `.claude/skills/brainstorm-pm/SKILL.md`. Wire into `pm-workflow` Phase 1 routing.
*Closes:* §3A Gap #1.

**P1.0c · Add `/roadmap` skill (or pm-workflow roadmap sub-cmd)** — **M** **[ANTH]**
*Why:* We maintain [docs/master-plan/master-backlog-roadmap.md](../master-plan/master-backlog-roadmap.md) ad-hoc; no skill encodes RICE / MoSCoW / Now-Next-Later. Anthropic's `roadmap-management` provides the template.
*Recommend:* `/pm-workflow roadmap {review|prioritize|decide}` sub-cmd inside the hub (keeps cardinality at 11 per §3C).
*Files:* extend `.claude/skills/pm-workflow/SKILL.md` + new `references/roadmap.md`.
*Closes:* §3A Gap #2.

**P1.0d · Add anti-patterns section to every SKILL.md** — **S** **[ANTH]**
*Why:* Anthropic PM skills end with explicit "Do not..." lists. Cheap to add, big quality lift, encodes hard-won mistakes (e.g. `cx` should say "Do not infer sentiment from <50 reviews"; `release` should say "Do not promote a build that hasn't passed `make verify-local`").
*Files:* all 11 SKILL.md, 3-5 bullets each.
*Closes:* part of T9.

**P1.1 · `/dev skills` skill-of-skills sub-command** — **M**
*New:* `/dev skills audit | trace | freshness`. Wraps P0.4 + adds: `/dev skills trace {feature}` = print which skills fired in a feature's `state.json::cache_hits[]`. Surfaces actual usage; lets us spot zero-usage skills empirically.
*Closes:* T8.

**P1.2 · UCC panel: Skills Activity** — **M**
*File:* `fitme-story/src/app/control-room/skills/page.tsx` (new). Aggregate per-skill: last invocation, last bump date, cross-skill dispatch counts. Data sourced from `state.json` + `gate-coverage.jsonl` + `_session-*.events.jsonl`.
*Closes:* T7.

**P1.3 · Self-test fixture for every preflight/pre-merge skill** — **M** per skill
*Affected skills:* ux, design. *Fixture shape:* `.claude/skills/{skill}/fixtures/{scenario}.json` + 1 expected-output golden file per scenario. Wire into CI.
*Closes:* T3.

**P1.4 · Cross-link adapters to consumers** — **S**
*File:* every `.claude/integrations/{adapter}/adapter.md`. Add a `consumed_by:` field listing SKILL.md files that reference it. Add inverse pointer (`adapters_used:`) to every SKILL.md.
*Closes:* T2.

**P1.5 · Skill-level changelog** — **S**
*New:* `docs/skills/CHANGELOG.md`. One section per skill, append-only. Bump every time `framework_version:` in a SKILL.md changes.
*Closes:* T4.

**P1.6 · `/cx digest` + `/analytics report` cross-link to UCC** — **S**
Both skills can write a JSON sidecar (`cx-signals.json`, `metric-status.json`) that UCC already reads. Confirm the schema match + document the contract.
*Closes:* T7.

### P2 — Defer to v8.x backlog (concrete but not urgent)

**P2.1 · Promote 4 v4.X gates into 11-skill model** — **L**
Extend the preflight/pre-merge pattern from `/ux` + `/design` to `/qa`, `/analytics`, `/release`. Aligns with FEATURE_CLOSURE_COMPLETENESS v7.9 promotion.

**P2.2 · Skill boundaries enforcement test** — **M**
Add `SKILL_OWNERSHIP_VIOLATION` to write-time gates. A skill shouldn't write to a shared file outside its `owns` list.

**P2.3 · Per-skill prompt regression tests** — **L**
Snapshot the rendered SKILL.md prompt + a canonical input scenario; assert output stability across model updates. Out-of-scope until prompt-eval tooling lands.

**P2.4 · Retire/merge low-usage skills** — **L**
After P1.1 surfaces usage, decide whether `/release` deserves to be standalone vs. folded into `/dev`. Same question for `/marketing` vs `/cx`. Don't act until empirical data shows zero-or-near-zero usage over 90 days.

**P2.5 · Skill versioning convention spec** — **M**
Document the rules: `v{major}.{minor}` bumped on sub-command add/remove/rename; `last_updated` bumped on any change; `framework_version` mirrors the host framework version at write time. Pair with P1.5.

---

## 6 · Out of scope

- **Superpowers, vercel-plugin, figma skills** — vendor-managed.
- **CLAUDE.md rewrites** — preserves current discipline; the doc is healthy.
- **/pm-workflow internal phase changes** — held back until v7.9 promotion decision (2026-05-21).
- **Anthropic PR #55 candidates** — passive watch; re-evaluate if/when [PR #55](https://github.com/anthropics/knowledge-work-plugins/pull/55) merges.
- **Per-skill evals** — defer until prompt-eval tooling lands; P2.3 already lists this.

---

## 7 · Verification

For each P0 item:

1. **P0.0** — `grep -L '^description: Use when' .claude/skills/*/SKILL.md` → expect empty.
2. **P0.1** — `grep -l 'last_updated:' .claude/skills/*/SKILL.md | wc -l` → expect 11.
3. **P0.2** — grep all 11 SKILL.md for `observed-patterns` → expect 11. Today: 3 (dev, qa, pm-workflow).
4. **P0.3** — grep all SKILL.md for `mixpanel|datadog|fastlane|ayrshare` → expect 0. Today: 4.
5. **P0.4** — `make skills-audit` exits 0. Wire into `make verify-local`.
6. **P0.5** — annotate frontmatter on 5 undated skills; verify via P0.4.

For P1 items: ship behind one PR each, gated by P0.4 passing.
- **P1.0a**: SKILL.md line count <500, `references/phase-*.md` files exist, live `/pm-workflow` smoke test passes.
- **P1.0b**: new skill responds to `/brainstorm-pm`; 4 modes + 4 frameworks documented.
- **P1.0c**: RICE/MoSCoW/Now-Next-Later docs present; decision-memo template exists.
- **P1.0d**: every SKILL.md ends with a "Do not..." section ≥3 bullets.
- **P1.1** unlocks empirical decision-making for P2.4.

For P2 items: re-evaluate after first 90-day window of P1.1 usage data.

---

## 8 · Critical files (for whoever implements)

- All 11 [`.claude/skills/*/SKILL.md`](../../.claude/skills/) — frontmatter, descriptions, observed-patterns stanza, anti-patterns section
- [.claude/skills/pm-workflow/](../../.claude/skills/pm-workflow/) — split target, plus new `references/phase-{0..9}.md` + `references/roadmap.md`
- `.claude/skills/brainstorm-pm/SKILL.md` — NEW (P1.0b)
- [.claude/integrations/](../../.claude/integrations/) — 6 existing + 4 ghost
- [.claude/shared/skill-routing.json](../../.claude/shared/skill-routing.json)
- [.claude/integrity/observed-patterns.md](../../.claude/integrity/observed-patterns.md)
- [CLAUDE.md](../../CLAUDE.md) — §Skills ecosystem block; minor reference updates only
- [docs/skills/](.) — README + architecture + evolution; reflect new conventions after ship
- `scripts/skills-audit.py` — NEW (P0.4)
- [scripts/integrity-check.py](../../scripts/integrity-check.py) — wire P0.4 into cycle (advisory first)
- [Makefile](../../Makefile) — add `skills-audit` target + chain into `integrity-check`
- `fitme-story/src/app/control-room/skills/page.tsx` — NEW (P1.2)

**Upstream reference repos** (for copying patterns, NOT vendoring):
- [`anthropics/knowledge-work-plugins`](https://github.com/anthropics/knowledge-work-plugins/tree/main/product-management) — Anthropic's 7-skill PM plugin (canonical PM templates)
- [`anthropics/skills`](https://github.com/anthropics/skills) — skill-creator authoring spec (frontmatter + length + references/ + anti-patterns)

---

## TL;DR

Eleven skills exist and are wired into the hub-and-spoke shared-state model. The system is **architecturally sound**. Where it has drifted is at the **content / measurement / authoring-spec-conformance** layers:

- 6 of 11 SKILL.md files are undated and don't reference v7.x mechanisms.
- 4 of 11 reference adapters that don't exist on disk.
- 8 of 11 don't surface the observed-patterns catalog.
- 11 of 11 have catalog-style descriptions that risk under-triggering (Anthropic spec).
- 1 of 11 (`pm-workflow`) is 1688 lines vs. Anthropic's <500 recommendation.
- 0 of 11 have explicit anti-patterns sections.
- 0 of 11 are mechanically audited for cross-reference integrity.
- 2 PM-flavored skills missing vs. Anthropic's PM plugin: `product-brainstorming`, `roadmap-management`.

**Top 4 recommended moves** (≤10h total — all S/M, no L):
1. **P0.0 + P0.1 + P0.2 + P0.3** — frontmatter + trigger-rich descriptions + observed-patterns stanza + delete ghost adapters (4 × S — ~2.5h).
2. **P0.4** — `make skills-audit` mechanical gate (M, ~2h). Single highest-leverage change; closes T3 + T8 in one PR.
3. **P1.0d** — anti-patterns sections on all 11 (S, ~1h). Closes part of T9.
4. **P1.0b + P1.0c** — `/brainstorm-pm` skill + roadmap sub-cmd (M + M, ~4h). Closes both §3A high-severity gaps.

**Larger, deferred to v8.x:** P1.0a (split pm-workflow, L) — biggest single conformance gap but biggest risk; needs fixture-driven verification.

The rest queues into v8.x.
