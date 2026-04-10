# `/dev` — Development Workflow

> **Role in the ecosystem:** The build layer. Owns branching strategy, code review checklists, dependency health, performance profiling, and CI status.

**Agent-facing prompt:** [`.claude/skills/dev/SKILL.md`](../../.claude/skills/dev/SKILL.md)

---

## What it does

Manages branching strategy, runs code review checklists (flagging high-risk files and security issues), checks dependency health, profiles performance, and monitors CI status.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/dev branch {feature}` | Create correctly-named branch | "Create a feature branch for push-notifications" | Phase 4 (Implement) |
| `/dev review` | Code review checklist | "Review my current diff for security and perf issues" | Phase 6 (Review) |
| `/dev deps` | Dependency health check | "Are there any vulnerable dependencies?" | Phase 4 (Implement) |
| `/dev perf` | Performance profiling | "Profile cold start and main thread blockers" | Phase 4 (Implement) |
| `/dev ci-status` | CI pipeline status | "What's the current CI status?" | Phase 7 (Merge) |

## Shared data

**Reads:** `feature-registry.json` (features in flight), `test-coverage.json` (coverage), `health-status.json` (CI status).

**Writes:** `health-status.json` (build status, CI).

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 4 (Implement) | `/dev branch` for branch setup |
| Phase 6 (Review) | `/dev review` for code review |
| Phase 7 (Merge) | `/dev ci-status` for merge readiness |

## Upstream / Downstream

- Reads test coverage from `/qa` (via `test-coverage.json`)
- Writes CI status consumed by `/release` (via `health-status.json`)
- Receives functionality bug dispatches from `/cx` when root cause = bug

## Standalone usage examples

1. **Branch creation:** `/dev branch push-notifications` → Creates `feature/push-notifications` from main
2. **Pre-PR review:** `/dev review` → Scans diff for high-risk file changes, security issues, perf problems
3. **Dependency audit:** `/dev deps` → Checks SPM + npm for vulnerabilities and updates

## Recent usage

- **5 features branched and merged** through the PM lifecycle: Home v2 (#61), Onboarding retro (#63), Body Composition (#65), Metric Deep Link (#67), Training v2 (#74).
- **v2/ subdirectory convention** validated at scale — multiple v2/ splits within one feature branch, project.pbxproj swaps automated.
- **Parallel task dispatch** — `/dev branch` + implementation tasks ran concurrently with `/design` and `/analytics` tasks during Phase 4.
- **Code review** ran on all 5 PRs via `/dev review`, flagging high-risk file changes in DomainModels.swift and AnalyticsProvider.swift.

## Key references

- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — CI pipeline
- [`CLAUDE.md`](../../CLAUDE.md) — branching strategy, high-risk files list
- [`Makefile`](../../Makefile) — token + build targets

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §8
- [qa.md](qa.md), [release.md](release.md) — downstream partners
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/dev/SKILL.md`](../../.claude/skills/dev/SKILL.md)

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| github | CLI (already connected) | PR management, branch operations, CI status, issue labels, code review automation |
| security-audit | MCP (`mcp-security-audit`) | OWASP Mobile Top 10 checks, dependency vulnerability scans, secrets detection |

**Adapter config:** `.claude/integrations/github/` and `.claude/integrations/security-audit/`

All incoming data passes through the **automatic validation gate**:

- GREEN (>= 95%): clean, auto-written
- ORANGE (90-95%): minor discrepancies, written with advisory
- RED (< 90%): blocked, user must resolve

Validation is automatic. Resolution is always manual.

### Learning Cache

**Location:** `.claude/cache/dev/`

Caches: branching patterns (feature vs. fix vs. chore naming, branch-from conventions), security baselines (prior audit results per module), CI fix patterns (recurring build failures and their resolutions).

On start: check cache for matching task signature, load learned patterns.
On complete: extract new patterns, write to L1 cache. Flag cross-skill patterns for L2 promotion.
