---
name: dev
description: "Use when starting a feature branch, requesting code review, checking CI status, auditing dependencies, profiling a performance hotspot, or auditing the skills layer itself (skill-of-skills meta-checks). Respects high-risk-area review policy (DomainModels, EncryptionService, SupabaseSyncService, CloudKitSyncService, SignInService, AuthManager, AIOrchestrator). Sub-commands: /dev branch {feature}, /dev review, /dev deps, /dev perf, /dev ci-status, /dev skills {audit|trace|freshness}."
last_updated: 2026-05-15
framework_version: v7.8.6
status: active
adapters_used: [security-audit]
---

# Development Skill: $ARGUMENTS

You are the Development specialist for FitMe. You manage branching strategy, code review checklists, CI pipeline status, dependency health, and performance profiling.

## Preflight — Observed Patterns Catalog (v7.8.5+)

<!-- BEGIN pattern-preflight (generated) -->
The [pattern↔skill map](../../shared/pattern-skill-map.json) tracks **69 work-blocking patterns** (25 gate-firing patterns + 44 workflow patterns) drawn from the [Observed Patterns Catalog](../../integrity/observed-patterns.md) (`make observed-patterns`). The patterns below are the ones mapped to `/dev` work — probe the mechanized ones, checklist the rest:

| ID | Pattern | Blocker | Remediation |
|---|---|---|---|
| `#12` | PR_CACHE_STALE — empty/stale cache → cascading false positives *(probed)* | no | Auto-refreshes via scripts/ensure-pr-cache-fresh.py; run make refresh-pr-cache if findings persist. |
| `#13` | BROKEN_PR_CITATION — unresolved PR cite (graceful fallback when gh unavailable) *(probed)* | yes | Fix the PR citation or add pr_citation_exempt frontmatter; skipped gracefully when gh is unavailable. |
| `#23` | .gitignore blocks Mechanism A / Mechanism C remote-agent visibility | no | Commit periodic gate-coverage / session-ledger snapshots to non-gitignored paths so remote agents can audit. |
| `#24` | Field-rename silent-pass in a READER/INDEX (measurement layer) — generalization of #7/#9 *(probed)* | no | Make the reader accept BOTH field representations (d.get('new') or d.get('legacy')); add a unit test pinning both; grep every reader of a renamed field in the same change. |
| `#25` | Derived index from gitignored session-local source regresses on overwrite — union-merge, don't overwrite *(probed)* | no | A committed artifact derived from a gitignored session-local source must union-merge with the existing committed copy (max counters, min first_seen, max last_*, carry over entries present only in committed), never overwrite. A thin/empty local source must not shrink it. Provide a --rebuild escape hatch for intentional resets. Fixed in scripts/refresh-gate-last-fired.py (PR #749). |
| `W1` | SSH signing requires loaded agent before headless commits *(probed)* | no | Run ssh-add ~/.ssh/id_ed25519 before headless commits; verify with ssh-add -l. |
| `W3` | Check CI before local-build panic | no | Check CI status (gh run list) before deep local-build debugging. |
| `W4` | No auto-merge without explicit approval | yes | Never auto-merge; surface PR + checks and wait for explicit approval. |
| `W5` | No destructive operations without approval | yes | Never delete branches/worktrees/files or force-push without explicit approval; list + propose first. |
| `W7` | Approval gates are multi-part | yes | Treat each destructive step as a separate approval; prior approval doesn't carry over. |
| `W9` | Branch drift from concurrent-session git checkout collision *(probed)* | no | If the branch-drift alert fires, stop, stash/cherry-pick, and git checkout the expected branch (W9 playbook). |
| `W10` | Stale [gone] branches + orphan worktrees surfaced by daily-checkpoint | no | Clean stale [gone] branches / orphan worktrees via commit-commands:clean_gone after confirming merge. |
| `W17` | Stale-base branches — cherry-pick onto fresh main is ground truth | yes | For stale-base branches, cherry-pick onto fresh origin/main to find ground truth before merging. |
| `W21` | Swift String.contains("\n") misses CRLF graphemes — scan unicodeScalars | yes | Scan unicodeScalars (not graphemes) for ASCII control chars like CR/LF in Swift. |
| `W22` | Swift type-checker timeout on heterogeneous array literals >20 elements | yes | Pre-compute each cell as a String local; use .map { String($0) } closure form for Optionals. |
| `W23` | AnalyticsService.logEvent is private — callers must use a log* method | yes | logEvent is private — add a named log* method, or use #if DEBUG print for can't-happen paths. |
| `W24` | pbxproj merge conflicts from concurrent PRs at same group/sources position | no | Resolve pbxproj merge conflicts additively — keep all branches' distinct PBXBuildFile/FileReference entries. |
| `W25` | @MainActor propagates to statics — test class must be @MainActor | yes | Mark test classes that exercise @MainActor types (incl. their statics) with @MainActor. |
| `W26` | Two workflows sharing name: clash in github.workflow concurrency groups *(probed)* | no | Give each workflow a hardcoded concurrency-group prefix, not ${{ github.workflow }}, when names collide. |
| `W28` | Local xcodebuild blocked by CoreSimulator out-of-date (Mac restart required) | no | Local xcodebuild CoreSimulator-out-of-date needs a Mac restart; fall back to swiftc -parse + CI. |
| `W30` | Q6 PR-list parity gate's minimal YAML parser silently strips list items lacking # | yes | In case-study related_prs frontmatter, use either string form (- "PR #623") OR inline bracket form (related_prs: [621, 623]). Bare YAML integers under dashed lists get silently dropped by _parse_case_study_frontmatter at scripts/check-state-schema.py:1149. Durable parser patch queued in backlog Framework hygiene. |
| `W31` | Workflow delivery anomaly: initial pull_request:opened sometimes fires only the dynamic/skip-path workflows; rebase + force-push triggers full set | no | If a PR open fires fewer than the usual 11-12 checks, run `git rebase origin/main` + `git push --force-with-lease`. close+reopen does NOT reliably re-trigger. Workaround documented as a PR-flow protocol; durable fix queued (CI assertion of expected workflow set). |
| `W32` | scripts/close-feature.py requires --force-incomplete when merged PR was the only phase (implementation → complete directly, no testing phase) | yes | For single-phase framework features (e.g., sub-fixes shipping their own unit tests in-phase), call `python3 scripts/close-feature.py <feature> --force-incomplete` directly. The `make close-feature` target does NOT pass --force-incomplete through. Durable script-heuristic patch queued in backlog Framework hygiene. |
| `W34` | PR cache window truncation past the 500-PR limit *(probed)* | yes | Verify the cache window covers the historically-cited PR range: `python3 -c "import json; v=json.load(open('.cache/gh-pr-cache.json'))['repos']['Regevba/FitTracker2']; ns=sorted({x['number'] for b in('open','merged','closed') for x in v[b]}); print('floor',ns[0],'ceil',ns[-1],'count',len(ns))"`. If the floor is far above 1 while citations reference numbers below it, the `gh pr list --limit N` window is truncated. Fix: raise `--limit` in `scripts/refresh-pr-cache.py` (shipped 2026-06-05 PR #631 raised it to 2000 — covers FT2's 571 PRs + headroom). Sibling patterns: #12 PR_CACHE_STALE (empty cache), W11 (incomplete repo set). |
| `W35` | Hook session-id keyed on never-set CLAUDE_SESSION_ID env → constant "default" → cross-session marker suppresses the gate forever | yes | When a hook needs the session id, read it from the hook STDIN payload (`session_id`), never `os.environ['CLAUDE_SESSION_ID']` (Claude Code does not set it). Use scripts/w9_session.py::session_id(). Symptoms: a gate's once-per-session marker piles up as `.claude/_session-state/default-*`; a gate's telemetry all carries one outcome from one code path while a documented sibling path emits nothing. When one gate name has two producers, give each its own gate name so GATE_COVERAGE_ZERO can see each independently. Fixed via feature fix/w9-session-id-keying (2026-06-14). |
| `W36` | Plan/seat-gated external capability documented as operational while it never once succeeded | yes | Treat a plan/seat-gated capability as an external dependency and verify it end-to-end: check the workflow run history (not existence) for successes. Scaffolding present ≠ pipeline working. Detection: `gh run list --workflow=<name>.yml --limit 20 \| grep -c success` (scaffold-only runs?); for Figma Code Connect: MCP get_code_connect_map returns plan-gate error on Pro. Remediation: (1) disable the scaffold CI if the plan is not available; (2) reconcile all docs to reflect the actual state; (3) add a honesty-ledger entry; (4) write a rebuild plan that uses capabilities actually available on the current plan. See observed-patterns.md W36, FT2-FH-005. |
| `W37` | Bot-authored (GITHUB_TOKEN) PR can never satisfy required checks under strict branch protection → permanent 'expected' deadlock | yes | GITHUB_TOKEN-created PRs don't trigger pull_request CI; with strict+enforce_admins the required checks stay 'expected' and API --admin merge is refused (web-UI admin bypass only). For append-only ledger workflows: commit+push straight to main (option B, shipped 2026-06-15) with the github-actions app in main's bypass_pull_request_allowances; PR fallback if push rejected. Alternative: GitHub App token so the PR triggers CI + enable-auto-merge (option A). See observed-patterns.md W37. |
| `W39` | Breaking-change major-version Dependabot bump cannot auto-merge; churns as repeated closed-unmerged PRs until a human ships a golden-verified manual migration | no | A major bump of a build-time dep (bundler/token-compiler/codegen/lint) whose new major removed the API the config used is a code migration, not a version-string change. Dependabot can only edit the version, so its PR fails CI (or passes a thin CI) and is closed; it re-proposes the next patch and the cycle repeats. Treat such a PR as a migration ticket: close the auto-bump, open a hand-authored migration branch, gate it on a golden-file diff (regenerate committed artifact, assert byte-identical). Repeat-bump tell: >=2 closed Dependabot PRs for the same package's same major. Distinct from W29 (passes CI, breaks main post-merge). See observed-patterns.md W39. |
| `W40` | Cross-layer tracker lag: item shows OPEN in Linear/Notion/backlog while already SHIPPED in the repo (no mechanical slug<->tracker join) *(probed)* | no | Trackers (Linear/Notion/backlog/plans) are downstream mirrors; repo (.claude/features/<slug>/state.json::current_phase + merged PRs) is source of truth. Before starting any tracker item, verify-first against the repo (feature-dir phase + gh pr list/git log); an 'open' item with a complete feature dir or merged PR is stale-open -> close it, don't rebuild. Mechanize via the FW-NAMING convention (FIT-200): slug + state.json.linear_id + scheme-prefixed code; `make crosswalk` builds item-registry.json + advisory for missing joins. Never reuse a bare thematic number across schemes (DE-R14 vs TC-R9). Mark shipped->Done, duplicate->Canceled, permanently-blocked->Won't-Do, keep genuinely-overdue open. See observed-patterns.md W40. |
| `W43` | iOS SNAPSHOT_MODE must reach the simulator via the scheme's TestAction env (build-setting expansion), not a runner env var / SIMCTL_CHILD_ *(probed)* | no | Env vars set on the xcodebuild process or via SIMCTL_CHILD_* do not deterministically reach the app/test process inside the simulator under a normal test action. Add <EnvironmentVariable key=SNAPSHOT_MODE value=$(SNAPSHOT_MODE)> to the scheme LaunchAction (TestAction inherits via shouldUseLaunchSchemeArgsEnv=YES) AND pass SNAPSHOT_MODE=record as an xcodebuild build-setting so $(SNAPSHOT_MODE) expands. Symptom: record/verify job is green but 0 baselines committed / all snapshot tests XCTSkip (a ci-green-masks-a-noop no-op). See observed-patterns.md W43. |
| `W44` | A derived index with no scheduled producer rots silently; a stale index is indistinguishable from a fresh one *(probed)* | no | Any derived artifact (index, cache, aggregate) that is regenerated only by hand AND exposes no way to compare itself against its source will drift without announcing it — .claude/shared/item-registry.json sat at 118 items against a 132-feature corpus, missing both in-flight features. Give the artifact a content fingerprint (sha256 over its canonicalized derived payload, NOT a wall-clock generated_at — a timestamp churns the file and still doesn't prove the content matches), expose a --check verdict that exits non-zero when stale, and put the producer in a scheduled check. Here: `make crosswalk CHECK=1` (exit 3 = stale) + daily advisory N5 in scripts/daily-integrity-checkpoint.py. Symptom: a confidently-formatted derived JSON whose item count doesn't match a glob of its source. See observed-patterns.md W44. |
| `W45` | Signing-capable != auth-capable: SSH auth to GitHub fails while the Mac sleeps (locked keychain holds the sole auth key's passphrase); W1 stays green *(probed)* | no | Intermittent `git@github.com: Permission denied (publickey)` that reproduces only sometimes, while HTTPS to the same repo works at the same instant. Cause: the sole GitHub AUTH key is passphrase-protected and its passphrase lives in the login keychain, which is locked during macOS sleep/DarkWake; IdentitiesOnly yes + IdentityAgent none leave no fallback, and the agent's keys are signing-only (gh api user/ssh_signing_keys vs gh api user/keys). Hardware keys don't help — they need a touch. Check `pmset -g log` for a Sleep/DarkWake window at the failure time before suspecting config rot. Fix: `git config --global url."https://github.com/".insteadOf "git@github.com:"` (public-repo fetch needs no credential, survives sleep), or hold the decrypted key in an agent via `ssh-add --apple-use-keychain`. W1 does NOT cover this: it proves signing only. See observed-patterns.md W45. |

At activation run `make skill-preflight SKILL=dev` — probes the 12 mechanized blockers for this work type; clear any before proceeding.

**Mandatory** (CLAUDE.md §v7.8.5): any novel pattern surfaced this session MUST be appended to [`observed-patterns.md`](../../integrity/observed-patterns.md) before the feature closes — then re-run `make gen-skill-preflight`.
<!-- END pattern-preflight -->

## Shared Data

**Preflight cache:** `.claude/shared/preflight-cache.json` — refreshed by `make preflight WORK_TYPE=<feature|enhancement|fix|chore> [FEATURE=<name>]`. Run BEFORE any sub-command to get current work-context data (W1 ssh-agent, integrity findings, drift vs anchor, doc-debt, adoption baseline). Cache schema: `docs/skills/preflight-cache-schema.md`.

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
