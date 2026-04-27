# Cache Read Paths Inventory

> Compiled 2026-04-27 by v7.7 T1 to scope the cache_hits writer-path
> instrumentation (M1 / closes #140). The instrumentation strategy
> depends on every read site being able to reach a single shared logger.

---

## Layer 1 — Per-skill caches

Located at `.claude/cache/<skill>/`. One directory per skill, each containing
`_index.json` (currently empty `entries[]` per audit FW-011/FW-012) plus
substantive JSON files with a `compressed_view` field that Claude reads as
context when the skill is invoked.

Directories found via `find .claude/cache -type d -maxdepth 2 | sort`:

```
.claude/cache
.claude/cache/_project
.claude/cache/_shared
.claude/cache/analytics
.claude/cache/cx
.claude/cache/design
.claude/cache/dev
.claude/cache/marketing
.claude/cache/ops
.claude/cache/pm-workflow
.claude/cache/qa
.claude/cache/release
.claude/cache/research
.claude/cache/ux
```

Per-skill cache files (non-index):

| Skill | Cache files |
|---|---|
| analytics | `ga4-event-spec.json`, `screen-prefix-convention.json` |
| cx | *(index only)* |
| design | `token-compliance-checker.json`, `ux-foundations-application.json`, `v2-refactor-pattern.json` |
| dev | `v2-implementation-recipe.json` |
| marketing | *(index only)* |
| ops | *(index only)* |
| pm-workflow | `work-type-decision.json` |
| qa | `analytics-test-patterns.json`, `test-strategy-patterns.json` |
| release | *(index only)* |
| research | *(index only)* |
| ux | `ux-spec-patterns.json`, `v2-screen-audit-playbook.json` |

No `L1-*` or `L2-*` named directories exist — the naming convention in docs
refers to *tiers*, not directory prefixes. L1 = per-skill dirs listed above.

---

## Layer 2 — Shared caches (`.claude/cache/_shared/`)

Files:

```
_index.json
design-system-decisions.json
screen-refactor-playbook.json
ux-foundations-map.json
```

---

## Layer 3 — Project caches (`.claude/cache/_project/`)

Files:

```
_index.json
anti-patterns.json
architecture-patterns.json
```

---

## Read call sites identified

The cache is a **context-injection system**, not a programmatic API. Skills
read cache files as Claude conversational context (via Read tool calls during
skill execution), not via Python function calls. There is no `load_cache()` or
`read_cache()` function anywhere in the codebase — `grep -rn
"load_cache\|read_cache\|cache_load\|cache_read"` returns zero results.

The canonical read protocol is documented in every SKILL.md under
"Phase 1 (Cache Check)" and in `pm-workflow/SKILL.md` §"Cache Tracking
Protocol (v6.0)". All 11 skills follow the same pattern: read
`.claude/cache/{skill}/_index.json`, match task signature, load the relevant
JSON file's `compressed_view` field, then optionally check L2/L3.

The single programmatic touch-point that bridges agent context to the
measurement ledger is `scripts/append-feature-log.py --cache-hit`.

| Site (file:line) | Layer | Sync/Async | Currently logs cache_hit? |
|---|---|---|---|
| `.claude/skills/pm-workflow/SKILL.md:192` — "On Skill Load" protocol, Phase 1 Cache Check | L1/L2/L3 | Sync (agent reads files as context) | No — agent must remember to call `append-feature-log.py` |
| `.claude/skills/dev/SKILL.md:123` — Phase 1 Cache Check: reads `dev/_index.json` + L2 `screen-refactor-playbook.json` | L1 + L2 | Sync | No |
| `.claude/skills/ux/SKILL.md:399` — Phase 1 Cache Check: reads `ux/_index.json` + L2 `ux-foundations-map.json` | L1 + L2 | Sync | No |
| `.claude/skills/qa/SKILL.md:128` — Phase 1 Cache Check: reads `qa/_index.json` | L1 | Sync | No |
| `.claude/skills/design/SKILL.md:181` — Phase 1 Cache Check: reads `design/_index.json` + L2 `ux-foundations-map.json` + L2 `design-system-decisions.json` | L1 + L2 | Sync | No |
| `.claude/skills/analytics/SKILL.md:163` — Phase 1 Cache Check: reads `analytics/_index.json` | L1 | Sync | No |
| `.claude/skills/research/SKILL.md:182` — Phase 1 Cache Check: reads `research/_index.json`, L2 `_shared/` | L1 + L2 | Sync | No |
| `.claude/skills/cx/SKILL.md:193` — Phase 1 Cache Check: reads `cx/_index.json` | L1 | Sync | No |
| `.claude/skills/ops/SKILL.md:151` — Phase 1 Cache Check: reads `ops/_index.json` | L1 | Sync | No |
| `.claude/skills/marketing/SKILL.md:183` — Phase 1 Cache Check: reads `marketing/_index.json` | L1 | Sync | No |
| `.claude/skills/release/SKILL.md:139` — Phase 1 Cache Check: reads `release/_index.json` | L1 | Sync | No |
| `scripts/count-framework-tokens.sh:55-56` — token counting over `cache/**/*.json` | L1/L2/L3 | Sync (reporting only) | N/A — this is a metrics read, not a knowledge read |
| `integrity-check.py:258` — `load_pr_cache()` function loads cached `gh pr list` result | Internal PR resolution cache (not `.claude/cache/`) | Sync | N/A — unrelated to skill cache layer |
| `check-state-schema.py:81` — `_load_pr_cache()` function (same as above) | Internal PR resolution cache | Sync | N/A |

**Distinct read sites that represent cache-knowledge access (skills loading
patterns from `.claude/cache/`):** 11 (one per skill SKILL.md).

**Shared loader path analysis:** All 11 sites follow an identical Phase 1
protocol defined in `pm-workflow/SKILL.md §Cache Tracking Protocol` and
mirrored into every individual SKILL.md. The protocol already specifies that
on a cache hit, the agent SHOULD call `scripts/append-feature-log.py
--cache-hit`. The gap is that this call is voluntary — there is no automated
trigger, gate, or wrapper that fires it.

---

## Existing instrumentation (`append-feature-log.py`)

The `--cache-hit` flags on `scripts/append-feature-log.py` **exist but are
not wired to any automatic trigger at cache read time**.

Evidence from `grep -rn "append-feature-log.*cache-hit" .claude/ scripts/`:

- `settings.local.json:248` — test invocation confirming the plumbing works
  (meta-analysis-audit feature, event_type cache_hit, L1)
- `settings.local.json:249` — real production call for meta-analysis-audit
  (BROKEN_PR_CITATION gh pr list cache reuse, L1, exact hit)
- `settings.local.json:269` — data-integrity-framework-v7-6 implementation
  checkpoint (L1, adapted, pm-workflow skill)
- `settings.local.json:277-278` — data-integrity-framework-v7-6 code change
  (L2, adapted, v7.5 documentation-debt pattern)
- `settings.local.json:280` — data-integrity-framework-v7-6 code change
  (L2, adapted, GitHub Actions cron pattern)
- `settings.local.json:332` — unified-control-center implementation
  (L3, adapted, vercel-deployment-verification)
- `settings.local.json:343` — unified-control-center implementation
  (L3, adapted, gha-deployment-status-pattern)
- `settings.local.json:346` — unified-control-center implementation
  (L1, adapted, design:tailwind-token-mapping)
- `settings.local.json:359` — unified-control-center implementation
  (L2, adapted, vercel-env-setup-pattern)
- `settings.local.json:362` — unified-control-center implementation
  (L1, adapted, qa:tmp-dir-fs-fixture-pattern)

**Conclusion:** The `--cache-hit` plumbing has been used manually (10
confirmed call sites stored in settings.local.json as allow-listed Bash
commands). It is **not** invoked automatically during Phase 1 cache checks —
those are agent context reads with no programmatic hook. The call is emitted
by the agent after the fact when it remembers to. This is precisely the
voluntary-adoption gap that issue #140 and M1 aim to close.

---

## Instrumentation strategy decision

- **Distinct read sites identified:** 11 (one per skill, all following the
  same Phase 1 protocol defined in `pm-workflow/SKILL.md`)
- **Shared loader path exists:** Yes — every skill follows an identical
  Phase 1 cache-check protocol described in `pm-workflow/SKILL.md §Cache
  Tracking Protocol (v6.0)` and the superseding `§Contemporaneous Logging
  Protocol (v7.5)`. The v7.5 section already specifies the exact
  `append-feature-log.py --cache-hit` call that should fire on every hit.
- **Recommendation for T2:** **Extend `append-feature-log.py`** rather than
  writing a new helper. The script already accepts `--cache-hit`, `--cache-key`,
  `--cache-hit-type`, and `--cache-skill`. What is missing is a pre-commit or
  gate mechanism (T3) that enforces the call happened, plus potentially a
  simplified wrapper (T2 can create `scripts/log-cache-hit.py` as a
  thin convenience shim over `append-feature-log.py` if the call-site
  verbosity is a friction barrier). The underlying logger does not need
  duplication — it needs a T3 enforcement hook and potentially a T2 invocation
  simplification that reduces the argument count to remove the friction of
  forgetting.

---

## Kill-criterion-1 result

**PROCEED — 11 read sites exist but all share a single loader path.**

The 11 cache read sites are not 11 independent code paths — they are all
instances of the same Phase 1 protocol, described once in
`pm-workflow/SKILL.md` and mirrored into each skill's SKILL.md. Every site
already points to `append-feature-log.py --cache-hit` as the prescribed
logging action. T2 does not need to invent a new mechanism; it needs to make
the existing mechanism easier to invoke (reduce friction) and T3 needs to
enforce it wasn't skipped. The 11-site count is within the kill threshold
because a single shared protocol governs all of them — T2's helper can be
wired once into the pm-workflow/SKILL.md protocol documentation and it
propagates to all 11 sites.
