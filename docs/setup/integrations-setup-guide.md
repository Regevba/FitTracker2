# FitMe Integrations Setup Guide

> Complete reference for every third-party integration in the FitMe project.
> Audience: anyone recreating the project from scratch or onboarding onto an existing clone.
> Date: 2026-04-09

---

## Table of Contents

1. [GitHub](#1-github)
2. [Supabase](#2-supabase)
3. [Firebase / Google Analytics (GA4)](#3-firebase--google-analytics-ga4)
4. [Vercel](#4-vercel)
5. [Claude Code](#5-claude-code)
6. [Figma MCP](#6-figma-mcp)
7. [Notion MCP](#7-notion-mcp)
8. [Design Token Pipeline (Style Dictionary)](#8-design-token-pipeline-style-dictionary)
9. [AI Engine (Docker / FastAPI)](#9-ai-engine-docker--fastapi)
10. [Apple CloudKit](#10-apple-cloudkit)
11. [SSD Development Environment](#11-ssd-development-environment)

---

## 1. GitHub

### What it is

Source control, CI/CD, issue tracking, and pull request workflow. The single source of truth for code and project management state.

### Repository

- **URL:** https://github.com/Regevba/FitTracker2
- **Owner:** `Regevba`
- **Default branch:** `main`

### GitHub Actions CI

A single workflow at `.github/workflows/ci.yml` runs on every push to `main` and every PR targeting `main`.

**Pipeline steps:**
1. Token pipeline — `npm install` + `make tokens-check` (design system drift detection)
2. Xcode build — `xcodebuild build` (iOS Simulator, no code signing)
3. Xcode test — `xcodebuild test` (XCTest suite)
4. On failure: uploads build/test logs as artifacts and comments error summary on the PR

**Runner:** `macos-15`

**Permissions required:** `contents: read`, `pull-requests: write`

### GitHub CLI (`gh`)

Used extensively by the PM workflow skills for issue management, label creation, milestone tracking, and PR operations.

**Setup:**
```bash
brew install gh
gh auth login          # follow browser-based OAuth flow
gh auth status         # verify: Logged in to github.com as Regevba
```

### Credentials / config locations

| Item | Location |
|------|----------|
| GitHub CLI auth token | `~/.config/gh/hosts.yml` (managed by `gh auth login`) |
| CI workflow | `.github/workflows/ci.yml` |
| GitHub Issues (PM state) | https://github.com/Regevba/FitTracker2/issues |
| Labels for PM workflow | 26 labels: 11 phase + 4 priority + 9 category + 2 spare |

---

## 2. Supabase

### What it is

Backend-as-a-service providing authentication (Apple Sign-In, Google Sign-In, email/password, passkeys) and real-time data sync for the iOS app.

### How it connects

The iOS app reads Supabase credentials from `Info.plist` at runtime:

| Info.plist key | Purpose |
|---|---|
| `SupabaseURL` | `https://<PROJECT_ID>.supabase.co` |
| `SupabaseAnonKey` | Public anon key for client-side auth |

The checked-in `Info.plist` contains placeholder values (`YOUR_PROJECT_ID`, `YOUR_SUPABASE_ANON_KEY`). Real values are set locally and never committed.

### Graceful degradation

`SupabaseClient.swift` detects missing/placeholder credentials and returns a stub client. The app builds and tests pass without real Supabase config. Auth and sync surfaces show a "not configured" message instead of crashing.

### Setup steps (recreating from scratch)

1. Go to https://supabase.com/dashboard and create a new project
2. Note the **Project URL** and **anon/public key** from Settings > API
3. Open `FitTracker/Info.plist` in Xcode
4. Replace `YOUR_PROJECT_ID` in `SupabaseURL` with your actual project ID
5. Replace `YOUR_SUPABASE_ANON_KEY` in `SupabaseAnonKey` with the anon key
6. Configure auth providers in Supabase Dashboard > Authentication > Providers:
   - Apple (requires Apple Developer account + Services ID)
   - Google (requires Google Cloud OAuth client)
   - Email/password (enabled by default)
7. Set up the passkey relying party ID to match `PasskeyRelyingPartyID` in Info.plist (`fittracker.regev.app`)

### Key source files

| File | Role |
|------|------|
| `FitTracker/Services/Supabase/SupabaseClient.swift` | Client initialization, credential validation, stub fallback |
| `FitTracker/Services/Supabase/SupabaseSyncService.swift` | Real-time data sync |
| `FitTracker/Services/Auth/SupabaseAppleAuthProvider.swift` | Apple Sign-In via Supabase |
| `FitTracker/Services/Auth/GoogleAuthProvider.swift` | Google Sign-In via Supabase |
| `FitTracker/Services/Auth/EmailAuthProvider.swift` | Email/password auth |
| `FitTracker/Services/Auth/SignInService.swift` | Auth orchestration |

### Credentials / config locations

| Item | Location |
|------|----------|
| Supabase URL + anon key | `FitTracker/Info.plist` (local only, placeholders in git) |
| Supabase Dashboard | https://supabase.com/dashboard |
| SPM dependency | `Supabase` package in `FitTracker.xcodeproj` Package Dependencies |

---

## 3. Firebase / Google Analytics (GA4)

### What it is

Analytics and event tracking for the iOS app. GA4 via Firebase SDK.

### Detailed setup

See the dedicated guide: [`firebase-setup-guide.md`](firebase-setup-guide.md) (20 steps, 30-45 minutes).

### Key points summary

- Firebase SDK added via SPM (`https://github.com/firebase/firebase-ios-sdk`)
- Linked frameworks: `FirebaseCore`, `FirebaseAnalytics`
- `GoogleService-Info.plist` is required for real analytics but NOT for builds or tests
- `GoogleService-Info.plist` is gitignored — each developer downloads their own from Firebase Console
- Auto screen reporting is disabled (`FirebaseAutomaticScreenReportingEnabled = NO` in Info.plist)
- Analytics respects GDPR consent flow — no events fire until user grants consent
- ATT (App Tracking Transparency) permission string is in Info.plist

### Graceful degradation

`AnalyticsRuntimeConfiguration.canUseFirebase` checks whether `GoogleService-Info.plist` exists at runtime. If missing, `FirebaseApp.configure()` is skipped. The app runs normally without analytics.

### Credentials / config locations

| Item | Location |
|------|----------|
| GoogleService-Info.plist | `FitTracker/GoogleService-Info.plist` (local only, gitignored) |
| Firebase Console | https://console.firebase.google.com |
| GA4 Dashboard | https://analytics.google.com |
| Bundle ID | `com.fittracker.regev` (verify in Xcode target settings) |
| Debug flag | `-FIRDebugEnabled` (Xcode launch argument) |

---

## 4. Vercel

### What it is

Hosting platform for two Astro web apps: the Development Dashboard and the marketing Website.

### Projects

| Project | Root directory | Framework | Vercel config |
|---------|---------------|-----------|---------------|
| Dashboard | `dashboard/` | Astro + React + Tailwind | `dashboard/vercel.json` |
| Website | `website/` | Astro + Tailwind | `website/vercel.json` |

### Dashboard setup

1. Go to https://vercel.com/new
2. Import `Regevba/FitTracker2`
3. Set **Root Directory** to `dashboard`
4. Framework preset: **Astro**
5. Build command: `npm run build`
6. Output directory: `dist`
7. Add environment variable `GITHUB_TOKEN` (PAT with `public_repo` scope) for live GitHub Issue fetching

### Website setup

Same import flow but set **Root Directory** to `website`. No environment variables needed.

### Automatic deploys

Both projects auto-deploy on push to `main`.

### Vercel Analytics

Enable in Vercel dashboard > Project > Analytics for page view and Web Vitals tracking. No code changes needed.

### Detailed activation guide

See [`dashboard-activation.md`](dashboard-activation.md) for the full post-launch activation walkthrough including GitHub Issues creation, scheduled rebuilds, and metrics review.

### Credentials / config locations

| Item | Location |
|------|----------|
| Vercel Dashboard | https://vercel.com (linked to GitHub account) |
| Dashboard vercel.json | `dashboard/vercel.json` |
| Website vercel.json | `website/vercel.json` |
| GITHUB_TOKEN env var | Vercel project settings > Environment Variables |
| Deploy hooks (optional) | Vercel project settings > Git > Deploy Hooks |

### Claude Code Vercel plugin

The Vercel plugin is enabled in Claude Code (see [Claude Code](#5-claude-code) section). It provides deployment status, env var management, and project bootstrapping skills directly in the CLI.

---

## 5. Claude Code

### What it is

Anthropic's CLI-based AI assistant, used as the primary development agent. Configured with project-specific permissions, hooks, MCP servers, and an ecosystem of skills.

### Configuration files

| File | Purpose |
|------|----------|
| `/Volumes/DevSSD/FitTracker2/.claude/settings.json` | Project-level permissions, hooks, additional directories |
| `/Volumes/DevSSD/FitTracker2/CLAUDE.md` | Project rules (PM lifecycle, design system, branching, CI, analytics) |
| `~/.claude/settings.json` | User-level permissions, enabled plugins, marketplace config |
| `~/.claude/projects/-Volumes-DevSSD-FitTracker2/` | Session data, memory, plugin state |

### Enabled plugins

| Plugin | Purpose |
|--------|---------|
| `swift-lsp` | Swift language server for code intelligence |
| `security-guidance` | Security review automation |
| `code-review` | PR code review |
| `commit-commands` | Git commit/push/PR workflows |
| `code-simplifier` | Code quality and refactoring |
| `serena` | Advanced code understanding |
| `superpowers` | Planning, brainstorming, TDD, parallel agents, worktrees |
| `figma` | Figma MCP integration (see [Figma MCP](#6-figma-mcp)) |
| `vercel-plugin` | Vercel deployment and management |

### Session start hook

On every new session, a hook runs that prints active PM workflow features and their current phases by reading `.claude/features/*/state.json`.

### MCP server permissions (project-level)

The project `.claude/settings.json` grants access to:
- **Figma MCP:** `get_metadata`, `search_design_system`
- **Notion MCP:** `notion-search`, `notion-fetch`, `notion-update-page`

### Skills ecosystem

The project has a comprehensive skills ecosystem documented in `docs/skills/`. Key skills:
- `/pm-workflow` — full product management lifecycle
- `/dev`, `/qa`, `/release` — development workflow
- `/ux`, `/design` — UX research and design system
- `/analytics` — event taxonomy and instrumentation
- `/research` — market and competitive research

See `docs/skills/README.md` for the full catalog.

### Setup (new machine)

1. Install Claude Code: follow https://docs.anthropic.com/en/docs/claude-code
2. Clone the repo to `/Volumes/DevSSD/FitTracker2`
3. Run `claude` from the repo root — it reads `CLAUDE.md` and `.claude/settings.json` automatically
4. Approve MCP server permissions when prompted (Figma, Notion)
5. Plugins install automatically based on `~/.claude/settings.json`

---

## 6. Figma MCP

### What it is

Model Context Protocol server that lets Claude Code read Figma designs, search the design system, and get component metadata directly from Figma files.

### Capabilities used

| Tool | Purpose |
|------|---------|
| `get_metadata` | Read Figma file/node metadata |
| `search_design_system` | Search design system components and variables |
| `get_design_context` | Extract design context for code generation |
| `get_screenshot` | Capture Figma node screenshots |

### Setup

The Figma MCP is provided by the `figma@claude-plugins-official` plugin. It activates automatically when:
1. The plugin is enabled in `~/.claude/settings.json` (already configured)
2. The user authenticates with Figma when first prompted

### Permissions

Project-level permissions in `.claude/settings.json`:
```
mcp__claude_ai_Figma__get_metadata
mcp__claude_ai_Figma__search_design_system
```

Additional tools (get_design_context, get_screenshot, etc.) require per-session approval.

### How it integrates

- UX/Design skills (`/ux`, `/design`) use Figma MCP to pull design specs
- The design token pipeline (Figma Variables > `tokens.json` > `DesignTokens.swift`) can be informed by Figma MCP reads
- V2 refactors reference Figma designs for pixel-accurate implementation

---

## 7. Notion MCP

### What it is

Model Context Protocol server that lets Claude Code search, read, and update Notion pages. Used for project documentation, meeting notes, and knowledge base management.

### Capabilities used

| Tool | Purpose |
|------|---------|
| `notion-search` | Search across the Notion workspace |
| `notion-fetch` | Read a specific Notion page or database |
| `notion-update-page` | Update page properties or content |

### Setup

The Notion MCP is a built-in Claude Code MCP server (`claude.ai/Notion`). It activates when:
1. The user authenticates with their Notion workspace when first prompted
2. Permissions are granted in the project `.claude/settings.json`

### Permissions

Project-level permissions in `.claude/settings.json`:
```
mcp__claude_ai_Notion__notion-search
mcp__claude_ai_Notion__notion-fetch
mcp__claude_ai_Notion__notion-update-page
```

---

## 8. Design Token Pipeline (Style Dictionary)

### What it is

Automated pipeline that converts design tokens from JSON to Swift code. Ensures the iOS app's design system stays in sync with the canonical token definitions.

### Pipeline flow

```
design-tokens/tokens.json  -->  Style Dictionary  -->  FitTracker/DesignSystem/DesignTokens.swift
```

### How it works

1. `design-tokens/tokens.json` — canonical token source (colors, spacing, radii)
2. `sd.config.js` — Style Dictionary config with custom Swift transforms and formatters
3. `make tokens` — regenerates `DesignTokens.swift` from `tokens.json`
4. `make tokens-check` — CI gate that fails if `DesignTokens.swift` is out of sync

### Setup

```bash
cd /Volumes/DevSSD/FitTracker2
npm install            # installs style-dictionary as a dev dependency
make tokens            # generates DesignTokens.swift
make tokens-check      # verifies sync (used in CI)
```

### Key files

| File | Purpose |
|------|---------|
| `design-tokens/tokens.json` | Canonical token definitions |
| `sd.config.js` | Style Dictionary config (custom transforms + Swift format) |
| `scripts/check-tokens.js` | CI verification script |
| `FitTracker/DesignSystem/DesignTokens.swift` | Generated output (committed to git) |
| `FitTracker/Services/AppTheme.swift` | ~125 semantic tokens consuming DesignTokens |
| `FitTracker/DesignSystem/AppComponents.swift` | 13 reusable components using tokens |
| `package.json` | Root-level npm config for style-dictionary |

### Dependencies

- Node.js 20+
- `style-dictionary` ^3.9.2 (npm dev dependency)

---

## 9. AI Engine (Docker / FastAPI)

### What it is

A Python-based FastAPI service for federated cohort intelligence. Containerized with Docker.

### Tech stack

- Python 3.12
- FastAPI + Uvicorn
- Pydantic v2 for settings/validation
- HTTPX for HTTP clients
- python-jose for JWT handling

### Project structure

```
ai-engine/
  app/          # FastAPI application source
  tests/        # pytest test suite
  Dockerfile    # Container definition
  pyproject.toml
```

### Local development setup

```bash
cd /Volumes/DevSSD/FitTracker2/ai-engine
python3.12 -m venv /Volumes/DevSSD/FitTracker2/.build/ai-venv
source /Volumes/DevSSD/FitTracker2/.build/ai-venv/bin/activate
pip install -e '.[dev]'
pytest -q                # run tests
uvicorn app.main:app --reload  # run locally on port 8000
deactivate
```

### Docker build

```bash
cd /Volumes/DevSSD/FitTracker2/ai-engine
docker build -t fittracker-ai .
docker run -p 8000:8000 fittracker-ai
```

### Deployment

The Dockerfile exposes port 8000. Deployment target is not yet configured (no Railway/Fly.io config files exist). The service is ready to deploy to any container hosting platform.

### CI integration

`make verify-ai` runs the pytest suite inside the local venv as part of the full `make verify-local` pipeline.

---

## 10. Apple CloudKit

### What it is

iCloud-based sync service as a secondary/fallback sync provider alongside Supabase.

### Key file

`FitTracker/Services/CloudKit/CloudKitSyncService.swift`

### Setup

CloudKit requires:
1. An Apple Developer account with the app's bundle ID registered
2. CloudKit container enabled in the Xcode target's Signing & Capabilities
3. CloudKit Dashboard access at https://icloud.developer.apple.com

CloudKit configuration is part of the Xcode project entitlements and does not require separate credential files.

---

## 11. SSD Development Environment

### What it is

All build artifacts, caches, and development data are stored on an external SSD at `/Volumes/DevSSD` to keep the Mac's internal disk clean.

### Detailed setup

See the dedicated guide: [`ssd-setup-guide.md`](ssd-setup-guide.md).

### Key redirects

| Item | SSD Location |
|------|-------------|
| Source code | `/Volumes/DevSSD/FitTracker2/` |
| Build artifacts | `/Volumes/DevSSD/FitTracker2/.build/` |
| Xcode DerivedData | `/Volumes/DevSSD/.xcode-shared/DerivedData/` |
| iOS Simulators | `/Volumes/DevSSD/.xcode-shared/CoreSimulator/` (symlink) |
| npm global cache | `/Volumes/DevSSD/.npm-cache/` |
| Homebrew cache | `/Volumes/DevSSD/.homebrew-cache/` |
| pip cache | `/Volumes/DevSSD/.pip-cache/` |
| AI engine venv | `/Volumes/DevSSD/FitTracker2/.build/ai-venv/` |

---

## Integration Dependency Map

```
                    GitHub (Regevba/FitTracker2)
                   /          |            \
                  /           |             \
           CI (Actions)    Issues/PRs    Source of truth
              |               |
         tokens-check     PM workflow
         build + test     (state.json + labels)
              |
              v
    +---------+---------+
    |         |         |
  Vercel    Vercel    Docker
 (dashboard) (website) (ai-engine)
    |
    +-- GITHUB_TOKEN env var

    iOS App (FitTracker.xcodeproj)
       |         |           |
    Supabase   Firebase    CloudKit
    (auth+sync) (analytics) (backup sync)
       |         |
   Info.plist  GoogleService-Info.plist

    Claude Code
       |       \        \
    Figma MCP  Notion MCP  Vercel Plugin
```

---

## Quick Reference: Where Secrets Live

**No secrets are committed to git.** All sensitive values are configured locally or in service dashboards.

| Secret | Where it lives | How to get it |
|--------|---------------|---------------|
| Supabase URL | `FitTracker/Info.plist` (local edit) | Supabase Dashboard > Settings > API |
| Supabase anon key | `FitTracker/Info.plist` (local edit) | Supabase Dashboard > Settings > API |
| GoogleService-Info.plist | `FitTracker/` (local file, gitignored) | Firebase Console > Project Settings > iOS app |
| GitHub PAT (dashboard) | Vercel env vars (`GITHUB_TOKEN`) | GitHub Settings > Developer Settings > PATs |
| GitHub CLI token | `~/.config/gh/hosts.yml` | `gh auth login` |
| Figma auth | Claude Code MCP (session-based) | Prompted on first use |
| Notion auth | Claude Code MCP (session-based) | Prompted on first use |
| Apple Developer certs | Xcode Signing & Capabilities | Apple Developer Portal |

---

## Bootstrap Checklist (New Machine)

Run these steps in order to get a fully working environment:

1. **Mount SSD** and verify `/Volumes/DevSSD` exists
2. **Clone repo:** `git clone https://github.com/Regevba/FitTracker2.git /Volumes/DevSSD/FitTracker2`
3. **SSD setup:** follow [`ssd-setup-guide.md`](ssd-setup-guide.md)
4. **Install tools:** Xcode 16+, Node 20+, Python 3.12+, `brew install gh`
5. **GitHub CLI:** `gh auth login`
6. **npm deps:** `cd /Volumes/DevSSD/FitTracker2 && npm install`
7. **Token pipeline:** `make tokens-check` (verify design tokens are in sync)
8. **Supabase (optional):** edit `FitTracker/Info.plist` with real credentials
9. **Firebase (optional):** follow [`firebase-setup-guide.md`](firebase-setup-guide.md), add `GoogleService-Info.plist`
10. **AI engine venv:** `cd ai-engine && python3.12 -m venv ../.build/ai-venv && source ../.build/ai-venv/bin/activate && pip install -e '.[dev]'`
11. **Dashboard deps:** `cd dashboard && npm install`
12. **Website deps:** `cd website && npm install`
13. **Full verify:** `make verify-local`
14. **Claude Code:** install CLI, run `claude` from repo root, approve MCP permissions
15. **Vercel (optional):** import repo at vercel.com, configure dashboard + website projects

After step 13 passes, you have a fully building and testing local environment. Steps 8-9 and 14-15 add optional integrations on top.

---

## See Also

- [`ssd-setup-guide.md`](ssd-setup-guide.md) — detailed SSD artifact setup
- [`firebase-setup-guide.md`](firebase-setup-guide.md) — 20-step Firebase/GA4 walkthrough
- [`dashboard-activation.md`](dashboard-activation.md) — Vercel dashboard activation
- [`../../CLAUDE.md`](../../CLAUDE.md) — project rules
- [`../../Makefile`](../../Makefile) — build targets
- [`../skills/README.md`](../skills/README.md) — skills ecosystem overview
