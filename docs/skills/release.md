# `/release` — Release Management

> **Role in the ecosystem:** The shipping layer. Owns version bumps with semantic versioning, changelog generation, pre-release checklists, and App Store submission prep.

**Agent-facing prompt:** [`.claude/skills/release/SKILL.md`](../../.claude/skills/release/SKILL.md)

---

## What it does

Handles version bumps with semantic versioning, generates changelogs from git history and feature registry, runs pre-release checklists (11-point readiness check), and prepares App Store submission materials.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/release prepare` | Version bump + release notes | "Prepare v1.3.0 release" | Phase 7 (Merge) |
| `/release checklist` | Pre-release readiness | "Are we ready to submit?" | Phase 7 (Merge) |
| `/release notes` | Generate changelog | "Write release notes from recent commits" | Phase 7 (Merge) |
| `/release submit` | App Store submission prep | "Prepare App Store submission materials" | Post-Phase 8 |

## Shared data

**Reads:** `feature-registry.json` (what's in release), `test-coverage.json` (quality gates), `health-status.json` (CI ready).

**Writes:** `CHANGELOG.md` updates, version bump in Xcode project.

## 11-point readiness checklist

`/release checklist` runs before every submission:

1. CI green on main
2. All tests passing (including new analytics tests)
3. `make tokens-check` clean
4. No open P0/P1 bugs
5. Analytics instrumentation verified
6. Performance within guardrails (crash-free >99.5%, cold start <2s)
7. No PII leaks in the build
8. ASO metadata updated (for App Store submissions)
9. Screenshots current
10. Release notes written
11. `feature-registry.json` reflects shipped state

Any failed check blocks `/release submit`.

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 7 (Merge) | `/release checklist` + `/release prepare` |
| Post-Phase 8 (for App Store builds) | `/release submit` |

## Upstream / Downstream

- Reads quality gates from `/qa` (via `test-coverage.json`)
- Reads CI/infra status from `/ops` + `/dev` (via `health-status.json`)
- Reads feature list from `/pm-workflow` (via `feature-registry.json`)
- Reads analytics readiness from `/analytics`

## Standalone usage examples

1. **Release prep:** `/release prepare` → bumps version, generates notes, tags release
2. **Readiness check:** `/release checklist` → 11-point checklist: CI, tests, tokens, bugs, analytics, perf, PII, ASO, screenshots, notes, registry
3. **App Store:** `/release submit` → metadata checklist, privacy labels, review notes, TestFlight config

## Key references

- [`CHANGELOG.md`](../../CHANGELOG.md) — milestone history
- [`FitTracker.xcodeproj/project.pbxproj`](../../FitTracker.xcodeproj/project.pbxproj) — version fields
- [`docs/design-system/app-store-assets.md`](../design-system/app-store-assets.md) — App Store creative requirements

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §15
- [qa.md](qa.md), [dev.md](dev.md), [ops.md](ops.md) — gate inputs
- [pm-workflow.md](pm-workflow.md) — the hub that dispatches `/release`
- [`.claude/skills/release/SKILL.md`](../../.claude/skills/release/SKILL.md)
