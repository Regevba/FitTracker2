# Figma MCP Automation Process — Lessons Learned & Setup Guide

**Date:** 2026-03-31
**Project:** FitTracker Design System Library (`0Ai7s3fCFqR5JXDW8JvgmD`)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Three MCP Servers Available                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Official Figma Remote MCP (mcp.figma.com/mcp)              │
│     ├─ READ:  get_design_context, get_screenshot, get_metadata │
│     ├─ WRITE: variables, styles, component variants             │
│     ├─ FAILS: new frame creation (ephemeral plugin sandbox)    │
│     └─ Auth:  Figma OAuth via plugin install                    │
│                                                                 │
│  2. Official Figma Desktop MCP (localhost:3845/mcp)            │
│     ├─ READ:  same as remote                                    │
│     ├─ WRITE: variables, styles, Code Connect only             │
│     ├─ FAILS: frame/node creation (not supported)              │
│     └─ Auth:  runs inside Figma Desktop, Dev Mode required     │
│                                                                 │
│  3. figma-console-mcp (community, localhost:9223-9232)         │
│     ├─ READ:  full file inspection, variables, components      │
│     ├─ WRITE: EVERYTHING — frames, nodes, fills, text, layout  │
│     ├─ 57+ tools including figma_create_child, figma_execute   │
│     └─ Auth:  Desktop Bridge plugin via WebSocket              │
│                                                                 │
│  CONCLUSION: Only figma-console-mcp can create persistent      │
│  screen frames. Use it for P4 screen builds.                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## What Persists vs What Doesn't (Official MCP)

| Operation | Official Remote | Official Desktop | figma-console-mcp |
|---|---|---|---|
| Read file structure | ✅ | ✅ | ✅ |
| Read/create variables | ✅ Persists | ✅ Persists | ✅ Persists |
| Read/create text styles | ✅ Persists | ✅ Persists | ✅ Persists |
| Read/create effect styles | ✅ Persists | ✅ Persists | ✅ Persists |
| Create component variants | ✅ Persists | ❌ | ✅ Persists |
| Create new frames | ❌ Ephemeral | ❌ Not supported | ✅ Persists |
| Set fills/strokes | ❌ Ephemeral | ❌ | ✅ Persists |
| Set text content | ❌ Ephemeral | ❌ | ✅ Persists |
| Move/resize nodes | ❌ Ephemeral | ❌ | ✅ Persists |
| Auto-layout | ❌ Ephemeral | ❌ | ✅ Persists |

---

## figma-console-mcp Setup (Verified Working)

### Prerequisites
- Figma Desktop app (not browser)
- Node.js (via nvm or direct install)
- Claude Code CLI

### Step 1: Install figma-console-mcp
```bash
npm install -g figma-console-mcp
```

### Step 2: Clone the repo (for Desktop Bridge plugin)
```bash
git clone https://github.com/southleft/figma-console-mcp.git ~/figma-console-mcp
```

### Step 3: Import Desktop Bridge plugin into Figma
1. Open Figma Desktop
2. Plugins → Development → Import plugin from manifest...
3. Navigate to: `~/figma-console-mcp/figma-desktop-bridge/manifest.json`

**IMPORTANT:** If it doesn't work, the server copies a stable version to:
`~/.figma-console-mcp/plugin/manifest.json`
Import THAT manifest instead if the git version fails.

**CRITICAL:** If you imported before v1.10.0, you MUST re-import the manifest.
Figma caches plugin code at the application level — restarting alone won't reload it.

### Step 4: Add to Claude Code MCP config
```bash
cd ~/Downloads/FitTracker2
claude mcp add figma-console npx figma-console-mcp
```

### Step 5: Connection sequence (ORDER MATTERS)
```
1. Start Claude Code:     claude  (this launches figma-console-mcp automatically)
2. Open Figma Desktop:    Open your design file
3. Run Desktop Bridge:    Plugins → Development → Figma Desktop Bridge
4. Plugin auto-connects:  Scans ports 9223-9232 via WebSocket
```

### Step 6: Verify connection
In Claude Code, ask: `What figma tools do I have available?`
Should list 50+ tools from `mcp_figma-console__figma_*`

