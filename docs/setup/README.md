# Setup Guides

> Step-by-step guides for one-time environment, tooling, and service setup. Everything here is "run this once when bootstrapping a new machine / new dev / new service" — not for active product work.

---

## What goes here

- **Machine / environment setup** — SSD layout, paths, shell config
- **Service setup** — Firebase, Supabase, GitHub Actions secrets, Vercel env vars
- **Tooling setup** — Xcode schemes, simulator config, MCP server setup
- **One-time activation** — enabling a service, wiring a new integration, first-run checklists

## What doesn't go here

- Daily workflow docs — those live in `docs/skills/` or `docs/master-plan/`
- Build prompts for other agents — `docs/prompts/`
- Feature PRDs — `docs/product/prd/`
- Changelogs / version history — `CHANGELOG.md`

A setup guide is something you read once per environment. A workflow doc is something you read every time you use the workflow. If the doc has "daily use" or "every feature" in it, it's not a setup guide.

## Current contents

| File | Purpose | When to run |
|---|---|---|
| `ssd-setup-guide.md` | Move build artifacts (DerivedData, SPM cache, npm cache, venv, homebrew) to the external SSD. Covers Xcode preferences, Homebrew env vars, Makefile overrides. | Once per machine, after attaching the SSD |
| `firebase-setup-guide.md` | 20-step walkthrough for the Firebase Analytics (GA4) integration: console project, `GoogleService-Info.plist` placement, SDK linking, first event verification | Once per dev, before running analytics tests or release builds |
| `dashboard-activation.md` | Wire up the Development Dashboard on Vercel: env vars (`GITHUB_TOKEN`, `DASHBOARD_WRITE_TOKEN`, `PUBLIC_DASHBOARD_WRITE_TOKEN`), deployment protection, first build verification | Once per Vercel project, before the dashboard goes live |
| `integrations-setup-guide.md` | Comprehensive reference for ALL third-party integrations: GitHub, Supabase, Firebase/GA4, Vercel, Claude Code, Figma MCP, Notion MCP, Style Dictionary token pipeline, AI engine, CloudKit, SSD setup. Includes dependency map, secrets locations, and bootstrap checklist. | Once per machine, as a master reference alongside the individual guides |
| `auth-runtime-verification-playbook.md` | 7-step manual checklist for validating real Supabase + Google auth flows against the Staging build path. Pairs with `Config/Local/Staging.xcconfig` + `make runtime-smoke PROFILE=sign_in_surface MODE=staging`. Required to promote auth from `compile-verified` to `runtime-verified`. | Before any release that touches auth; last-mile of Gemini audit Tier 2.1 |

## How to use this folder

**Bootstrapping a fresh clone:**
1. Read `ssd-setup-guide.md` to decide where build artifacts go
2. Read `firebase-setup-guide.md` if you need analytics — add the plist locally
3. Read `dashboard-activation.md` if you're deploying the dashboard
4. Run `make verify-local` once everything's wired

**Writing a new setup guide:**
1. Use a numbered step-by-step format (one-line per step where possible)
2. State the prerequisites explicitly at the top
3. State the verification steps at the bottom ("how do I know this worked?")
4. Link out to official docs for the underlying service
5. Include a troubleshooting section for the most common failure modes

## Related documents

- [`../../Makefile`](../../Makefile) — `make verify-local`, `make tokens-check`, `make verify-ios` targets
- [`../../CLAUDE.md`](../../CLAUDE.md) — project rules, including CI requirements
- [`../skills/ops.md`](../skills/ops.md) — the `/ops` skill for runtime health checks after setup is complete
- [`../../scripts/check-ssd-setup.sh`](../../scripts/check-ssd-setup.sh) — machine-readable SSD-setup verification
