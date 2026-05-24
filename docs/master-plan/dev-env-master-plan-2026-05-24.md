# FitMe Dev-Env Stability & Scale Master Plan — 2026-05-24

> **Status:** CURRENT · Opened 2026-05-24 as a sub-doc of [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md)
> **Source audit:** [`docs/research/2026-05-19-dev-env-audit-stability-and-scale.md`](../research/2026-05-19-dev-env-audit-stability-and-scale.md) (655 lines, 24 ranked recommendations, 4 tiers)
> **Scope:** The development environment for both repos (FT2 iOS + ai-engine + dashboard + website; fitme-story Next.js + control room), plus the v7.8.6 framework substrate, multi-agent harness, and supporting CI/observability infra. Drives lint/test/coverage/security/backup hardening across 24 R-items grouped in 4 tiers.
> **Purpose:** Codify the 2026-05-19 dev-env audit as a tracked, in-spec master plan so that (a) every R-item is mirrored as a backlog row, (b) status is visible on disk via this sub-plan (not memory-only), (c) the calibration calendar respects v7.9 Phase E + branch-isolation infra-globs, and (d) shipped vs open status is greppable.
> **Why a sub-plan, not a section in the infra plan:** Same pattern as [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) + [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — dev-env work has its own R-series candidates, its own shipping calendar, and its own per-item calibration. Folding 24 items into infra plan §3 would crowd out v7.9.1 → v8.x F-series planning.
> **Authority:** R-candidates here are framework-substrate Chore work; they walk the standard PM workflow chore work-type (1-phase: Implement → CI green → Merge). They do NOT compete for the v7.9.1 / v8.0 F-series slots; they ship in their own cadence.

---

## 0. TL;DR

**6 of 24 shipped, 18 open.** Memory's "16/24" tally was an optimistic count; ground-truth fs sweep on 2026-05-24 confirms R1+R2+R3+R4+R5+R6 (all fully shipped — R6 re-verified 2026-05-24 PR-2A audit). The other 18 R-items remain open work — primarily lint/coverage/security tooling that's been calendar-blocked by the v7.9 calibration window (2026-05-15 → 2026-05-21) and is now eligible to ship starting **2026-05-22** with most items unblocking after Phase E exit (~2026-06-04).

**Tier breakdown (post-audit ground truth):**

| Tier | Theme | Total | Shipped | Open | Earliest open-item ship |
|---|---|---|---|---|---|
| 1 | Critical for stability | 5 | **5** | 0 | — (Tier 1 complete) |
| 2 | Important for scale | 7 | 1 (R6 fully shipped — re-verified 2026-05-24) | 6 | 2026-05-22 → 2026-06-04 |
| 3 | Future-proofing | 7 | 0 | 7 | 2026-06-05 → 2026-06-30 |
| 4 | Aspirational (post-launch) | 5 | 0 | 5 | post-App-Store-launch |

**Top 3 recommendations for next 14 days (Phase E + post-Phase-E):**

1. **Ship R7+R8+R12 as a single Tier-2 lint batch** (SwiftLint warn-only + ruff + markdownlint) on **2026-05-22 → 2026-05-24** while branch-isolation still demands chore-grouped commits. Each is ≤2h; bundle keeps `Makefile` + `pyproject.toml` infra-glob hits to one PR.
2. **R9 coverage instrumentation on 2026-05-25 → 2026-05-26** (Slather iOS + c8 web + coverage.py Python). Feeds the T1 `GATE_TEST_MISSING` meta-gate work (unblocks 2026-08-22 at F14 Phase E exit) AND v8.x ranking with real numbers.
3. **R10 + R11 as a CI-hardening pair on 2026-05-27 → 2026-06-03** (daily-checkpoint launchd → GHA migration + gitleaks pre-commit). Self-healing cron + pre-launch secret scanning. Both `.github/workflows/*` infra-glob — defer until v7.9 Phase E exit on 2026-06-04 if any uncertainty about contaminating the post-promotion soak.

---

## 1. Scope + Relationship to Infra Master Plan

### 1.1 What this plan covers

Every concern from the 2026-05-19 audit's 18-dimension inventory (Appendix A of source audit):

| Dimension | Audit § | R-items |
|---|---|---|
| Language toolchains & runtimes | A.1 | R1 |
| Package managers & lockfiles | A.2 | (already covered by Dependabot) |
| Build system & artifact locations | A.3 | (no R-item; in spec) |
| CI/CD workflows | A.4 | R10, R11, R13, R14 |
| Pre-commit hooks | A.5 | R11, R18 |
| Test infrastructure | A.6 | R9, R15 |
| Linters & formatters | A.7 | R7, R8, R12 |
| Type checking | A.8 | (covered by existing TS strict mode + Swift) |
| Observability | A.9 | R16 |
| Secrets management | A.10 | R11 (gitleaks) |
| Dependency management hygiene | A.11 | R13 (pip-audit) |
| Local dev tooling | A.12 | R6 |
| Custom scripts | A.13 | R2 |
| Documentation tooling | A.14 | R12 |
| MCP / agent harness | A.15 | (no R-item; per-MCP rotation tracked elsewhere) |
| Editor / shell helpers | A.16 | R6 |
| Container / sandbox | A.17 | R19 |
| Backup / recovery | A.18 | R2, R3 |
| Commit hygiene | A.7 (related) | R17 |
| Web E2E | A.6 (related) | R15 |
| Release/performance | A.6 (related) | R20, R21 |
| Distributed tracing | A.9 (related) | R22, R24 |
| Design system browsing | A.6 (related) | R23 |
| GitHub-level enforcement | A.4 (related) | R5 |
| Operator key resilience | A.10 (related) | R3 |
| Memory hygiene (agent harness) | A.15 (related) | R4 |

### 1.2 Relationship to the v7.9 / v8.x docket

Dev-env R-items are **work-type Chore** (1-phase, no PRD required). They do NOT promote into the v7.9.1 or v8.0 F-series; they ship in their own cadence. R-items walk the standard chore lifecycle (Implement → CI green → Merge) and are tracked in [`docs/product/backlog.md`](../product/backlog.md) under the new subsection "Dev-Env Stability & Scale Track."

| R-item ↔ F-item interaction | Effect |
|---|---|
| R9 (coverage) ↔ F14 | R9 provides baseline coverage numbers; F14 dispatch tests use them to gate against regression |
| R9 (coverage) ↔ T1 | T1 `GATE_TEST_MISSING` meta-gate (v8.0 backlog) becomes ranked-by-data once R9 emits coverage telemetry |
| R7+R8 (lint) ↔ F18 | F18 mutation testing benefits from a clean lint baseline; R7+R8 ship first |
| R10 (cron→GHA) ↔ infra plan §3.5.4 | Removes the launchd lock-in flagged in W1/W11 observed patterns; X10 Pro migration becomes trivial |
| R11 (gitleaks) ↔ External Audit #2 (2026-06-12) | Audit pack includes secret-scan results; gitleaks generates the artifact |

### 1.3 What this plan does NOT cover

- **Performance + load testing** — separate concern; backlog item
- **Penetration testing** — quarterly process via `/security-review` skill
- **Manual QA / TestFlight** — `/qa` skill + `/release` skill
- **Accessibility audits** — `/design accessibility`
- **App-store assets** — separate active feature (`app-store-assets`)
- **Storage hardware** — SSD migration to X10 Pro completed 2026-05-19; future hardware decisions tracked in [`reference_devssd_hardware_issue.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/reference_devssd_hardware_issue.md)

---

## 2. Current shipped status (R1–R24 matrix)

Source-of-truth fs sweep on 2026-05-24. `[x]` = file/config/policy exists on disk; `[ ]` = open.

### Tier 1 — Critical for stability

| ID | Action | Status | Evidence |
|---|---|---|---|
| R1 | Pin language versions via `.tool-versions` (mise) | **[x]** | `.tool-versions` at FT2 root (931 bytes; Node 24 + Python 3.12 + Swift 5.0) |
| R2 | Rotate / prune daily-checkpoint snapshots | **[x]** | `scripts/rotate-checkpoint-snapshots.py` exists |
| R3 | Add 2nd SSH signing key (YubiKey) | **[x]** | YubiKey LIVE per memory `project_session_2026_05_21_v7_9_devenv_ghsec` (2026-05-21) + `project_yubikey_signing_wrapper` (2026-05-23 wrapper) |
| R4 | Clean up `MEMORY.md` (currently > 24.4KB) | **[x]** | MEMORY.md = 21,196 bytes (was 44.5KB at audit time; trimmed 2026-05-23) |
| R5 | Enable GitHub branch protection on main | **[x]** | Per memory `project_repo_hardening_2026_04_29` — PUBLIC + branch protection with `enforce_admins=true`; required checks include `pr-integrity` |

### Tier 2 — Important for scale

| ID | Action | Status | Evidence / blocker |
|---|---|---|---|
| R6 | Add `.editorconfig` + `.vscode/{settings,extensions}.json` | **[x]** | Verified SHIPPED 2026-05-24 (audit re-check): FT2 + fitme-story both have `.editorconfig` (794 + 336 bytes) + `.vscode/settings.json` (991 + 1182 bytes) + `.vscode/extensions.json` (406 + 321 bytes). Original "PARTIAL" status was an audit miss — only file presence was checked, not contents. Both configs are substantive (language-specific tabSize, formatOnSave, recommended extensions: swift/python/eslint/prettier/figma/claude-code/markdown). |
| R7 | Configure SwiftLint via SPM plugin + `.swiftlint.yml` | **[ ]** OPEN | No `.swiftlint.yml`; calendar-safe **2026-05-22+** (`Makefile` infra-glob defer) |
| R8 | Configure ruff for ai-engine + `scripts/` | **[ ]** OPEN | No `[tool.ruff]` in pyproject; calendar-safe **2026-05-22+** |
| R9 | Add coverage instrumentation (Slather + c8 + coverage.py) | **[ ]** OPEN | No coverage tooling; **2026-05-25 → 2026-05-26** target |
| R10 | Migrate daily-checkpoint cron from launchd → GitHub Actions | **[ ]** OPEN | Cron still launchd; calendar-safe **2026-05-22+** (`.github/workflows/*` infra-glob defer). Recommend post-Phase-E for safety |
| R11 | Add `gitleaks` pre-commit + GH Action | **[ ]** OPEN | No `.gitleaks.toml`; calendar-safe **2026-05-22+** |
| R12 | Add `markdownlint-cli2` to `verify-local` | **[ ]** OPEN | No `.markdownlint-cli2.jsonc`; calendar-safe **2026-05-22+** |

### Tier 3 — Future-proofing (target 60–90 days post-v7.9)

| ID | Action | Status | Evidence / blocker |
|---|---|---|---|
| R13 | Add `pip-audit` to ai-engine CI | **[ ]** OPEN | Not in `dependency-audit-weekly.yml`; **2026-06-05+** |
| R14 | Add SBOM generation (`syft`) on release tags | **[ ]** OPEN | Not in any workflow; **2026-06-05+** |
| R15 | Add Playwright smoke specs for fitme-story | **[ ]** OPEN | No `playwright.config.ts`; precondition for C2 (T6 RICE 200, now CLOSED via fitme-story #137) — Playwright still needed for `/control-room/*` E2E coverage |
| R16 | Add `@sentry/nextjs` to fitme-story | **[ ]** OPEN | Not in fitme-story package.json; gated on Sentry-integration paused → pre-launch trigger |
| R17 | Add commitlint for conventional-commits | **[ ]** OPEN | No commitlint config; **2026-06-05+** |
| R18 | Add `shellcheck` to pre-commit | **[ ]** OPEN | Not in `.githooks/pre-commit`; **2026-06-05+** |
| R19 | Containerize ai-engine via devcontainer | **[ ]** OPEN | No `.devcontainer/`; **Q3 2026** with ai-engine deployment |

### Tier 4 — Aspirational (post-launch)

| ID | Action | Status |
|---|---|---|
| R20 | Lighthouse-CI for fitme-story | **[ ]** OPEN — post-App-Store-launch |
| R21 | iOS App Thinning report in release flow | **[ ]** OPEN — post-App-Store-launch |
| R22 | OpenTelemetry across iOS ↔ ai-engine (when deployed) | **[ ]** OPEN — gated on ai-engine deployment |
| R23 | Storybook (or Ladle) for fitme-story design-system browsing | **[ ]** OPEN — post-App-Store-launch |
| R24 | Distributed-tracing-aware Sentry config | **[ ]** OPEN — post-Sentry-resume |

---

## 3. Implementation calendar

Calendar-safe ordering. Every R-item respects v7.9 Phase E ("no new gates" + "no new test-discipline work" 2026-05-21 → 2026-06-04) AND branch-isolation infra-glob (`scripts/*`, `.github/workflows/*`, `Makefile`, `.githooks/*`).

| Window | Items | Notes |
|---|---|---|
| **today (2026-05-24)** | finish R6 (.vscode/settings.json + extensions.json) | `.vscode/*` is NOT in path-reducers infra-glob; safe today |
| **2026-05-22 → 2026-05-24** (post-v7.9 promotion + UCC B12 / B2 windows clear) | R7 (SwiftLint warn) + R8 (ruff) + R12 (markdownlint) as a bundled "lint baseline" PR | Each ≤2h; bundle keeps `Makefile` infra-glob hits to one PR |
| **2026-05-25 → 2026-05-26** | R9 (coverage instrumentation) | Standalone PR; feeds R10 + future F14/T1 work with real numbers |
| **2026-05-27 → 2026-06-03** | R10 (cron→GHA) + R11 (gitleaks) as CI-hardening pair | Both `.github/workflows/*` — recommend post-Phase-E-exit window 2026-06-05+ if any uncertainty |
| **2026-06-05 → 2026-06-30** (post Phase E exit) | R13 (pip-audit) + R14 (SBOM) + R15 (Playwright smoke) + R17 (commitlint) + R18 (shellcheck) | Tier 3 batch; sequence as bandwidth allows |
| **Q3 2026** (with ai-engine deployment + App Store launch) | R19 (devcontainer) + R16 (@sentry/nextjs unblocks at Sentry resume) | Coupled to product milestones |
| **post-App-Store-launch (Q4 2026 +)** | R20–R24 (Tier 4) | Lighthouse-CI, App Thinning, OpenTelemetry, Storybook, distributed-tracing Sentry |

Each R item ships in its own PR with chore work-type. The reverse-sync + Mechanism E merge driver protect `.claude/shared/*` ledger appends from concurrent agent work.

---

## 4. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Tier-2 lint batch (R7+R8+R12) makes pre-commit slow | Medium | Medium | Add timing instrumentation to pre-commit hook before R7+R8+R12 land; revert any single item that adds >500ms to typical run |
| `.tool-versions` mismatches existing Xcode-bundled Swift on operator's machine | Low | Low | Already shipped; document `swift 5.0` is declarative (not enforced by mise); Xcode controls real Swift version |
| Branch protection blocks emergency hotfix | Low | Medium | `enforce_admins=true` makes this real; operator-override runbook lives in `docs/setup/repo-hardening-runbook.md` (TODO: write if not present) |
| Cron migration (R10) drops a daily checkpoint during cutover | Medium | Low | Keep launchd installed in parallel for 30d after GHA goes live; alert if both fire OR neither fires on a given day |
| Coverage instrumentation (R9) emits noisy first-run numbers because most surfaces are untested | High | Low | Expected and intentional — report-only, no threshold for the first 30 days; T1 meta-gate decides threshold later |
| gitleaks (R11) blocks valid commit (false positive on a legitimate test fixture) | Medium | Low | Maintain `.gitleaks.toml` allow-list; document operator-override `--no-verify` with explicit reason in commit message |
| Playwright (R15) flakes on Vercel preview deployments | Medium | Medium | Run against locally-spun fitme-story dev server first; promote to preview-URL targeting only after 30-day local-baseline stability |
| markdownlint (R12) generates >1000 findings in first run | High | Low | Ship warn-only for the first 14 days; bulk-fix worst-class findings as a separate hygiene PR |
| SBOM generation (R14) leaks dep names that operator considers proprietary | Low | Low | Project is PUBLIC (per repo-hardening 2026-04-29); leakage is already moot |

---

## 5. Open questions

1. **R6 .vscode/ completeness** — `.vscode/` directory exists but only header-listed (4 entries). Are `settings.json` + `extensions.json` both present? Quick check during execution.
2. **R7 SwiftLint as SPM plugin vs separate Mint install** — SPM plugin keeps the toolchain pinned via `Package.swift`; Mint install survives a `.build/` wipe but requires operator install. Decide at R7 execution.
3. **R10 GHA vs Vercel Cron for daily checkpoint** — GHA is free for public repos + already host of integrity-cycle.yml. Vercel Cron requires a webhook target. Default: GHA unless Vercel Cron is being chosen for a non-obvious reason.
4. **R11 gitleaks scope** — full-repo scan on every push is slow; scoped-to-changed-files-on-push + full-repo-weekly is the conventional split. Confirm at R11 execution.
5. **R15 Playwright vs Vitest browser-mode** — Vitest now has experimental browser-mode that's lighter-weight than full Playwright. For 3 smoke specs, the difference is small. Default: Playwright (industry standard, better debugging).
6. **R19 devcontainer base image** — official `mcr.microsoft.com/devcontainers/python:3.12-bookworm` vs a thinner Debian slim. Decide at R19 execution; bigger image = faster cold start, smaller = less attack surface.
7. **Coverage thresholds (R9 outcome)** — current baseline is unknown. After R9 emits the first report, propose initial threshold (likely "≥ current minus 5% per file" — anti-regression only, not floor). Threshold decision is itself a separate item.

---

## 6. References

### Parent / sibling sub-plans

- [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) — canonical v7.9 / v8.x docket
- [`test-coverage-master-plan-2026-05-13.md`](test-coverage-master-plan-2026-05-13.md) — sibling sub-plan; R9 coverage feeds T1 there
- [`data-integrity-and-rollback-2026-05-14.md`](data-integrity-and-rollback-2026-05-14.md) — sibling; R10 cron migration aligns with daily-checkpoint protocol there
- [`analytics-master-plan-2026-05-13.md`](analytics-master-plan-2026-05-13.md) — sibling; R16 Sentry web wiring aligns with analytics-observability
- [`post-v7-9-candidate-plan-2026-05-20.md`](post-v7-9-candidate-plan-2026-05-20.md) — sibling; R-items are NOT in the v7.9.1 docket (they're chore work, separate cadence)

### Source audit

- [`docs/research/2026-05-19-dev-env-audit-stability-and-scale.md`](../research/2026-05-19-dev-env-audit-stability-and-scale.md) — 655-line research-grade audit; full R1–R24 detail (action / files / effort / acceptance / why)

### Backlog tracking

- [`docs/product/backlog.md`](../product/backlog.md) §"Dev-Env Stability & Scale Track" — 18 open R-items mirrored as backlog rows

### Live state evidence

- `.tool-versions` (R1 shipped) · `scripts/rotate-checkpoint-snapshots.py` (R2 shipped) · `.editorconfig` (R6 shipped) · `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/MEMORY.md` 21.2 KB (R4 shipped) · YubiKey live + branch protection live (R3+R5 per memory)

### Memory cross-references

- [`project_session_2026_05_21_v7_9_devenv_ghsec.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_21_v7_9_devenv_ghsec.md) — original "dev-env 16/24" claim (now reconciled as 6/24 here)
- [`project_yubikey_signing_wrapper.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_yubikey_signing_wrapper.md) — R3 follow-up wrapper installed 2026-05-23
- [`project_repo_hardening_2026_04_29.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_repo_hardening_2026_04_29.md) — R5 branch protection origin
- [`project_session_2026_05_19_late_migration_crash_recovery.md`](~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_19_late_migration_crash_recovery.md) — SSD migration complete (X10 Pro canonical); out of R-scope but adjacent

### CLAUDE.md anchors

- "Concurrent Dispatch Hygiene" section — branch isolation infra-glob list that R-items respect
- "v7.9 Promotion Release" section — Phase E calendar that R-items respect
- "Key Paths" section — pointer to backlog + cadence ledger

---

## 7. Change log for this document

| Date | Change |
|---|---|
| 2026-05-24 | Initial creation. Reconciles "dev-env 16/24" memory claim against fs ground truth (6/24); registers as sub-plan of infra master plan; opens 18 backlog rows. |
