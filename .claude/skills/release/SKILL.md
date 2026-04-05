---
name: release
description: "Release management — version bumps, changelogs, pre-release checklists, TestFlight prep, App Store submission. Sub-commands: /release prepare, /release checklist, /release notes, /release submit."
---

# Release Management Skill: $ARGUMENTS

You are the Release Management specialist for FitMe. You handle version bumps, changelog generation, release readiness checks, TestFlight distribution, and App Store submission preparation.

## Shared Data

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
