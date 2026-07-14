---
name: release
description: "Use when preparing a TestFlight or App Store release, drafting a pre-release checklist, generating release notes from the changelog, or submitting a build to App Store Connect. Verifies CI gates green (build + test + tokens-check + ui-audit P0=0) before promoting any build. Sub-commands: /release prepare, /release checklist, /release notes, /release submit."
last_updated: 2026-05-15
framework_version: v7.8.6
status: stable
adapters_used: [app-store-connect]
---

# Release Management Skill: $ARGUMENTS

You are the Release Management specialist for FitMe. You handle version bumps, changelog generation, release readiness checks, TestFlight distribution, and App Store submission preparation.

## Observed patterns preflight

<!-- BEGIN pattern-preflight (generated) -->
The [pattern↔skill map](../../shared/pattern-skill-map.json) tracks **67 work-blocking patterns** (25 gate-firing patterns + 42 workflow patterns) drawn from the [Observed Patterns Catalog](../../integrity/observed-patterns.md) (`make observed-patterns`). The patterns below are the ones mapped to `/release` work — probe the mechanized ones, checklist the rest:

| ID | Pattern | Blocker | Remediation |
|---|---|---|---|
| `W4` | No auto-merge without explicit approval | yes | Never auto-merge; surface PR + checks and wait for explicit approval. |
| `W15` | MDX `<digit` / `<non-letter` breaks page rendering | yes | Escape/avoid `<digit` in MDX (use 'under 5 min', &lt;, or a code-span) to keep prerender green. |
| `W18` | Default-URL OG image silent-404 | no | Point the default OG image URL at the Next.js convention route; unit-test that the URL resolves. |
| `W19` | Env-var trailing newline corrupts runtime string | no | Trim string env vars at the boundary (process.env.X?.trim()) to strip trailing newlines. |
| `W26` | Two workflows sharing name: clash in github.workflow concurrency groups *(probed)* | no | Give each workflow a hardcoded concurrency-group prefix, not ${{ github.workflow }}, when names collide. |
| `W28` | Local xcodebuild blocked by CoreSimulator out-of-date (Mac restart required) | no | Local xcodebuild CoreSimulator-out-of-date needs a Mac restart; fall back to swiftc -parse + CI. |
| `W41` | Runner git commit is unsigned -> required_signatures rejects it; GraphQL createCommitOnBranch auto-signs (signature half of W37) *(probed)* | no | When a workflow-authored commit must land on a branch with required_signatures=true, a runner `git commit`/`git push` is unsigned and rejected (a PAT fixes W37's check-trigger half but NOT the signature). Create the commit via the GitHub GraphQL createCommitOnBranch mutation instead -> GitHub auto-signs with its web-flow key, satisfying required_signatures. scripts/create-signed-snapshot-pr.py does this (reads staged diff, resolves base OID, signed commit, opens PR, squash auto-merge) driven by WORKFLOW_PR_TOKEN so required checks also run. See observed-patterns.md W41 (companion to W37). |

At activation run `make skill-preflight SKILL=release` — probes the 2 mechanized blockers for this work type; clear any before proceeding.

**Mandatory** (CLAUDE.md §v7.8.5): any novel pattern surfaced this session MUST be appended to [`observed-patterns.md`](../../integrity/observed-patterns.md) before the feature closes — then re-run `make gen-skill-preflight`.
<!-- END pattern-preflight -->

## Shared Data

**Preflight cache:** `.claude/shared/preflight-cache.json` — refreshed by `make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]`. Run BEFORE any sub-command to get current work-context data (W1 ssh-agent, integrity findings, drift vs anchor, doc-debt, adoption baseline). Cache schema: `docs/skills/preflight-cache-schema.md`.

**Reads:** `.claude/shared/feature-registry.json` (what's included in release), `.claude/shared/test-coverage.json` (quality gate status), `.claude/shared/health-status.json` (CI + infrastructure ready)

**Produces:** `CHANGELOG.md` updates, version bump in Xcode project, App Store submission materials

## Sub-commands

### `/release prepare`

Prepare a new release.

1. **Determine version bump:**
   - Read current version from Xcode project (`FitTracker.xcodeproj`)
   - Read `.claude/shared/feature-registry.json` for features merged since last release
   - Apply semantic versioning:
     - Major: breaking changes, major UI redesign
     - Minor: new features
     - Patch: bug fixes, performance improvements
2. **Bump version:**
   - Update `MARKETING_VERSION` in Xcode project
   - Increment `CURRENT_PROJECT_VERSION` (build number)
3. **Generate release notes** from merged features (see `/release notes`)
4. **Tag release:** `git tag v{version}`

### `/release checklist`

Pre-release readiness checklist.

Run every check and report pass/fail:

| Check | Status | Details |
|-------|--------|---------|
| CI green (main) | | Latest workflow run |
| All tests passing | | XCTest suite |
| Token pipeline synced | | `make tokens-check` |
| No critical bugs | | Open issues with `bug` + `priority:critical` labels |
| Analytics regression passed | | All events firing on main |
| Performance acceptable | | Cold start <2s |
| No PII exposure | | Scan for sensitive data in logs/analytics |
| ASO listing updated | | App Store metadata ready |
| Screenshots current | | Reflect new features |
| Release notes written | | CHANGELOG.md updated |
| Feature registry updated | | All shipped features marked complete |

**All checks must pass before proceeding to submission.**

### `/release notes`

Generate changelog entry from merged features.

1. Read git log since last release tag: `git log v{last}..HEAD --oneline`
2. Read `.claude/shared/feature-registry.json` for feature descriptions
3. Categorize commits:
   - **New:** new features
   - **Improved:** enhancements to existing features
   - **Fixed:** bug fixes
   - **Internal:** refactoring, CI, tooling (don't include in user-facing notes)
4. Generate two versions:
   - **CHANGELOG.md entry** (developer-facing, detailed)
   - **App Store release notes** (user-facing, benefit-focused, concise)

### `/release submit`

App Store submission checklist.

1. **Build:**
   - Archive build for distribution
   - Validate with App Store Connect (no issues)
2. **Metadata:**
   - Description (read from `/marketing aso` output or draft)
   - Keywords
   - Screenshots (all required sizes)
   - Preview video (if applicable)
   - Privacy nutrition labels (accurate for current data usage)
   - App Review notes (test account, special instructions)
3. **TestFlight (optional):**
   - Upload to TestFlight
   - Internal testing group configuration
   - External testing group (if applicable)
   - Beta App Review submission
4. **Production submission:**
   - Select build
   - Confirm metadata
   - Submit for App Review
   - Set release mode: manual or automatic after approval

## Key References

- `FitTracker.xcodeproj` — Xcode project (version numbers)
- `CHANGELOG.md` — release history
- `.github/workflows/ci.yml` — CI pipeline
- `.claude/shared/feature-registry.json` — feature tracking

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| app-store-connect | MCP | App versions, TestFlight builds, submission status, build processing |

**Adapter location:** `.claude/integrations/app-store-connect/`
**Shared layer writes:** `feature-registry.json`

### Validation Gate

All incoming release data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /release + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /release + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for a release task, research:

1. **Version strategy** — current version, what's changed since last release, semantic versioning rules
2. **Release checklist** — CI gates, feature flag status, migration requirements, breaking changes
3. **App Store requirements** — current review guidelines, metadata requirements, screenshot specs
4. **Tools & APIs** — App Store Connect submission API, Fastlane lane configurations, TestFlight distribution
5. **Rollback planning** — phased rollout percentage, crash monitoring thresholds, rollback triggers

Sources checked in order: L1 cache → shared layer (feature-registry.json, health-status.json) → integration adapters (app-store-connect) → codebase (CHANGELOG.md, xcodeproj) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/release/_index.json`. Check for cached release checklists, version bump patterns, TestFlight distribution lists from prior releases.

**Phase 4 (Learn):** Extract new patterns (release timing, submission gotchas, review turnaround). Write/update L1 cache.

**Cache location:** `.claude/cache/release/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
1. Read `.claude/cache/release/_index.json` for L1 entries
2. Match current task against `task_signature.type`
3. Check L2 `.claude/cache/_shared/` for cross-skill patterns
4. If hit: load `learned_patterns`, `anti_patterns`, `speedup_instructions`
5. Apply loaded patterns — skip derivation steps covered by cache
6. If miss: proceed to Phase 2 (Research)

### Phase 4 — Learn (on skill complete)
1. Extract new patterns and anti-patterns from this execution
2. Write or update L1 cache entry in `.claude/cache/release/`
3. If pattern overlaps with an existing L2 entry, increment `hit_count`
4. If a new pattern applies to 2+ skills, flag for L2 promotion

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| app-store-connect | `.claude/integrations/app-store-connect/` | feature-registry.json | On `/release checklist` or `/release submit` |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. Version history and changelog patterns
2. Submission requirements and guidelines
3. TestFlight feedback from prior builds
4. Regression checklist from change-log.json
5. Store metadata and screenshot status

**Source priority:** L2 cache > L1 cache > shared layer (feature-registry.json) > app-store-connect adapter


## Anti-patterns

Hard-won mistakes for `/release` work. Every bullet encodes a real or near-miss failure mode.

- Do not promote a build to TestFlight without `make verify-local` passing end-to-end (tokens-check + schema-check + ui-audit + build + test) — every leg gates
- Do not include `partial_ship` features in release notes without resolving the decision fork first (pattern #15 `PARTIAL_SHIP_TERMINAL`)
- Do not skip the release checklist — every TestFlight push and every App Store submit is multi-part approval (pattern W7)
- Do not edit a release note after submission without recording the change in `CHANGELOG.md` and noting the version it correlates to
- Do not bump a major version without parallel notification to `/marketing` — launch comms prep needs a 1-week lead time minimum
