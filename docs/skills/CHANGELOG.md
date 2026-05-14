# Skills Changelog

> Append-only per-skill changelog for `.claude/skills/*/SKILL.md`. Closes P1.5 from [`docs/skills/skills-review-2026-05-13.md`](skills-review-2026-05-13.md). Bumped whenever a SKILL.md's `framework_version:` or `last_updated:` frontmatter changes, OR when a sub-command is added / removed / renamed.
>
> Format per skill: reverse-chronological dated entries. Entry per logical change. Cite PRs.

## Convention

Each entry follows:

```markdown
### YYYY-MM-DD — vX.Y.Z (PR #NNN)

- Change 1 (one line, declarative)
- Change 2
```

Versioning rules (P2.5):

- `framework_version:` — mirrors the host framework version at write time (currently `v7.8.5`)
- A `vMAJOR.MINOR` bump corresponds to: sub-command add/remove/rename, mode change (active ↔ stable ↔ planned ↔ deprecated), or significant body restructure
- `last_updated:` bumps on ANY change, including frontmatter-only edits

---

## `/pm-workflow`

### 2026-05-14 — v7.8.5 (PR #350 + #352)

- Added `/pm-workflow roadmap {review|prioritize|decide}` sub-cmd via Anthropic `references/` pattern (P1.0c). New file: `.claude/skills/pm-workflow/references/roadmap.md`.
- Phase 0 dispatch table extended: `/brainstorm-pm` is now the FIRST skill called for new-feature work (before `/research wide`).
- Added trigger-rich description (P0.0), `last_updated: 2026-05-14`, `framework_version: v7.8.5`, `status: active` frontmatter (P0.1, P0.5).
- Added observed-patterns preflight stanza tied to v7.8.5 catalog (P0.2 was previously present; reformatted).
- Added 5-bullet anti-patterns section (P1.0d).
- (P1.4) added `adapters_used: [ga4]` to frontmatter.

## `/ux`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5).
- Added observed-patterns stanza citing #6 + W7 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- (P1.4) added `adapters_used: [axe]`.

## `/design`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5).
- Added observed-patterns stanza citing #6 + #16 + W4 + W7 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- (P1.4) added `adapters_used: [axe]`.

## `/cx`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5) with `status: stable`.
- Added observed-patterns stanza citing #14 + #16 + #18 + W2 + W6 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- (P1.4) added `adapters_used: [app-store-connect, ga4, sentry]`.

## `/analytics`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5).
- Description now includes new `/analytics watch` sub-cmd (shipped in PR #345, predates this changelog but recorded here).
- Removed `mixpanel` ghost adapter ref (P0.3) — only `ga4` is wired.
- (P1.4) added `adapters_used: [ga4]`.

### 2026-05-13 — (PR #348)

- Added observed-patterns preflight stanza (predates the project-wide P0.2 sweep; first skill to adopt the convention).

## `/marketing`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5) with `status: stable`.
- Added observed-patterns stanza citing #14 + W2 + W8 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- Removed `ayrshare` ghost adapter ref (P0.3) — only `app-store-connect` + `firecrawl` are wired.
- (P1.4) added `adapters_used: [app-store-connect, firecrawl]`.

## `/ops`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5) with `status: stable`.
- Added observed-patterns stanza citing #11 + #12 + #23 + W3 + W5 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- Removed `datadog` ghost adapter ref (P0.3) — only `sentry` is wired.
- (P1.4) added `adapters_used: [security-audit, sentry]`.

## `/research`

### 2026-05-14 — v7.8.5 (PR #350 + this PR)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5).
- Added observed-patterns stanza citing #14 + W6 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- Removed `apify` ghost adapter ref (P0.3 + this PR's audit cleanup) — only `firecrawl` is wired.
- (P1.4) added `adapters_used: [firecrawl]`.

## `/release`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5) with `status: stable`.
- Added observed-patterns stanza citing #6 + #15 + W4 + W7 (P0.2).
- Added 5-bullet anti-patterns section (P1.0d).
- Removed `fastlane` ghost adapter ref (P0.3) — only `app-store-connect` is wired.
- (P1.4) added `adapters_used: [app-store-connect]`.

## `/qa`

### 2026-05-14 — v7.8.5 (PR #350)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5).
- Added observed-patterns stanza (P0.2 was already present via earlier work; reformatted).
- Added 5-bullet anti-patterns section (P1.0d).
- (P1.4) added `adapters_used: [axe, security-audit, sentry]`.

### 2026-05-13 — (predates project-wide v7.8.5 sweep)

- Observed-patterns preflight stanza added (one of three skills to predate the P0.2 sweep).

## `/dev`

### 2026-05-14 — v7.8.5 (PR #350 + #352)

- Trigger-rich description (P0.0); frontmatter (P0.1, P0.5).
- Added 5-bullet anti-patterns section (P1.0d).
- (P1.4) added `adapters_used: [security-audit]`.
- **PR #352**: added `/dev skills {audit|trace|freshness}` sub-cmd — skill-of-skills meta-checks (P1.1).

### 2026-05-13 — (predates project-wide v7.8.5 sweep)

- Observed-patterns preflight stanza added (one of three skills to predate the P0.2 sweep).

## `/brainstorm-pm` (NEW)

### 2026-05-14 — v7.8.5 (PR #350)

- **NEW skill** (P1.0b). Modeled on Anthropic's `product-brainstorming` from `anthropics/knowledge-work-plugins`.
- 4 modes: problem / solution / assumption / strategy.
- 4 frameworks: HMW / JTBD / First Principles / OST.
- Wired into pm-workflow Phase 0 as the default new-feature entry point.
- Output contract: writes to `state.json::brainstorm.<mode>` which becomes input to Phase 1 PRD sections.
- (P1.4) `adapters_used: []` (no external adapters).

---

## Integration adapter changelog

Tracks frontmatter changes to `.claude/integrations/{adapter}/adapter.md`. Same convention as skills.

### 2026-05-14 — all 6 adapters (this PR)

Added P1.4 frontmatter (`name`, `type`, `consumed_by`, `last_updated`) to:

- `app-store-connect` — `consumed_by: [cx, release, marketing]`
- `axe` — `consumed_by: [ux, qa, design]`
- `firecrawl` — `consumed_by: [research, marketing]`
- `ga4` — `consumed_by: [analytics, pm-workflow, cx]`
- `security-audit` — `consumed_by: [dev, ops, qa]`
- `sentry` — `consumed_by: [ops, cx, qa]`

Bidirectional integrity (each `consumed_by` entry matches the corresponding skill's `adapters_used`) is verifiable by hand today; a follow-up PR will add a `W5` check to `scripts/skills-audit.py` once PR #350 + #352 land (to avoid merge conflicts).
