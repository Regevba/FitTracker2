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

## Key references

- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — CI pipeline
- [`CLAUDE.md`](../../CLAUDE.md) — branching strategy, high-risk files list
- [`Makefile`](../../Makefile) — token + build targets

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §8
- [qa.md](qa.md), [release.md](release.md) — downstream partners
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/dev/SKILL.md`](../../.claude/skills/dev/SKILL.md)
