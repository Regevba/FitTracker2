# PRD: CI Pipeline

> **ID:** CI | **Status:** Shipped | **Priority:** P0
> **Last Updated:** 2026-04-04

> **Status note (2026-04-26):** No standalone `.claude/features/` directory exists for this PRD. This is intentional — CI is framework-internal infrastructure, not a product feature. State tracking happens at the framework version level (`docs/architecture/dev-guide-v1-to-v7-6.md` — the v7.6 Mechanical Enforcement bump shipped 2026-04-25 added per-PR review bot + weekly framework-status cron on top of this pipeline). Changes here are governed by the framework versioning lifecycle, not the PM workflow.

---

## Purpose

Automated CI pipeline that validates every commit with design token drift detection, iOS build verification, and test execution — ensuring code quality and design system consistency.

## Business Objective

CI prevents regression, enforces design system governance, and enables confident merging. The token-check gate is unique to FitMe — it ensures the auto-generated `DesignTokens.swift` stays in sync with `tokens.json`, preventing visual drift.

## Current Implementation

### Pipeline Steps
| Step | Command | Purpose |
|------|---------|---------|
| 1. Token Check | `make tokens-check` | Verify DesignTokens.swift matches tokens.json |
| 2. Build | `xcodebuild build` | iOS Simulator build (no code signing) |
| 3. Test | `xcodebuild test` | XCTest suite execution |

### Token Pipeline
| Stage | Tool | Details |
|-------|------|---------|
| Source | `design-tokens/tokens.json` | Single source of truth |
| Transform | Style Dictionary (`sd.config.js`) | Custom transforms + formats |
| Output | `DesignTokens.swift` | Auto-generated (DO NOT EDIT) |
| Verify | `scripts/check-tokens.js` | Diff committed vs generated |

### Infrastructure
- **GitHub Actions** — `.github/workflows/ci.yml`
- **Xcode 16+** build environment
- **Node.js** for token pipeline
- **macOS runner** for Xcode builds

### Merge Requirements (CLAUDE.md)
- All three CI steps must pass before merge to main
- Both feature branch AND main must be green
- High-risk files require extra review: DomainModels.swift, EncryptionService.swift, SupabaseSyncService.swift, CloudKitSyncService.swift, SignInService.swift, AuthManager.swift, AIOrchestrator.swift

## Key Files
| File | Purpose |
|------|---------|
| `.github/workflows/ci.yml` | GitHub Actions workflow |
| `Makefile` | `tokens`, `tokens-check`, `install` targets |
| `sd.config.js` | Style Dictionary configuration |
| `scripts/check-tokens.js` | Token drift detection |
| `design-tokens/tokens.json` | Token source of truth |

## Success Metrics

| Metric | Baseline | Target | Status |
|--------|----------|--------|--------|
| CI pass rate | 0% (no instrumentation existed before) (T2 — Declared, 2026-04-26) | >95% (T2 — Declared) | Active |
| Token drift incidents | N/A — pre-launch (T2 — Declared, 2026-04-26) | 0 (T2 — Declared) | Enforced by CI gate |
| Build time | N/A — pre-launch (T2 — Declared, 2026-04-26) | <5 min (T2 — Declared) | Monitored |
| Kill criteria | CI pass rate <80% sustained for 14 days OR build time >15 min p95 sustained 14 days OR token drift incidents >2/month sustained 60 days → CI pipeline is considered failed and the workflow is rebuilt (potential split into faster sub-jobs) (T2 — Declared, 2026-04-26) | — | GitHub Actions runs |

## Guardrails
- CI pass rate >95% is a system-wide guardrail (CLAUDE.md)
- Merge blocked if any step fails
- No `--no-verify` or hook bypasses allowed
