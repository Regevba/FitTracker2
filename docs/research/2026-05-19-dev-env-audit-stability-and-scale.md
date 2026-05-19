# Dev Env Audit — Stability & Scale Plan

**Date:** 2026-05-19
**Author:** generated via Claude Code research/plan session (operator: Regev)
**Scope:** the development environment for [FitTracker2](/Volumes/DevSSD/FitTracker2) (iOS Swift + ai-engine Python + dashboard Astro + website Astro) and [fitme-story](/Volumes/DevSSD/fitme-story) (Next.js 16 web + control room), plus the v7.8.6 framework substrate, multi-agent harness, and supporting CI/observability infra.
**Method:** thorough Explore-agent inventory of disk reality + read of canonical infra plans + comparison against industry standards for the equivalent stack at production scale.
**Audience:** the project operator deciding what to add, replace, or harden over the next 30/60/90 days.
**Out of scope:** product roadmap (covered in [`docs/master-plan/master-backlog-roadmap.md`](../master-plan/master-backlog-roadmap.md)), framework v8.x F-candidate ranking (covered in [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §3).

---

## 0. TL;DR — top 12 actions ranked by stability-per-effort

Each row is independently shippable. None of them touch the v7.9 calibration window (2026-05-15 → 2026-05-21) where `gate-coverage.jsonl` is frozen — every dev-env change is in `scripts/*`, `.githooks/*`, or repo-root config which lives behind the v7.8.1 infra-path globs and would fire `BRANCH_ISOLATION_VIOLATION` Mode B if shipped before 2026-05-21 promotion decision lands. **Earliest target ship window: 2026-05-22.**

| # | Action | Tier | Effort | Stability impact | Why now |
|---|--------|------|--------|------------------|---------|
| 1 | Pin language versions via `.tool-versions` (mise) — Node 24.14.0 + Python 3.12 + Swift 5.0 | 1 | 30 min | Eliminates "works on my Mac" drift; daily-checkpoint cron survives Homebrew bumps | 0 tooling pins exist on disk today |
| 2 | Rotate/prune daily-checkpoint snapshots → keep last 30d + monthly anchors | 1 | 1 h | Internal disk at 83% capacity (170 GB / 228 GB) — backup pipeline silently fails when disk fills | Already inside 14d of risk |
| 3 | Add a 2nd SSH signing key (YubiKey) — registered to GitHub + Git config | 1 | 30 min | Single-key loss = can't commit, can't push, can't sign. SSH-agent feedback rule presupposes ≥1 working key | Same pattern as UCC Part 7 break-glass — operator instinct already aligned |
| 4 | Clean up MEMORY.md to under 24.4KB index limit (currently 44.5KB — system truncates) | 1 | 1 h | Memory entries silently get dropped on read; current state of MEMORY.md is unreliable for cross-session continuity | Daily |
| 5 | Add `.editorconfig` + `.vscode/{settings,extensions}.json` shared across both repos | 2 | 1 h | Trivial cost; standardizes formatting + suggests right extensions to future contributors / agents | Compounding over time |
| 6 | Configure SwiftLint via SPM plugin + `.swiftlint.yml` | 2 | 2 h | 74 test files + ~250 source files have zero lint coverage; PR review currently catches style drift manually | Compounds with `ui-audit` |
| 7 | Configure ruff for ai-engine + scripts/ (single `pyproject.toml` rule set) | 2 | 1 h | 75+ Python scripts in `scripts/` have zero lint; bugs slip in (recent example: `framework-routines` index 2026-05-15) | Same |
| 8 | Add coverage instrumentation: Slather (iOS) + c8 (TS) + coverage.py (Python) — reporting only, no threshold yet | 2 | 3 h | F14/F15 require coverage data; baseline now means v8.x ranking has real numbers, not gut feel | Feeds C1 (2026-05-22) |
| 9 | Migrate daily-checkpoint cron from launchd → GitHub Actions OR Vercel Cron | 2 | 3 h | Removes macOS lock-in + the W1 ssh-agent / W11 cwd-binding failure modes that crash local cron | Self-healing |
| 10 | Add `gitleaks` pre-commit + GitHub Action — secret scanning | 2 | 1 h | Zero secret-scanning today. With 8 MCP integrations + GA4 + Supabase + Figma tokens + UCC env vars, exposure surface is wide | Pre-launch hygiene |
| 11 | Add `markdownlint-cli2` to `verify-local` — docs are case studies are spec are gate inputs in this project | 2 | 1 h | Case-study frontmatter gates already exist (CASE_STUDY_MISSING_FIELDS); markdown body has zero linting; broken links / missing alt-text / heading-skips ship | Compounds with audit substrate |
| 12 | Enable GitHub branch protection on `main` for both repos — require `pr-integrity-check` + `Build and Test` to pass | 1 | 15 min | The strongest gate the framework already enforces (`pr-integrity-check`) is bypassable today because no GitHub-level rule requires it. Per-PR review bot exists but is opt-in | Free safety upgrade |

The full plan is in §6–§9. Items #2, #3, #4, and #12 are calendar-independent (no v7.9 calibration risk) and can ship today.

---

## 1. Project parameters that shape every recommendation

Before any "industry best practice" applies, frame the constraints that make this project unique:

| Parameter | Value (2026-05-19) | Why it matters for dev env |
|---|---|---|
| Operator count | 1 human + ≥2 concurrent Claude agents | Single point of failure on SSH key, secrets, local state. Concurrent agents need branch isolation already enforced by v7.8.1. |
| Repos | 2 (FT2 canonical + fitme-story public-site / control room) | Cross-repo sync via `scripts/sync-from-fittracker2.ts`; v7.8.3 D-1 reverse-sync GHA. Recommendations must work in both. |
| Languages | Swift 5.0 + TS 5.x + Python 3.12 + Astro 5 | 4 toolchains = 4 lint stacks + 4 test stacks + 4 dep-update streams. |
| Feature count | 62 features tracked via `state.json` | State proliferation; backup growth O(n) in features. |
| Gate count | 34 mechanical + 5 advisory | Pre-commit overhead grows linearly; F16 try-repo harness is needed to prove gates work. |
| External audit cadence | 4 audits/year + 4 freshness audits | Reproducible bundles required — implemented via `scripts/audit/build_bundle.py` (PR #405 OPEN). |
| Storage | 1 SSD (SanDisk, hardware-unreliable; X10 Pro inbound) | Migration prep refreshed today; backup-disk has 36 GB free. |
| OS | macOS Darwin 25.5.0 | launchd, not systemd. App Sandbox available but unused. |
| App targets | iOS 17.0+ minimum | Xcode-driven, no headless build cluster. |
| Calendar | v7.9 promotion 2026-05-21; ext-audit #1 2026-05-22; HADF Sub-exp 1 2026-05-23; UCC Part 8 2026-05-28+ | Migration AND dev-env changes must NOT contaminate the 2026-05-15 → 2026-05-21 calibration window. |
| Scale ceiling target | TestFlight beta → App Store launch within Q3 2026 (inferred from app-store-assets feature `phase=implementation`) | Need: Crash-free 99.5%, cold-start <2s, Sentry, GA4, on-call surface. Mostly there; gaps below. |
| Operating mode | "school project" framing per user memory, but full PM discipline + production stack | Don't recommend enterprise overkill (SOC 2 controls, EKS, Datadog); DO recommend solo-friendly tools that scale 10×. |

**The asymmetric load on dev-env hygiene comes from the FRAMEWORK SUBSTRATE, not the app.** A 4-line typo in a `scripts/*.py` file silently breaks Mechanism A on 9 gates for 6 days (the v7.8.4 PR_CACHE_STALE incident; per `infra-master-plan-2026-05-12.md` §2.4). The dev env exists to keep the framework's measurement honest. Every recommendation is filtered through "does this make the framework harder to break silently."

---

## 2. Current state — what's actually on disk

Detailed inventory at the end of this doc (§Appendix A). The 18-dimension scan found:

**Strong:**

- **Data integrity framework** — 34 mechanical write-time + cycle-time gates; `gate-coverage.jsonl` Mechanism A telemetry; weekly drift scan; daily checkpoint with SSD-sibling backup. **Best-in-class for an SDLC of this size.**
- **CI workflows** — 9 in FT2 + 6 in fitme-story; per-PR integrity check; per-tag audit bundle; weekly framework status, dependency audit, framework drift, figma drift. **Mature.**
- **Pre-commit hooks** — `.githooks/pre-commit` enforces every gate the cycle-time scan checks; self-audits its own header (Mechanism D). **Self-healing.**
- **Multi-agent harness** — `.claude/settings.json` with SessionStart + PostToolUse hooks; 11 skills with auto-conformance audit; Mechanism C session attribution.
- **MCP integrations** — Figma + Supabase + Linear + Notion + Vercel + GA4 + Gmail + Calendar + Drive + Hugging Face + PubMed connected.
- **Cross-repo sync** — `sync-from-fittracker2.ts` runs at prebuild; reverse-sync GHA carries audit logs back.

**Weak / absent:**

| Gap | What's missing | Industry standard for this stack |
|---|---|---|
| Language version pinning | No `.tool-versions`, `.nvmrc`, `.python-version`, `.swift-version` | mise / asdf / nvm + pyenv |
| Linting (Swift) | No `.swiftlint.yml` | SwiftLint via SPM plugin |
| Linting (Python) | No ruff/black config | ruff in `pyproject.toml` |
| Linting (Markdown) | No `.markdownlint*` | markdownlint-cli2 |
| Type checking (Python) | No mypy/pyright config | mypy strict for ai-engine; pyright for scripts/ |
| Editor config | No `.editorconfig`, no `.vscode/settings.json`, no `.vscode/extensions.json` shared | Standard at any team size ≥1 |
| Coverage thresholds | Test runs but no `xccov`, `c8`, or `coverage.py` config | Slather + c8 + coverage.py with codecov.io OR self-hosted readout |
| Secret scanning | None | gitleaks pre-commit + GitHub secret scanning |
| Dependency auto-update | Partially via Dependabot (active per recent #406/#407 PRs) but no documented config file | Renovate OR Dependabot config in repo |
| Containerization | No Dockerfile, devcontainer, or sandbox | devcontainer for ai-engine reproducibility |
| Branch protection | Not visible via `gh api` from this session — likely OFF on main for both repos | Required status checks: pr-integrity + Build/Test |
| SBOM / supply-chain | None | syft generate SBOM; grype scan for CVEs |
| Performance budget | None codified | Lighthouse-CI for fitme-story; Xcode App Thinning report for iOS |
| Distributed tracing | Sentry-only error tracking; no spans across iOS ↔ FastAPI ↔ DB | OpenTelemetry → Sentry/Tempo when needed |
| Storybook / DS playground | None for fitme-story; design-system browsing happens in Figma library | Storybook (or Ladle) — useful for /design build review |

**Discoverable from the project's own ledgers (not "missing best practice"):**

- The **F-candidate docket** (`infra-master-plan` §3.1) already names test-discipline gaps F14–F18 + per-gate dispatch test requirement. Several of my recommendations dovetail with that work (#8 coverage instrumentation, #11 markdown lint, #6 SwiftLint enable F14-style enforcement).
- The **must-have-cadence-followups** ledger names C2 (web PR test gate, RICE 200) and C3 (Sentry reachability test, RICE 80) as the two highest-leverage UNSHIPPED test items. Both are in scope for the post-v7.9 window.
- The **2026-05-14 data-integrity-and-rollback master plan** §3.2 calls for explicit rollback rehearsal — my #2 (snapshot rotation) and #9 (cron migration) close two failure modes that the plan flags.

---

## 3. Comparison axis 1: industry standard for this stack at solo + AI-augmented scale

This is the "what would a senior engineer ask why isn't this here" axis. Filter is: **single-operator-with-agents at production-iOS-launch scale**, not enterprise.

### 3.1 Code quality stack

| Concern | Today | Standard | Gap |
|---|---|---|---|
| Swift linting | none | SwiftLint via SPM build plugin + opt-in `.swiftlint.yml` (50–80 rules) | **Add**; pairs with `ui-audit` for design-system rules, lint catches general Swift idioms |
| TS linting | ESLint v9 via Next.js default | eslint-config-next + `@typescript-eslint/recommended` + ban-types | **Verify** the config + extend |
| TS formatting | None | Prettier with `.prettierrc.json` + `eslint-config-prettier` | **Add**; one-time bulk format then auto on save |
| Python linting | None | ruff (replaces flake8 + isort + pydocstyle + pyupgrade in one) | **Add** to ai-engine `pyproject.toml` + apply to `scripts/` |
| Python formatting | None | ruff format (replaces black) | **Add** with ruff above |
| Python typing | None enforced | mypy strict for ai-engine; pyright for scripts/ | **Add** mypy first (more mature for FastAPI), pyright later for scripts |
| Markdown linting | None | markdownlint-cli2 with `.markdownlint-cli2.jsonc` | **Add**; case studies are gate inputs — broken links break audits |
| YAML linting | None | yamllint OR actionlint for GH workflows (F12 candidate in v8.x docket already) | **Already on docket as F12** — bump priority |
| Shell linting | None | shellcheck on `.sh` scripts | **Add** to pre-commit (~5 .sh files in scripts/) |
| TOML linting | None | taplo for `pyproject.toml`, `Cargo.toml` if any | **Skip** unless TOML count grows |
| Commit message lint | None enforced (but consistent style observed) | commitlint with conventional-commits | **Add** — feeds case-study autogen |

### 3.2 Test stack

| Concern | Today | Standard | Gap |
|---|---|---|---|
| iOS unit | XCTest, 74 files, ~440 methods, no coverage report | Slather → codecov; threshold gates on PR | **Add Slather → report (no threshold yet)** |
| iOS UI | Intentionally thin (7 files, per CLAUDE.md "UI test coverage strategy") | Same; deferred until parallel-clone simulator hang fixed | **Keep** as-is per documented strategy |
| Web unit | tsx --test, 19 files | vitest OR tsx --test (already chosen) | **Keep**; add c8 for coverage |
| Web E2E | None | Playwright for golden-path coverage (sign-in, dashboard, framework page) | **Add 3 smoke specs** post-v7.9 |
| Python | pytest with asyncio_mode=auto | pytest + coverage.py | **Add coverage.py** |
| Snapshot tests | None | SwiftSnapshotTesting (iOS) + vitest snapshots (web) | **Defer** — overlaps with figma-drift / ui-audit |
| Mutation | None | mutmut / Stryker | **Already on docket as F18** |
| End-to-end gate harness | None | try-repo subprocess pattern | **Already on docket as F16** — fund |
| Performance | None | xcrun xctrace + Lighthouse CI | **Defer** until App Store soft-launch |
| A11y | None automated (manual via `make ui-audit` DS-A11Y-* rules) | iOS: XCUITest accessibility audit; web: axe-core | **Add axe-core to fitme-story Playwright specs** when those exist |

### 3.3 CI/CD

| Concern | Today | Standard | Gap |
|---|---|---|---|
| PR gate (FT2) | `ci.yml` + `pr-integrity-check.yml` | Same shape; status checks required by branch protection | **Add branch protection rule** (#12) |
| PR gate (fitme-story) | `integrity.yml` + `case-study-audit.yml`; **no JS tests run** | Add `npm test` step | **C2 in cadence-followups, RICE 200** |
| Periodic | weekly framework-status + dependency-audit + figma-drift; 72h integrity-cycle | Same | **Migrate daily-checkpoint to GHA** (#9) |
| Release tags | `audit-bundle-on-tag.yml` builds external audit bundle | Same | None |
| Notifications | None visible — failures land as GH issue creation | Slack/Discord webhook for cron failures | **Add Slack webhook** (or skip if low-volume) |
| CI runner OS | ubuntu-latest (mostly); macos-15 for Figma SPM | Pin to ubuntu-22.04 (or 24.04) for reproducibility | **Pin** runners in workflow YAML |
| Build cache | SPM cache + npm cache via per-repo `.build/` | Add `actions/cache` for ai-engine pip + Astro build | **Add** pip/Astro caches |
| Concurrency cancel | Not visible | `concurrency: { group: $-pr, cancel-in-progress: true }` | **Add** to all PR-gated workflows |

### 3.4 Local dev ergonomics

| Concern | Today | Standard | Gap |
|---|---|---|---|
| Version manager | None | mise (or asdf) with `.tool-versions` | **Add mise** + `.tool-versions` in BOTH repos |
| Editor config | None | `.editorconfig` (universal) + `.vscode/{settings,extensions}.json` (project-specific) | **Add** |
| Direnv | None | `.envrc` with `dotenv .env.local` + tool-versions activation | **Add** alongside `.tool-versions` |
| Git hooks bootstrap | `make install-hooks` exists | `make bootstrap` aggregating install-hooks + ensure-toolchain + env-check | **Add `make bootstrap`** (#2 in §6) |
| Pre-push hook | None | Run `make verify-local` before push to remote | **Add** opt-in `.githooks/pre-push` |
| Dev server reliability | iOS: Xcode; web: pnpm dev; ai-engine: uvicorn (per pyproject.toml) | Foreman / overmind to launch all 3 from one shell | **Skip** for now (rarely all 3 at once) |
| MCP server health | Inferred from session start — no readout | `claude /mcp status` (built-in) | **Add to SessionStart hook output** |

### 3.5 Observability & runtime

| Concern | Today | Standard | Gap |
|---|---|---|---|
| iOS crashes | Sentry (per integration path; not deeply verified) | Sentry SDK + dSYM upload in release lane | **Verify dSYM upload + add a synthetic-event test** (C3, RICE 80) |
| iOS analytics | Firebase Analytics + GA4 — fixed 2026-05-17 (plist target membership) | Same + Amplitude OR Mixpanel for funnel UX | **Hold**; current adapter pattern (FirebaseAnalyticsAdapter / MockAnalyticsAdapter / DebugSinkAdapter) is well-designed |
| Web errors | None visible — no `@sentry/nextjs` in fitme-story package.json | Sentry Next.js wrapper | **Add** post-v7.9 |
| Web analytics | GA4 via `@next/third-parties` + Vercel Speed Insights | Same | None |
| Logs | Vercel logs (web); console (iOS dev); FastAPI logs (ai-engine, when deployed) | Same; aggregate via Logflare / Better Stack | **Skip** until ai-engine deploys |
| Distributed tracing | None | OpenTelemetry → Sentry / Tempo | **Defer** — only useful once ai-engine in prod |
| Status page | None | Better Stack / Instatus / hand-rolled with `/control-room/health` | **Already partial** via /control-room/framework — extend post-v7.9 |
| On-call rotation | N/A (single operator) | PagerDuty / OpsGenie | **Skip** — overkill for solo |

### 3.6 Security

| Concern | Today | Standard | Gap |
|---|---|---|---|
| Secret in repo scan | None | gitleaks pre-commit + GH secret scanning | **Add** (#10) |
| Dependency CVE | Weekly `npm audit` via cron | Add Snyk-free OR `pip-audit` for Python | **Add `pip-audit`** to ai-engine CI |
| SBOM | None | syft generate at release | **Defer** |
| Signed commits | SSH signing active | Same | None |
| 2FA on GitHub | Assumed yes (passkey on UCC = Regev is comfortable with WebAuthn) | Required + recovery codes archived offline | **Verify + archive** (5 min) |
| API key rotation | Manual | Set calendar reminders for 90d rotation on Figma + GA4 SA + Vercel Blob | **Add to cadence-followups** as `Q-1`/`Q-2`/`Q-3` |

### 3.7 Backup & recovery

| Concern | Today | Standard | Gap |
|---|---|---|---|
| Daily snapshot | `daily-integrity-checkpoint.py` → SSD + internal disk | Same + cloud (B2 / R2 / S3 with lifecycle) | **Add cloud tier** post-X10 swap |
| Git bundles | Per-migration manifest (2026-05-13 + 2026-05-19) | Recurring weekly `git bundle --all` → cloud | **Add weekly bundle to dependency-audit cron** |
| Disk health | None automated | smartmontools `smartctl --health` weekly | **Add** to dependency-audit cron |
| Disaster drill | Migration manifest covers this | Rehearse on Crucial X10 once it arrives | **Document outcome** as case study |

---

## 4. Comparison axis 2: what the project's own substrate says it needs

The infra master plan + cadence-followups already enumerate ~30 substrate-level gaps. My job here is to not duplicate them — to identify which dev-env additions accelerate the items already on the docket. The map is:

| My recommendation # | Unlocks / accelerates | From which roadmap doc |
|---|---|---|
| #1 (tool-versions) | All test infrastructure (F14–F18) needs known toolchain | infra-master-plan §3.6 |
| #2 (snapshot rotation) | Daily-checkpoint reliability that B2 (2026-05-28 baseline) depends on | data-integrity §3 |
| #5 (editorconfig) | Reduces gate noise from whitespace drift across agent sessions | observed-patterns W2/W3 |
| #6 (SwiftLint) | Foundation for F14 dispatch tests on Swift code paths if/when added | F14 candidate spec |
| #7 (ruff) | Closes the same silent-typo class that produced PR #317 + F18 mutation test motivation | infra-master-plan §2.4 + §3.5 |
| #8 (coverage) | C1 + F15 both need a coverage signal to gate on; baseline now means v8.x ranking has data | followups §C1 + F15 |
| #9 (cron migration) | Removes macOS launchd lock-in flagged in observed-patterns W1/W11 | observed-patterns §W |
| #10 (gitleaks) | Pre-launch hygiene for App Store submission flow | release skill checklist |
| #11 (markdownlint) | Pre-condition for audit substrate report quality (External Audits #1–#4) | substrate spec §12 |
| #12 (branch protection) | Closes the `--no-verify` bypass class that `FEATURE_CLOSURE_COMPLETENESS` cycle-time check catches retroactively | v7.8.1 spec §"why advisory" |

Conversely, the project already plans to address (so I don't need to recommend):

- **F12 actionlint** — workflow lint on docket
- **F14 per-gate dispatch tests** — C1 starts 2026-05-22
- **F15 zero-coverage gate tests** — in C1 work
- **F16 try-repo harness** — foundation for F14/F18
- **F17 last_fired_at index** — telemetry materialization
- **F18 mutation testing** — Theme G test discipline
- **C2 web PR test gate** — RICE 200
- **C3 Sentry reachability test** — RICE 80
- **Quarterly Data Freshness Audit** (B4) — 2026-08-13 first run

The dev-env recommendations in this doc fill the **ergonomic and quality-of-life gaps that are not gate-shaped** — the ones the framework substrate doesn't auto-detect.

---

## 5. Project-specific scaling concerns (what breaks at 2× the current load)

Looking ahead at the next 30/60/90 days:

### 5.1 Storage growth

- `~/Documents/FitTracker2-backups/` is 500 MB+ across 20+ dated snapshots after 5 weeks. Linear extrapolation = ~5 GB/year. Internal disk has 36 GB free. **Hits zero in ~7 years** at this rate — fine, but `daily/` subdir is the growth driver and should be rotated to keep last 30d + monthly anchors. Plan: #2.
- `gate-coverage.jsonl` is append-only. Today's size unknown but with 34 gates × ~5 candidates each × ~30 commits/day = ~5K rows/day = ~500 KB/day = ~180 MB/year. Acceptable.
- `.claude/logs/_session-*.events.jsonl` is per-session, never cleaned. Across many sessions this accumulates. Recommend: 30-day retention via cron.

### 5.2 Pre-commit hook performance

Each commit fires 12+ write-time gates + Mechanism A coverage emission for each. Today's pre-commit time on a single-file commit is acceptable. At 4× the gate count (the v8.x trajectory), gate-fire overhead becomes user-noticeable. **No action today**, but instrument it: add a wall-clock timer to `.githooks/pre-commit` that emits `{"event": "pre_commit_timing", "duration_ms": N}` to `.claude/logs/pre-commit-timing.jsonl`. Trivial. Post-v7.9.

### 5.3 Cross-repo sync drift

`sync-from-fittracker2.ts` is the most complex script in fitme-story (22 KB). It runs at prebuild AND has 17 KB of tests. The risk surface scales with how many doc subdirs we sync. Today's 92 untracked auto-synced files in `src/data/docs/` (visible via `git status` after a sync) is noise that hides real-changes signals. **Action:** add `.gitignore` rules for the auto-synced docs subtree (it's regenerable, never edited by hand) and document the carve-out in the sync script header. Post-v7.9.

### 5.4 Multi-agent contention

The v7.8.1 branch-isolation gates handle this for `state.json` mutations. But concurrent agents writing to **shared ledgers** (`measurement-adoption.json`, `documentation-debt.json`) need the v7.8.3 Mechanism E merge driver — which is installed for those ledgers. Action: verify the driver list covers every append-only ledger:

```
.claude/shared/measurement-adoption-history.json
.claude/shared/integrity-checkpoint-ledger.jsonl
.claude/shared/integrity-checkpoint-ledger.md
.claude/shared/gate-coverage-weekly.jsonl
.claude/logs/gate-coverage.jsonl
.claude/logs/<feature>.log.json
.claude/logs/_session-*.events.jsonl
```

Already covered? Verify by reading `.gitattributes` post-v7.9. If gap, add to merge driver. Trivial fix.

### 5.5 Secret blast radius

`.env.example` in fitme-story lists 12+ variables. Real `.env.local` has actual values. If the SSD is lost AND the operator's machine is lost simultaneously, the Vercel dashboard + GitHub secrets are the recovery point. Both are passkey-protected (per UCC + GitHub passkey). **Backup plan exists.** But: the 2026-05-19 incident from memory ("Vercel-fs ephemerality" — UCC audit-log persisted to local fs that doesn't survive deploys) suggests **anything depending on local fs state has a hidden expiry**. Audit:

- `~/.claude/projects/<encoded>/memory/MEMORY.md` — local only
- `~/.fittracker/<probably tokens>` — local only
- `~/Library/LaunchAgents/<plists>` — local only

Action: document each in the migration manifest's "what doesn't migrate" section (the 2026-05-19 refresh covers the launchd plist). For memory + .fittracker dir, add to backup script.

### 5.6 MCP integration credential rotation

8 MCP servers (Figma, Supabase, Linear, Notion, Vercel, GA4, Drive, Calendar, etc) each have OAuth + a refresh token + service-account JWKS. None have a documented rotation policy. **Risk:** at TestFlight launch, a stale token causes a silent integration failure (e.g., GA4 reports stop accruing). **Action:** add a quarterly Q-1/Q-2/Q-3/Q-4 calendar item to the cadence-followups for credential health verification.

### 5.7 ai-engine deployment

The FastAPI ai-engine is built but not visibly deployed (no Railway/Fly config in `ai-engine/`). When deployment happens, the dev-env story changes:

- Containerization becomes mandatory (Dockerfile)
- Secret rotation becomes urgent (LLM_API_KEY currently commented in `.env.example`)
- Monitoring tier shifts (Sentry web + APM)
- ai-engine becomes a deployable surface = new CI workflow for deploy

**Action:** when ai-engine deploys, add the ai-engine-specific dev-env section to this doc (don't recommend pre-emptively).

---

## 6. Recommendations — full prioritized plan

Each item: **Action / Files / Effort / Tier / Calendar safety / Acceptance / Why**.

### Tier 1 — Critical for stability (eligible to ship after 2026-05-21 OR safe today if non-infra)

#### R1. Pin language versions via `.tool-versions`

- **Action:** Install `mise` (or `asdf`); write `.tool-versions` at root of both repos containing:
  ```
  node 24.14.0
  python 3.12.4
  swift 5.0   # Xcode controls real version; declarative for parity
  ```
- **Files:** `.tool-versions` (FT2 + fitme-story root); README setup section update
- **Effort:** 30 min
- **Calendar safety:** `scripts/*` infra-glob; **defer to 2026-05-22**
- **Acceptance:** `mise install` from clean clone resolves to the same versions used today
- **Why:** Removes "works on my machine" failures; enables Claude agents in subagent dispatch to assume known toolchain.

#### R2. Rotate / prune daily-checkpoint snapshots

- **Action:** Extend `daily-integrity-checkpoint.py` (or add `scripts/rotate-checkpoint-snapshots.py`) to keep:
  - Last 30 daily snapshots in `~/Documents/FitTracker2-backups/daily/`
  - First-of-month anchors permanent (12/year)
  - Compress older anchors to `tar.zst`
- **Files:** `scripts/rotate-checkpoint-snapshots.py` (new); Makefile target `checkpoint-rotate`; cron extension
- **Effort:** 1 h
- **Calendar safety:** `scripts/*` infra-glob; **defer to 2026-05-22**
- **Acceptance:** internal disk free ≥ 50 GB sustainably; rotation visible in checkpoint ledger
- **Why:** Internal disk at 83% capacity; backup silent-fail risk

#### R3. Add 2nd SSH signing key (YubiKey)

- **Action:** Generate ED25519 on YubiKey (or alternate device); register to GitHub; configure `~/.ssh/allowed_signers` with both
- **Files:** `~/.ssh/config`, `~/.ssh/allowed_signers`, `git config gpg.ssh.allowedSignersFile`
- **Effort:** 30 min
- **Calendar safety:** Operator-side, no repo-state mutation; **today**
- **Acceptance:** `git commit -S` succeeds with either key plugged in
- **Why:** Single-key loss = stuck. Same break-glass pattern as UCC Part 7.

#### R4. Clean up `MEMORY.md` (currently 44.5KB; system limit 24.4KB)

- **Action:** Move detail to individual `memory/<topic>.md` files (already done for ~40 topics — just need to trim the INDEX entries themselves to one line)
- **Files:** `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/MEMORY.md`
- **Effort:** 1 h
- **Calendar safety:** ~/.claude/ is internal-disk; no repo state; **today**
- **Acceptance:** `wc -c MEMORY.md` < 24400 bytes
- **Why:** System truncates past 24.4KB → memory is unreliable for cross-session continuity

#### R5. Enable GitHub branch protection on main (BOTH repos)

- **Action:** Via `gh api`:
  ```
  gh api -X PUT repos/Regevba/FitTracker2/branches/main/protection \
    -f required_status_checks[strict]=true \
    -f required_status_checks[contexts][]=pr-integrity \
    -f required_status_checks[contexts][]='Build and Test' \
    -F required_pull_request_reviews[required_approving_review_count]=0 \
    -F enforce_admins=false
  ```
- **Files:** GitHub repo settings only (no local state)
- **Effort:** 15 min
- **Calendar safety:** GitHub-side; **today**
- **Acceptance:** PR to main requires `pr-integrity` + `Build and Test` to pass
- **Why:** Required checks are bypassable today; this closes the `--no-verify`-then-push class without enforcing it in pre-commit

### Tier 2 — Important for scale (target 30 days post-v7.9 promotion)

#### R6. Add `.editorconfig` + `.vscode/{settings,extensions}.json`

- **Action:** Add shared editor config; suggested-extensions include `swiftlang.swift`, `ms-python.python`, `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `figma.figma-vscode-extension`, `redhat.vscode-yaml`, `editorconfig.editorconfig`
- **Files:** `.editorconfig`, `.vscode/settings.json`, `.vscode/extensions.json` (both repos)
- **Effort:** 1 h
- **Calendar safety:** `.vscode/*` and `.editorconfig` are not in `path-reducers.json` infra-glob; **safe today** but defer to 2026-05-22 for grouping with other dev-env commits
- **Acceptance:** Opening either repo in VS Code recommends extensions + applies the formatting rules
- **Why:** Standardizes future-agent experience; cuts whitespace-drift PR noise

#### R7. Add SwiftLint via SPM plugin

- **Action:** Add `realm/SwiftLint` SPM dep + build plugin; create `.swiftlint.yml` with conservative rule set (disable opinionated rules; enable bug-finding rules); add to `make verify-ios` as a non-blocking warn-only first
- **Files:** `Package.swift` (or .pbxproj entry), `.swiftlint.yml`, Makefile target `swiftlint`
- **Effort:** 2 h
- **Calendar safety:** Touches `Package.swift` (not in infra-glob) but `Makefile` IS in infra-glob; **defer to 2026-05-22**
- **Acceptance:** `make swiftlint` runs; emits findings to stdout; doesn't block CI initially
- **Why:** Zero Swift lint coverage today; SwiftUI idioms not enforced

#### R8. Add ruff for ai-engine + scripts/

- **Action:** Extend `ai-engine/pyproject.toml` with `[tool.ruff]` (line length 100, target Py 3.12, select E/F/W/I/N/UP/B/A/C4/SIM); add a top-level `pyproject.toml` at repo root for `scripts/` if needed (or add ruff config there); add Makefile target `pylint`
- **Files:** `ai-engine/pyproject.toml`, `pyproject.toml` (new at root), Makefile
- **Effort:** 1 h
- **Calendar safety:** `Makefile` + `scripts/` infra; **defer to 2026-05-22**
- **Acceptance:** `make pylint` exits 0 OR with documented findings; format-only mode runs cleanly via `ruff format --check`
- **Why:** 75+ Python scripts have zero static analysis; F18 mutation testing depends on a baseline of clean code

#### R9. Add coverage instrumentation (reporting only, no threshold)

- **Action:**
  - iOS: integrate `SlatherOrg/Slather` via SPM plugin; emit `.build/coverage/swift-coverage.json`; add `make coverage-ios`
  - Web: `npm install -D c8`; wrap test script: `c8 --reporter=json --reporter=text npm test`
  - Python: add `coverage` dev dep; `pytest --cov=ai_engine --cov-report=json`; add `make coverage-py`
  - Aggregate: `scripts/aggregate-coverage.py` emits `.claude/shared/coverage-summary.json` (per-language, per-target, % lines)
- **Files:** Package.swift / .pbxproj (Slather), `package.json` (c8), `pyproject.toml` (coverage), Makefile, new script
- **Effort:** 3 h
- **Calendar safety:** Mixed; **defer to 2026-05-22**
- **Acceptance:** Coverage summary visible in framework-status; iOS + web + Python all reporting
- **Why:** C1 (F14/F15 dispatch tests) needs a coverage baseline to gate against; v8.x ranking has gut-feel numbers today

#### R10. Migrate daily-checkpoint cron from launchd → GitHub Actions

- **Action:** Add `.github/workflows/daily-checkpoint.yml` running 06:00 UTC; on success commits to `.claude/shared/integrity-checkpoint-ledger.jsonl` (auto-resolved via Mechanism E merge driver) and uploads off-SSD artifact (90d retention); deprecate launchd plist (keep installed as belt-and-suspenders for first 30 days)
- **Files:** new workflow YAML; existing `daily-integrity-checkpoint.py` reused
- **Effort:** 3 h
- **Calendar safety:** `.github/workflows/*` infra-glob; **defer to 2026-05-22**
- **Acceptance:** Workflow runs at 06:00 UTC; ledger commit appears on main; launchd no longer required
- **Why:** Removes macOS launchd lock-in flagged in W1/W11 observed patterns; self-healing across machine changes; X10 Pro migration becomes trivial for the cron

#### R11. Add `gitleaks` pre-commit + GH Action

- **Action:** Add `gitleaks` to `.githooks/pre-commit` (after the framework gates); add `.github/workflows/gitleaks.yml` running on every push + scheduled weekly full-repo scan
- **Files:** `.githooks/pre-commit`, new workflow YAML, `.gitleaks.toml` rules
- **Effort:** 1 h
- **Calendar safety:** `.githooks/*` + `.github/workflows/*` infra-glob; **defer to 2026-05-22**
- **Acceptance:** Synthetic secret in a test commit blocks pre-commit; full-repo scan returns 0 findings on clean main
- **Why:** Pre-launch hygiene for App Store + 12+ env vars across fitme-story

#### R12. Add `markdownlint-cli2` to verify-local

- **Action:** `npm install -D markdownlint-cli2`; write `.markdownlint-cli2.jsonc` with relaxed-for-prose ruleset (disable MD013 line length, MD033 inline HTML); apply to `docs/` + `.claude/skills/` + `content/`; emit findings as warn-only first; add to `verify-local`
- **Files:** `package.json`, `.markdownlint-cli2.jsonc`, Makefile
- **Effort:** 1 h
- **Calendar safety:** root `package.json` + Makefile infra; **defer to 2026-05-22**
- **Acceptance:** `make verify-local` runs markdownlint; emits N findings; doesn't block CI initially
- **Why:** Case studies are gate inputs; broken links / heading-skips / missing alt-text degrade audit substrate quality (External Audits #1–#4)

### Tier 3 — Future-proofing (target 60–90 days post-v7.9)

#### R13. Add `pip-audit` to ai-engine CI

- **Action:** Add to `dependency-audit-weekly.yml`; emit findings in same digest format as `npm audit`
- **Effort:** 30 min
- **Why:** Python supply-chain coverage matches existing npm coverage

#### R14. Add SBOM generation (`syft`) on release tags

- **Action:** Extend `audit-bundle-on-tag.yml` to include `syft scan dir:. -o cyclonedx-json > bundle/sbom.cdx.json`
- **Effort:** 1 h
- **Why:** External Audit substrate already commits to public reproducibility — SBOM is the missing ingredient

#### R15. Add Playwright smoke specs for fitme-story

- **Action:** 3 specs — `/` loads, `/control-room/framework` requires auth and renders post-login, `/case-studies/[slug]` renders frontmatter
- **Files:** `tests/e2e/*.spec.ts`, `playwright.config.ts`
- **Effort:** 3 h
- **Why:** C2 (RICE 200) precondition; PR test gate becomes meaningful when there are tests TO run

#### R16. Add `@sentry/nextjs` to fitme-story

- **Action:** Standard SDK wrap of `next.config.mjs`; DSN from existing FT2 Sentry org
- **Effort:** 1 h
- **Why:** Web errors today are invisible past Vercel runtime logs

#### R17. Add commitlint for conventional-commits

- **Action:** `@commitlint/{cli,config-conventional}` as dev-dep; pre-commit hook `commitlint --edit "$1"`
- **Effort:** 30 min
- **Why:** Already 95% conformant by convention; enforce 100% so case-study autogen + release notes can be derived from log

#### R18. Add `shellcheck` to pre-commit

- **Action:** brew install shellcheck; pre-commit invokes on `*.sh` in scripts/
- **Effort:** 30 min
- **Why:** ~5 shell scripts in scripts/; bugs in `framework-status.sh` etc. would silently surface in CI

#### R19. Containerize ai-engine via devcontainer

- **Action:** `.devcontainer/devcontainer.json` + `Dockerfile` for ai-engine; matches Python 3.12 + dependencies; bind-mount ai-engine source
- **Effort:** 2 h
- **Why:** When ai-engine deploys (probably Q3 2026 with App Store launch), having the container today removes a Day 1 task

### Tier 4 — Aspirational (post-launch)

#### R20. Lighthouse-CI for fitme-story

#### R21. iOS App Thinning report in release flow

#### R22. OpenTelemetry across iOS ↔ ai-engine when ai-engine deploys

#### R23. Storybook (or Ladle) for fitme-story design-system browsing

#### R24. Distributed-tracing-aware Sentry config

---

## 7. Implementation calendar

Calendar-safe ordering (no calibration-window contamination):

| Date | What ships | Group |
|---|---|---|
| **today (2026-05-19)** | R3 (2nd SSH key), R4 (MEMORY.md cleanup), R5 (branch protection) | Operator-only, no infra-glob |
| **2026-05-21 eve / 22 morning** | v7.9 promotion ceremony (separate from this plan) | Calibration freeze ends |
| **2026-05-22** (post v7.9 decision) | R1 (.tool-versions), R6 (editorconfig + vscode), R2 (snapshot rotation) | Tier 1 + low-risk Tier 2 |
| **2026-05-23 → 2026-05-27** | R7 (SwiftLint warn), R8 (ruff), R10 (cron migration) | Tier 2 substrate |
| **2026-05-28 → 2026-06-04** | R9 (coverage), R11 (gitleaks), R12 (markdownlint) | Tier 2 finish |
| **2026-06-05 → 2026-06-30** | R13–R19 as bandwidth allows | Tier 3 |
| **post App Store launch** | R20–R24 | Tier 4 |

Critical: each R item should ship in its own PR with the framework's standard PM workflow chore work-type (1-phase: Implement → CI green → Merge). The reverse-sync + Mechanism E merge driver protect ledger appends from any concurrent agent work.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Tier-2 batch creates pre-commit slowness | Add timing instrumentation (see §5.2) before R7+R8+R11 land; revert any single item that adds >500ms |
| `.tool-versions` mismatches existing Xcode-bundled Swift | Test on local clone before push; document `swift 5.0` is declarative, not enforced by mise |
| Branch protection blocks emergency hotfix | Add operator-override via temporary unprotect + clear runbook |
| Coverage instrumentation surfaces low numbers and motivates rushed test-writing | Frame R9 as baseline-only; coverage thresholds are an F14/F15 decision, not this plan |
| Cron migration loses a day's data during cutover | Run launchd + GHA in parallel for 30 days; reconcile ledgers daily |
| gitleaks false-positives on legit `.env.example` placeholders | Tune `.gitleaks.toml` with explicit allowlist; first run dry-only |
| markdownlint produces 1000+ findings on first run | Run with `--no-globs --fix` first; commit auto-fixes; only then enable in verify-local |

---

## 9. Open questions for operator

Before any of this ships, decide:

1. **mise vs asdf** for version management? mise is faster + Rust-built + has direnv-like env hooks; asdf is more battle-tested but slower. Recommendation: **mise** for a solo operator who values speed.
2. **Coverage tool for iOS:** Slather vs xccov + xchtmlreport? Slather is older + has JSON output that aggregates cleanly; xccov is built-in. Recommendation: **Slather** to start; can swap later.
3. **Where does `make bootstrap` live?** New target in `Makefile` (FT2) that aggregates `mise install`, `make install-hooks`, `pnpm install` (when migrated), and env validation? Or a separate `scripts/bootstrap.sh`? Recommendation: **Makefile** target so it's discoverable next to other Make targets.
4. **Pre-push hook?** Run `make verify-local` before push? Trade-off: catches issues earlier but adds ~30s to every push. Recommendation: **opt-in** via env var `FITTRACKER_PRE_PUSH=1`.
5. **Cloud backup destination** when added (R-future)? B2 (cheapest), R2 (free egress, S3-compat), or S3 (most familiar)? Recommendation: **R2** — already in the Vercel/Cloudflare orbit.
6. **YubiKey purchase** if R3 isn't already satisfied? Solo Key 2A+ as alternative? Recommendation: **YubiKey 5C NFC** for parity with the operator's UCC passkey hardware (one key for git + auth).

---

## Appendix A — Full 18-dimension inventory

Reproduced verbatim from the 2026-05-19 Explore-agent inventory pass. Source-of-truth for everything cited in §2.

### A.1 Language toolchains & runtimes

- Xcode `5.0` Swift (project.pbxproj), iOS deployment target `17.0`
- Node `v24.14.0`, npm `11.13.0`
- Python `3.12+` (ai-engine/pyproject.toml, build = Hatchling)
- Shell: zsh; bash scripts in `scripts/`
- **Gap:** no `.swift-version`, `.nvmrc`, `.python-version`

### A.2 Package managers & lockfiles

- npm (only; no pnpm/yarn) — `package-lock.json` v1 in 3 FT2 dirs + fitme-story
- SPM with `Package.resolved`; clone cache `.build/spm-cache`
- pip via embedded `pyproject.toml`
- No Homebrew Brewfile

### A.3 Build system & artifact locations

- Makefile (50+ targets) — `verify-local`, `tokens-check`, `integrity-check`, `ui-audit`, `preflight`, `daily-checkpoint`, etc.
- `.build/` for SPM, DerivedData, npm cache, clang cache
- Overridable via `BUILD_DIR`, `DERIVED_DATA`, `SPM_CACHE`
- fitme-story Makefile is vendored subset

### A.4 CI/CD workflows

- **FT2:** 9 workflows — `ci.yml`, `pr-integrity-check.yml`, `integrity-cycle.yml`, `dependency-audit-weekly.yml`, `framework-status-weekly.yml`, `audit-prompts-weekly.yml`, `audit-bundle-on-tag.yml`, `figma-code-connect-publish.yml`, `ucc-audit-log-sync.yml`
- **fitme-story:** 6 workflows — `integrity.yml`, `case-study-audit.yml`, `figma-code-connect-publish.yml`, `figma-drift-weekly.yml`, `verify-blind-switch.yml`, `reverse-sync-fitme-story-to-ft2.yml`
- Secrets referenced: `FIGMA_ACCESS_TOKEN`, default GH token, Vercel implicit

### A.5 Pre-commit hooks

- FT2 `.githooks/pre-commit` enforces all v7.5–v7.8 gates (SCHEMA_DRIFT, PR_NUMBER_UNRESOLVED, PHASE_TRANSITION_*, BROKEN_PR_CITATION, CASE_STUDY_*, CACHE_HITS_*, CU_V2_INVALID, STATE_NO_CASE_STUDY_LINK, FRAMEWORK_VERSION_FORMAT, etc.)
- Self-audits via `make pre-commit-self-test`
- Mechanism E merge driver installed via `.claude/scripts/install-merge-drivers.sh`
- fitme-story `.githooks/pre-commit` is vendored subset

### A.6 Test infrastructure

- **iOS:** XCTest, 74 files, ~440 methods, via `make verify-ios`
- **Web:** tsx --test, 19 `.test.ts` files
- **Python:** pytest, asyncio_mode=auto, ai-engine/tests
- **Coverage:** none enforced

### A.7 Linters & formatters

- ESLint v9 via Next.js default (no `.eslintrc.json` standalone)
- No SwiftLint, ruff, black, markdownlint, prettier config

### A.8 Type checking

- Swift built-in
- TypeScript strict via fitme-story tsconfig.json
- No mypy / pyright

### A.9 Observability

- Sentry integration path (`.claude/integrations/sentry/`)
- GA4 via `@next/third-parties` (`NEXT_PUBLIC_GA_ID`)
- Vercel Speed Insights in fitme-story + dashboard
- Custom scripts: `analytics-watch.py`, `.claude/logs/gate-coverage.jsonl`, daily checkpoint
- `.claude/shared/*` — 30+ ledgers (framework-manifest, health-status, metric-status, measurement-adoption, documentation-debt, cache-metrics, token-budget, integrity-checkpoint-ledger, case-study-monitoring, …)

### A.10 Secrets management

- `.env.example` in ai-engine + fitme-story
- `.env.local` (fitme-story) + `.env` (ai-engine) gitignored
- GH secret: FIGMA_ACCESS_TOKEN
- Vercel secrets: BLOB_READ_WRITE_TOKEN, CRON_SECRET, UCC_*

### A.11 Dependency management hygiene

- Dependabot active (per merged PRs #406/#407) but no `.github/dependabot.yml` documented
- Weekly `aggregate-dependency-audit.py` cron

### A.12 Local dev tooling

- No `.vscode/`, `.editorconfig`, asdf/nvm/mise/direnv
- Rich MCP server coverage (~11 servers connected: Figma, Supabase, Linear, Notion, Gmail, Calendar, Drive, HuggingFace, PubMed, Vercel, GA4)

### A.13 Custom scripts

- FT2: ~75 scripts across integrity/observability/feature-lifecycle/design-system/quality/audit/HADF
- fitme-story: ~20 scripts (sync, validate, drift, control-room)
- See Explore-agent §13 for full list with sizes

### A.14 Documentation tooling

- Case studies generated via `scripts/sync-from-fittracker2.ts`
- Control room at `fitme-story/src/app/control-room/*`
- No Sphinx/MDBook — Markdown only

### A.15 MCP / agent harness

- `.claude/settings.json` (227 lines) — permissions + SessionStart/PostToolUse hooks
- `.claude/{cache,features,shared,skills,integrity,logs,worktrees,entrypoints,integrations}` — full framework substrate
- fitme-story has lighter `.claude/` footprint

### A.16 Editor / shell helpers

- Nothing — no direnv, asdf, nvm, mise, pyenv, .editorconfig

### A.17 Container / sandbox

- No Docker, devcontainer, or sandbox
- Vercel platform for fitme-story (Next.js Serverless + Edge)

### A.18 Backup / recovery

- `daily-integrity-checkpoint.py` → `~/Documents/FitTracker2-backups/daily/` + `/Volumes/DevSSD/FitTracker2-snapshots/`
- launchd plist daily @ 06:00 local
- 20+ dated backup dirs accumulated

---

## Appendix B — Cross-reference index

- **Original migration prep:** [`~/Documents/FitTracker2-backups/2026-05-13-ssd-migration/`](file:///Users/regevbarak/Documents/FitTracker2-backups/2026-05-13-ssd-migration/)
- **Refreshed migration prep (this session):** [`~/Documents/FitTracker2-backups/2026-05-19-ssd-migration-refresh/`](file:///Users/regevbarak/Documents/FitTracker2-backups/2026-05-19-ssd-migration-refresh/)
- **Infra master plan:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md)
- **Data integrity master plan:** [`docs/master-plan/data-integrity-and-rollback-2026-05-14.md`](../master-plan/data-integrity-and-rollback-2026-05-14.md)
- **Test coverage master plan:** [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md)
- **Cadence-followups ledger:** [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md)
- **Observed patterns catalog:** [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md)
- **Dev guide:** [`docs/architecture/dev-guide-v1-to-v7-7.md`](../architecture/dev-guide-v1-to-v7-7.md)
- **Audit substrate spec:** [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md)
