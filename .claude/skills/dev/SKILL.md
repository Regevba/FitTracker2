---
name: dev
description: "Use when starting a feature branch, requesting code review, checking CI status, auditing dependencies, profiling a performance hotspot, or auditing the skills layer itself (skill-of-skills meta-checks). Respects high-risk-area review policy (DomainModels, EncryptionService, SupabaseSyncService, CloudKitSyncService, SignInService, AuthManager, AIOrchestrator). Sub-commands: /dev branch {feature}, /dev review, /dev deps, /dev perf, /dev ci-status, /dev skills {audit|trace|freshness}."
last_updated: 2026-05-14
framework_version: v7.8.5
status: active
---

# Development Skill: $ARGUMENTS

You are the Development specialist for FitMe. You manage branching strategy, code review checklists, CI pipeline status, dependency health, and performance profiling.

## Preflight — Observed Patterns Catalog (v7.8.5+)

Before debugging any unexpected git, gate, or CI behavior, check [`.claude/integrity/observed-patterns.md`](../../integrity/observed-patterns.md) (`make observed-patterns`). 23 gate patterns + 9 workflow patterns are catalogued. The W-section is especially relevant for `/dev` work:

- **W1** SSH signing requires `ssh-add` loaded before headless commits
- **W3** Check CI before local-build panic
- **W4** No auto-merge without explicit approval
- **W5** No destructive operations without approval
- **W9** Branch-drift from concurrent-session `git checkout` collision (real-time alert wired via PostToolUse:Bash hook → if the warning fires, follow the 4-step recovery playbook in the catalog)

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

### `/dev skills {audit|trace|freshness}`

Skill-of-skills meta-checks for `.claude/skills/*`. Wraps the P0.4 audit script and adds usage tracing + freshness inspection. Per [`docs/skills/skills-review-2026-05-13.md`](../../../docs/skills/skills-review-2026-05-13.md) §5 item P1.1.

#### `/dev skills audit`

Run mechanical conformance checks on every SKILL.md (frontmatter present, trigger-rich descriptions, observed-patterns reference, adapter + script refs resolve on disk, freshness within window).

```bash
make skills-audit             # strict mode — exit 1 on E findings
python3 scripts/skills-audit.py --advisory --quiet   # advisory mode (used in `make integrity-check`)
python3 scripts/skills-audit.py --skill <name>       # single-skill scope
```

Report: per-skill PASS / E[code] / W[code] lines + summary count. Exit codes: 0 on clean, 1 on E findings. The audit also runs inside `make integrity-check` as `--advisory --quiet` (v7.8.5 → v7.9 window).

#### `/dev skills trace {feature}`

Surface which skills fired during a feature's lifecycle by cross-referencing three data sources:

1. **`state.json::cache_hits[]`** — Read events attributed to that feature (Mechanism C). Filter for entries whose `file` field matches `.claude/skills/<name>/SKILL.md` — that's the proxy for "skill loaded into context."
2. **`state.json::tasks[].dispatched_skills`** (if populated) — explicit skill dispatch ledger.
3. **`.claude/logs/_session-<id>.events.jsonl`** — raw session events; filter where `active_feature == <feature>` and the Read target contains `.claude/skills/`.

Output: ranked list of `<skill> — N hits` for the feature. Surfaces zero-usage skills empirically; data feeds the P2.4 retire/merge decision in the future.

When `{feature}` is omitted: aggregate across all features in `.claude/features/*/state.json` and report a leaderboard.

#### `/dev skills freshness`

Inspect every SKILL.md frontmatter and flag those with `last_updated:` older than 90 days. Wraps the `W4` warning emitted by `scripts/skills-audit.py` (since this commit) so the operator can see the same data without running the full audit.

```bash
python3 scripts/skills-audit.py --quiet 2>&1 | grep '\[W4\]'
```

Reads `last_updated:` from each `.claude/skills/<name>/SKILL.md`. Flags any skill `>90 days` since last update (configurable via `--max-age-days <N>` to the audit script). Forces a review even if the skill is otherwise passing — stale skills accumulate quiet drift against the framework version they cite.

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


## Anti-patterns

Hard-won mistakes for `/dev` work. Every bullet encodes a real or near-miss failure mode.

- Do not run `git commit` in a headless Bash shell without first confirming `ssh-add -l` shows identities — `ssh-keygen -Y sign` hangs silently with no error when the agent is empty (pattern W1)
- Do not run destructive git operations (`git reset --hard`, `git push --force`, `git checkout .`, `git clean -f`, `git branch -D`) without explicit user approval — even if they look reversible from your perspective (pattern W5)
- Do not merge a PR while you have unresolved questions about the diff — approval is multi-part (pattern W7)
- Do not assume CI is broken before checking GitHub Actions status — environment-specific local failures are common (pattern W3: check CI before local-build panic)
- Do not auto-merge a PR without explicit user 'merge' instruction — `gh pr merge --auto` flags should never be used unattended (pattern W4)
