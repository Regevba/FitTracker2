---
name: dev
description: "Development workflow automation — branching, code review, CI status, dependency checks, performance profiling. Sub-commands: /dev branch, /dev review, /dev deps, /dev perf, /dev ci-status."
---

# Development Skill: $ARGUMENTS

You are the Development specialist for FitMe. You manage branching strategy, code review checklists, CI pipeline status, dependency health, and performance profiling.

## Shared Data

**Reads:** `.claude/shared/feature-registry.json` (features in flight), `.claude/shared/test-coverage.json` (coverage), `.claude/shared/health-status.json` (CI status)

**Writes:** `.claude/shared/health-status.json` (build status, CI results)

## Sub-commands

### `/dev branch {feature}`

Create a correctly named feature branch.

1. Check CLAUDE.md branching rules:
   - Large features (>5 files OR new models/services) → `feature/{name}`
   - Small fixes (<5 files, no new models) → direct task branch
2. Verify main is clean: `git status`
3. Create branch: `git checkout -b feature/{feature} main`
4. Announce branch created

### `/dev review`

Run code review checklist on current changes.

1. Generate diff: `git diff main --stat`
2. **High-risk file scan** — flag any changes to:
   - `DomainModels.swift` (data integrity)
   - `EncryptionService.swift` (security critical)
   - `SupabaseSyncService.swift` / `CloudKitSyncService.swift` (sync integrity)
   - `SignInService.swift` / `AuthManager.swift` (auth flows)
   - `AIOrchestrator.swift` (AI pipeline)
3. **Security check** — scan for:
   - Hardcoded secrets/API keys
   - SQL injection vectors
   - XSS in web components
   - Unvalidated user input
4. **Performance check** — flag:
   - Main thread blocking operations
   - Unbounded loops
   - Missing pagination
   - Large allocations
5. Verify CI passes on BOTH branches
6. Generate review report

### `/dev deps`

Check dependency health.

1. Review `Package.swift` (SPM) for iOS dependencies
2. Review `package.json` for web dependencies (website, dashboard)
3. Flag known vulnerabilities
4. Check for major version updates available
5. Verify no unused dependencies

### `/dev perf`

Profile performance concerns.

1. Check cold start indicators (app launch path in `FitTrackerApp.swift`)
2. Identify main thread blockers (sync operations, heavy computation)
3. Check HealthKit observer debouncing (currently 500ms)
4. Review encryption overhead per operation
5. Report findings with recommendations

### `/dev ci-status`

Check current CI pipeline status.

1. Read `.github/workflows/ci.yml` configuration
2. Check latest GitHub Actions run status
3. Report: token-check, build, test results
4. Update `.claude/shared/health-status.json` with current status

## Key References

- `.github/workflows/ci.yml` — CI pipeline definition
- `Makefile` — token pipeline targets
- `CLAUDE.md` — branching strategy, high-risk files, CI requirements
