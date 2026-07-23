# Cross-Layer Item Naming Convention

> **Status:** active (established 2026-06-29, FIT-200 / `cross-layer-item-naming-convention`).
> **Why:** before this, the same logical item had different identifiers in every
> layer (feature slug ≠ `FIT-NNN` ≠ thematic code), thematic codes **collided**
> (two different "R14"s — dev-env SBOM vs integrity-check parallelization), and
> there was no mechanical join, so ~12 shipped items sat stale-open in Linear
> (2026-06-29 reconciliation). This convention gives every trackable item **one
> canonical key, one tracking key, and a namespaced label** that repeat
> identically across Linear, Notion, `docs/product/backlog.md`, the master plan,
> and every sub-plan.

---

## 1. The three identifiers (every item carries all three)

| Role | Identifier | Where it lives | Example |
|---|---|---|---|
| **Canonical key** (source of truth) | **feature slug** (kebab-case) | `.claude/features/<slug>/` directory name | `f4-framework-version-stale` |
| **Tracking key** (cross-tool) | **`FIT-NNN`** | `state.json.linear_id` ← → Linear issue id | `FIT-96` |
| **Thematic label** (grouping/sort) | **`SCHEME-CODE`** | `state.json.thematic_codes[]` + Linear/Notion/plan titles | `FW-F4` |

**Rule of precedence:** the **slug is canonical** (repo is source of truth per
CLAUDE.md). `FIT-NNN` is the pointer that makes repo ↔ Linear a *mechanical*
join. Thematic codes are labels for grouping and human reference — **never** the
primary key (that is what allowed the collisions).

A feature with no Linear issue yet still has a slug; a Linear issue with no
feature dir yet (pure backlog) still gets a slug **reserved** in its title so the
join is ready the moment work starts.

---

## 2. Scheme prefixes (kills the collision class)

Thematic codes are **always** prefixed by their scheme. Bare `F4` / `T14` / `R14`
are no longer valid identifiers anywhere.

| Prefix | Scheme | Source | Example codes |
|---|---|---|---|
| **`FW-`** | Framework infrastructure & gates | infra-master-plan F-candidates | `FW-F4`, `FW-F16`, `FW-F22` |
| **`TC-`** | Test coverage (Theme H) | test-coverage-master-plan | `TC-T14`, `TC-T3`, `TC-T1` |
| **`DE-`** | Dev-env upgrade plan | **Linear epic FIT-166** R1–R24 (FIT-167…FIT-190) | `DE-R14`, `DE-R18` |
| **`HADF-`** | HADF program | HADF plans (B14.x/B15.x/C16.x/Phase-3a) | `HADF-B15.22a`, `HADF-3A-T4` |
| **`AN-`** | Analytics-observability | analytics sub-plan (Phase 1.B.x) | `AN-1B.1`, `AN-1B.2` |
| **`PROD-`** | Product features (app/site) | product backlog | `PROD-app-store-assets` |
| **`SEC-`** | Security hardening | GitHub-security tiers | `SEC-tier-a` |
| **`AUDIT-`** | External audits | audit substrate | `AUDIT-hadf-2` |

> **The collision this fixes:** Linear's `R14` ("make integrity-check
> parallelization", `DE-R14`) vs the 2026-05-24 dev-env plan's `R14` ("SBOM
> workflow", shipped in `dev-env-r11-r13-r14-r17-r18-batch`). Under this scheme
> the SBOM item is **not** `DE-R14` — the 05-24 plan items are a *separate*
> shipped batch and keep their own historical labels; the live `DE-` scheme is
> the Linear R1–R24 plan only. New work never reuses a number across schemes.

### 2.1 The two R-series, explicitly (clarified 2026-07-23)

The `DE-` source line above previously read "2026-05-19 dev-env audit (R1–R24)",
which is **wrong and was itself a source of confusion** — the Linear series does
not follow the audit's numbering. They are two different recommendation sets that
both happen to run R1–R24, and they diverge from **R3 onward**:

| # | `DE-R##` — Linear FIT-166 series (**live scheme**) | `DEV-AUDIT-R##` — 2026-05-19 audit + 2026-05-24 plan (**historical, shipped**) |
|---|---|---|
| R3 | Hardware-attribute snapshot in daily checkpoint | 2nd SSH signing key (YubiKey) |
| R7 | Auto-rotate `gh-pr-cache.json` | SwiftLint via SPM plugin |
| R9 | Mechanism C session-ledger compaction | Coverage instrumentation (Slather / coverage.py) |
| R10 | Make `verify-local` idempotent | launchd → GitHub Actions cron migration |
| R14 | `make integrity-check` parallelization | SBOM generation (`syft`) |
| R15 | Pre-commit P95 latency profiling | Playwright smoke specs for fitme-story |
| R17 | Cross-repo state-sync health endpoint | commitlint |
| R18 | `state.json schema_version` + migrator | shellcheck |
| R21 | Containerized dev-env (Docker image) | iOS App Thinning report |
| R22 | Multi-machine encrypted state sync | OpenTelemetry iOS ↔ ai-engine |
| R24 | Telemetry ingest endpoint | Distributed-tracing-aware Sentry config |

**Rule:** an unqualified `R##` in *live* tracking means the Linear series
(`DE-R##`). When citing the audit/plan series, write **`DEV-AUDIT-R##`** — the
[`dev-env-master-plan`](../master-plan/dev-env-master-plan-2026-05-24.md) Tier
tables are that series, and its rows are historical records of shipped work, not
live `DE-` items. Do not renumber either series; qualify instead.

