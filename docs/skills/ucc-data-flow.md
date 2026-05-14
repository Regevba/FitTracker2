# UCC ↔ skills data-flow contract

> Closes P1.6 from [`docs/skills/skills-review-2026-05-13.md`](skills-review-2026-05-13.md). Documents the existing data flow between skills and the Operations Control Room (UCC), confirms which files act as the integration contract, and surfaces what is NOT wired (gaps left for P1.2).

## Context

The UCC (`fitme-story.vercel.app/control-room/*`) is the operator dashboard that surfaces framework gates, integrity cycle snapshots, measurement-adoption ledgers, and the case-study feed. It is built at deploy time from data files in this repo.

The plan recommended cross-linking `/cx digest` + `/analytics report` to UCC. **This document confirms that the cross-link already works** via shared-layer JSON files and the fitme-story pre-build sync — no code change required. The deliverable here is the explicit contract so future drift can be detected.

## Architecture

```
                 FitTracker2 (FT2 repo)                      fitme-story (UCC)
┌──────────────────────────────────────────────┐    ┌─────────────────────────────┐
│                                              │    │                             │
│   /cx digest        →   cx-signals.json   ─────→     scripts/sync-from-       │
│                                              │      fittracker2.ts (pre-      │
│   /analytics report →   metric-status.json─────→     build sync, hourly +     │
│                                              │      on-push)                   │
│   /ops health       →   health-status.json─────→                              │
│                         framework-health.json│      → src/data/* mirror       │
│                                              │      → src/lib/control-room/   │
│   (all under .claude/shared/)                │        renders pages           │
│                                              │      → /control-room/*         │
└──────────────────────────────────────────────┘    └─────────────────────────────┘
```

## Sync mechanism

- **Source-of-truth files** all live in `.claude/shared/*.json` in FitTracker2.
- The fitme-story `scripts/sync-from-fittracker2.ts` is the **pre-build sync** that mirrors every `.claude/shared/*.json` + every `.claude/features/*/state.json` + the canonical doc tree into fitme-story's `src/data/` tree.
- The UCC pages (under `fitme-story/src/app/control-room/*` and `fitme-story/src/lib/control-room/*`) read the synced copies at render time, not the live FT2 repo.
- Sync triggers: hourly cron + push to main + manual `npm run sync:ft2` invocation.

## The contract per shared file

### `cx-signals.json` (owned by `/cx`)

**Writer:** `/cx` sub-commands. Specifically:

- `/cx reviews` → `reviews.{avg_rating, count, sentiment.*, word_analysis.*}`
- `/cx nps` → `nps.{score, last_survey, trend}`
- `/cx sentiment` → `reviews.sentiment.*` + `reviews.word_analysis.*`
- `/cx analyze` → `confusion_signals[]` + `post_deployment.{feature_name}`
- `/cx digest` → `post_deployment.{feature_name}` summary

**Schema (current — see [`.claude/shared/cx-signals.json`](../../.claude/shared/cx-signals.json) for the canonical):**

```jsonc
{
  "version": "1.0",
  "updated": "YYYY-MM-DD",
  "nps": { "score": null|number, "last_survey": null|"YYYY-MM-DD", "trend": [] },
  "reviews": {
    "avg_rating": null|number,
    "count": number,
    "sentiment": { "positive": [], "negative": [], "neutral": [] },
    "word_analysis": { /* keyword frequency by category */ }
  },
  "feature_requests": [],
  "confusion_signals": [],
  "post_deployment": { /* per-feature digest summaries */ }
}
```

**UCC consumer:** any panel/route that surfaces "what users say" — currently fed through the sync mechanism into `fitme-story/src/data/cx-signals.json`. Pages that may render this: `/control-room/cx` (planned), `/control-room/framework` (consumes `health-status.json`, not this file).

**Contract:** `/cx` skills MUST preserve the top-level structure; new sub-fields are additive only. Renaming a top-level key requires a fitme-story PR to update the sync target shape.

### `metric-status.json` (owned by `/analytics`)

**Writer:** `/analytics` sub-commands. Specifically:

- `/analytics validate` → updates `instrumented` boolean per metric
- `/analytics report` → populates `current` values from GA4
- `/analytics dashboard` + `/analytics funnel` → may add metrics or annotations

**Schema (current — see [`.claude/shared/metric-status.json`](../../.claude/shared/metric-status.json)):**