---

## Troubleshooting

### "WebSocket transport not available"
- The server is running but the plugin hasn't connected yet
- Close and re-open the Desktop Bridge plugin
- Make sure only ONE instance of figma-console-mcp is running
- If you started one manually AND Claude Code started one, kill the manual one

### Plugin shows "MCP ready" with pairing code but won't auto-connect
- The plugin is defaulting to Cloud Mode
- Pull latest: `cd ~/figma-console-mcp && git pull origin main`
- Re-import the manifest in Figma (forces code reload)
- Ensure server is running BEFORE opening the plugin

### Port conflicts (EADDRINUSE)
- Two instances trying to use port 9223
- Kill all: `pkill -f figma-console-mcp`
- Restart with only one instance (either manual OR Claude Code managed)
- Check ports: `lsof -i :9223` and `lsof -i :9224`

### "Cannot connect to Figma Desktop" / localhost:9222
- This error references the OLD CDP (Chrome DevTools Protocol) method
- CDP was removed by Figma — `--remote-debugging-port=9222` no longer works
- Ignore this error — the WebSocket bridge on 9223-9232 is the correct method

### Desktop Bridge connected but Claude Code shows "1 MCP server failed"
- Claude Code launched its OWN figma-console-mcp instance (e.g. port 9224)
- The plugin was connected to a DIFFERENT instance (port 9223)
- Fix: Kill the manual instance, close/re-open plugin, it will find Claude Code's instance

---

## What We Accomplished via MCP (Official Remote Server)

### P2b — Variable Collections (118 variables)
| Collection | Variables | Created/Verified |
|---|---|---|
| Color / Primitives | 19 | Created from AppPalette.swift |
| Color / Semantic | 46 (Light+Dark) | Consolidated from FitMe Tokens + old collection |
| Spacing | 9 | Verified match to AppSpacing |
| Radius | 9 | Verified match to AppRadius |
| Elevation | 6 | Verified match to AppShadow |
| Motion | 7 | Fixed 4 names to match AppDuration |
| Text / Roles | 22 | Verified match to AppText |

### P2c — Text Styles (22)
All verified against AppText.* — Nunito for rounded, IBM Plex Mono for monospaced.

### P2d — Effect Styles (2)
`elevation-card` and `elevation-cta` verified against AppShadow.

### P3 — Components (22 sets, 65 variants)
9 pre-existing + 13 created via use_figma.

### P4 — Screen Frames
Could NOT be created via official MCP (ephemeral).
Requires figma-console-mcp Desktop Bridge for persistent creation.

---

## Automation Process for Future Development

### When code changes affect the design system:

1. **Token changes** (AppTheme.swift, AppPalette.swift):
   - Use official Figma MCP `use_figma` to update variables
   - Run `make tokens-check` to verify pipeline sync
   - Update Figma variable values to match

2. **New component added** (AppComponents.swift, AppDesignSystemComponents.swift):
   - Use official Figma MCP `use_figma` to create component variants
   - Document in component-contracts.md

3. **Screen layout changes** (Views/*.swift):
   - Use figma-console-mcp (via Claude Code local) to update screen frames
   - Requires Desktop Bridge plugin running

4. **New screen added**:
   - Use figma-console-mcp to create the frame on the appropriate page
   - Follow p4-screen-build-manual.md spec format

### CI/CD Integration
```
Code change → make tokens-check (CI) → Figma sync (manual/MCP) → Screenshot verify
```

---

## Key File Locations (Mac)

| File | Path |
|---|---|
| figma-console-mcp repo | `~/figma-console-mcp/` |
| Desktop Bridge manifest | `~/figma-console-mcp/figma-desktop-bridge/manifest.json` |
| Stable plugin copy | `~/.figma-console-mcp/plugin/manifest.json` |
| Claude Code MCP config | `~/Downloads/FitTracker2/.claude.json` |
| Screen build manual | `docs/design-system/p4-screen-build-manual.md` |
| Approval process | `docs/design-system/approval-process.md` |
| Figma library progress | `docs/design-system/figma-library-progress.md` |
