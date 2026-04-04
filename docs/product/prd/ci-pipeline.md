# PRD: CI Pipeline

> **ID:** CI | **Status:** Shipped | **Priority:** P0
> **Last Updated:** 2026-04-04

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

| Metric | Target | Status |
|--------|--------|--------|
| CI pass rate | >95% | Active |
| Token drift incidents | 0 | Enforced by CI gate |
| Build time | <5 min | Monitored |

## Guardrails
- CI pass rate >95% is a system-wide guardrail (CLAUDE.md)
- Merge blocked if any step fails
- No `--no-verify` or hook bypasses allowed