**Forward-only.** Existing shipped case studies / dated plans keep their bare
historical codes (point-in-time records). New rows + reconciled live rows use
prefixed codes.

---

## 3. Shared status vocabulary ("Done" means the same everywhere)

Every layer maps its native states onto this single enum. The repo
`state.json.current_phase` is the **authoritative status source**; Linear/Notion/
backlog mirror it.

| Unified status | `state.json.current_phase` | Linear status | Backlog / plan marker |
|---|---|---|---|
| **Done** | `complete` | Done | ✅ SHIPPED / DONE |
| **In Progress** | any non-terminal phase with a feature dir (`implementation`, `tasks_phase`, `ux`, `test`, `review`, `merge`, `docs`, …) | In Progress | 🟡 in flight |
| **Blocked** | non-terminal + `paused`/`blocked`/`isolation_opt_out` reason or external dependency | Blocked (or In Progress + note) | ⛔ blocked (reason) |
| **Planned** | feature dir exists at `research`/`prd`/`tasks` OR reserved slug, work not started | Backlog | 🗓️ planned / Now-Next-Later |
| **Backlog** | no feature dir yet (Linear-only) | Backlog | backlog row |
| **Won't-Do** | n/a (`case_study_type: no_case_study_required` + reason, or external block) | Canceled | 🚫 won't-do (reason) |

---

## 4. Title format (identical string in every layer)

```
[SCHEME-CODE] <short name> (<slug>)
```

- **Linear issue title:** `FW-F4 — framework_version auto-update (f4-framework-version-stale)`
- **Backlog / master-plan / sub-plan row:** same `[SCHEME-CODE] <name>` + cite the slug
- **Notion row:** same; link the Linear `FIT-NNN` and the slug

This means a single grep for the slug, the `FIT-NNN`, or the `SCHEME-CODE` finds
the item in **every** layer.

---

## 5. The crosswalk registry (the join table)

`make crosswalk` runs [`scripts/build-item-registry.py`](../../scripts/build-item-registry.py),
which reads every `.claude/features/<slug>/state.json` and emits
[`.claude/shared/item-registry.json`](../../.claude/shared/item-registry.json):

```json
{
  "schema_version": 1,
  "generated_note": "derived from .claude/features/*/state.json — do not hand-edit",
  "source_fingerprint": "sha256 over the canonicalized items list",
  "items": [
    {
      "slug": "f4-framework-version-stale",
      "linear_id": "FIT-96",
      "thematic_codes": ["FW-F4"],
      "status": "Done",
      "current_phase": "complete",
      "case_study": "...",
      "prs": [740]
    }
  ],
  "coverage": { "total": 132, "with_linear_id": 66, "missing_linear_id": 66 }
}
```

Notion, backlog, and the plans cite items **by slug + `FIT-NNN`**; the registry
is the authority that ties them together. Regenerate after any reconcile.

### 5.1 Freshness (W44, added 2026-07-23)

The registry is a **derived** index, and until 2026-07-23 its only producer was
a manual `make crosswalk` with no freshness signal in the file. It drifted to
**118 items against a 132-feature corpus** — missing the two in-flight features
outright — and nothing surfaced it, because a stale index looks exactly like a
fresh one. See observed pattern **W44**.

Two mechanisms close that:

- **`source_fingerprint`** — sha256 over the canonicalized `items` list. It is
  deliberately *not* a wall-clock `generated_at`: a timestamp would churn the
  file on every regeneration and still would not prove the content matches the
  corpus. The fingerprint makes regeneration **idempotent** (same corpus →
  byte-identical file) and makes staleness **exactly** decidable.
- **`make crosswalk CHECK=1`** — recomputes from the live corpus and compares.
  Prints a FRESH/STALE verdict (`--json` for machines) and exits **3** when
  stale, so callers can gate on it. A registry with no `source_fingerprint`
  (the pre-2026-07-23 format) is reported stale: it cannot prove otherwise.

The verdict is surfaced **daily** as advisory **N5** in
[`scripts/daily-integrity-checkpoint.py`](../../scripts/daily-integrity-checkpoint.py),
so the join table can no longer rot unnoticed between reconcile passes. The
advisory is fail-silent: any tooling error yields no output rather than a false
staleness claim.

---

## 6. Enforcement (advisory, forward-only)

- `state.json` gains two **optional** fields: `linear_id` (string `FIT-NNN`) and
  `thematic_codes` (array of `SCHEME-CODE` strings).
- `make crosswalk` prints an **advisory** list of features missing `linear_id`
  (the join gap). It **never blocks a commit** at introduction.
- Promotion path: once the backfill lands and the missing-join count is stable
  near zero, a `LINEAR_ID_MISSING` cycle-time advisory (then enforced gate) can
  be added through the standard 14-day calibration ladder. Not before.

---

## 7. Operating rules

1. **New item →** create the Linear issue with the `[SCHEME-CODE] name (slug)`
   title, reserve the slug, and (when work starts) write `linear_id` +
   `thematic_codes` into `state.json`.
2. **Reconcile →** run `make crosswalk`; for any Done feature, ensure its Linear
   issue + Notion row + backlog row read **Done**, and its `state.json` carries
   `linear_id`.
3. **Never reuse a bare number across schemes.** Always prefix.
4. **Repo wins.** If Linear/Notion/backlog disagree with `state.json`, the
   repo is right; fix the mirror (this is the 2026-06-29 stale-open lesson).
