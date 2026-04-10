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

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| github | CLI | PR status, CI results, issue tracking (already integrated via gh CLI) |
| security-audit | MCP | CVE vulnerability scanning, dependency audit results |

**Adapter location:** `.claude/integrations/security-audit/`
**Shared layer writes:** `task-queue.json`

### Validation Gate

All incoming security/CI data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /dev + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /dev + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for a dev task, research:

1. **Implementation approach** — existing patterns in codebase, architecture conventions (MVVM, service layer), similar feature implementations
2. **Dependencies** — SPM package availability, version compatibility, CVE status (via security-audit adapter)
3. **Branching strategy** — feature branch vs direct, high-risk file list from CLAUDE.md, CI requirements
4. **Tools & APIs** — GitHub CLI capabilities, Xcode build settings, CI pipeline configuration
5. **Code quality** — Swift best practices, memory management patterns, concurrency approaches (async/await vs Combine)

Sources checked in order: L1 cache → L2 shared (screen-refactor-playbook) → shared layer (task-queue.json, health-status.json) → integration adapters (security-audit) → codebase → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/dev/_index.json`. Check for cached branching patterns, code review outcomes, security scan baselines. Also read `.claude/cache/_shared/screen-refactor-playbook.json` when implementing UI.

**Phase 4 (Learn):** Extract new patterns (implementation approaches, dependency decisions, CI fixes). Write/update L1 cache.

**Cache location:** `.claude/cache/dev/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
Read `.claude/cache/dev/_index.json`, match `v2_screen_implementation`, check L2 `screen-refactor-playbook.json`. If hit: follow recipe directly. If miss: Phase 2.

### Phase 4 — Learn (on skill complete)
Extract new decomposition approaches, build fixes. Write L1. If applies to /design or /qa, flag L2.

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| security-audit | `.claude/integrations/security-audit/` | health-status.json, test-coverage.json | On `/dev deps` or `/dev review` |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. v2/ convention from CLAUDE.md
2. Existing code patterns in target dir
3. Build config (pbxproj, SPM)
4. CI pipeline (make tokens-check, xcodebuild)
5. Performance baselines

**Source priority:** L2 cache > L1 cache > shared layer (health-status.json) > security-audit adapter > pbxproj direct read