```jsonc
{
  "version": "1.0",
  "updated": "YYYY-MM-DD",
  "categories": {
    "product_engagement": [
      { "name": "DAU", "target": null|string, "current": null|number,
        "instrumented": boolean, "source": "GA4|Firebase|..." }
    ],
    "health_fitness": [ /* ... */ ],
    "ai_intelligence": [ /* ... */ ],
    "technical_health": [ /* ... */ ],
    "business_growth": [ /* ... */ ],
    "customer_experience": [ /* ... */ ]
  }
}
```

**UCC consumer:** the framework-health page (`/control-room/framework`) cross-references this for instrumentation-adoption percentages. Direct rendering via the sync mechanism.

**Contract:** `/analytics` skills MUST preserve the six category names. New metric entries within a category are additive. Renaming a category requires a fitme-story PR.

### `health-status.json` + `framework-health.json` (owned by `/ops`)

Already documented in [`docs/skills/ops.md`](ops.md). Same sync pattern: writes flow via the pre-build sync to fitme-story's `src/data/` tree.

## What IS wired today

| Source | File | UCC route | Verified |
|---|---|---|---|
| `/cx` | `.claude/shared/cx-signals.json` | mirror in `fitme-story/src/data/cx-signals.json` | ✅ structure exists, schema confirmed |
| `/analytics` | `.claude/shared/metric-status.json` | mirror in `fitme-story/src/data/metric-status.json` | ✅ structure exists, schema confirmed |
| `/ops` | `.claude/shared/health-status.json` + `framework-health.json` | `/control-room/framework` | ✅ live; per `framework-v7-7-validity-closure` showcase |

The sync is one-way (FT2 → fitme-story). Any change a `/cx` or `/analytics` skill makes lands in the UCC on the next build.

## What is NOT wired today (P1.2 scope)

The plan called for a separate **UCC "Skills Activity" panel** that aggregates per-skill metrics:

- Last invocation per skill
- Last `last_updated:` bump per SKILL.md
- Cross-skill dispatch counts
- Adapter-usage matrix (consumed_by ↔ adapters_used) — newly possible after this PR
- Audit findings count + severity (from `make skills-audit` output)

That's a new fitme-story page (`fitme-story/src/app/control-room/skills/page.tsx`) — out of scope for this PR; tracked as P1.2 in the skills-review queue.

The data sources for that panel ALREADY EXIST:

- Per-skill `last_updated:` is in every SKILL.md frontmatter (P0.1 — shipped in PR #350)
- Per-skill `status:` is in every SKILL.md frontmatter (P0.5 — shipped in PR #350)
- Per-skill `adapters_used:` is in every SKILL.md frontmatter (P1.4 — this PR)
- Per-adapter `consumed_by:` is in every adapter.md frontmatter (P1.4 — this PR)
- Audit findings are produced by `make skills-audit` (P0.4 — shipped in PR #350)
- Session-event ledger for trace data is `.claude/logs/_session-*.events.jsonl` (Mechanism C — shipped in v7.8)

So P1.2 is purely a fitme-story rendering task; no FT2 skill changes needed.

## Verification

To confirm the contract is intact:

```bash
# 1. Schema files exist with expected top-level keys
python3 -c 'import json; d=json.load(open(".claude/shared/cx-signals.json")); assert {"nps","reviews","feature_requests","confusion_signals","post_deployment"} <= d.keys(), "schema drift in cx-signals.json"'
python3 -c 'import json; d=json.load(open(".claude/shared/metric-status.json")); assert {"categories"} <= d.keys() and {"product_engagement","health_fitness","ai_intelligence","technical_health","business_growth","customer_experience"} <= d["categories"].keys(), "schema drift in metric-status.json"'

# 2. fitme-story pre-build sync includes both files
grep -q 'cx-signals.json\|metric-status.json' /Volumes/DevSSD/fitme-story/scripts/sync-from-fittracker2.ts  # expect a hit per file
```

If either schema check fails OR the sync target list is missing a file: that's a P1.6 regression; the contract has drifted and a follow-up PR is needed in both repos.

## Anti-patterns

- Do not write to `.claude/shared/cx-signals.json` from any skill other than `/cx` (ownership rule from [`docs/skills/architecture.md`](architecture.md))
- Do not write to `.claude/shared/metric-status.json` from any skill other than `/analytics`
- Do not change a top-level key shape without a coordinating fitme-story PR — the sync target schemas are part of the contract
- Do not skip the sync step when manually previewing UCC locally — stale `src/data/*.json` will mislead reviewers
