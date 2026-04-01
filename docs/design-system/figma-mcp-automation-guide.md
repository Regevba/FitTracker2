# Figma MCP Automation Guide — Lessons Learned

**Date:** 2026-03-31
**Project:** FitTracker Design System

---

## Architecture Overview

```
Claude Code (local Mac) → figma-console-mcp → WebSocket:9223 → Desktop Bridge Plugin → Figma Desktop
                                                                        ↓
                                                              Persistent frame creation ✅
                                                              Variable binding ✅
                                                              Component instantiation ✅
```

---

## Two MCP Servers — Different Capabilities

### 1. Official Figma MCP (Remote)
- **URL:** `https://mcp.figma.com/mcp`
- **What persists:** Variables, text styles, effect styles, component variants
- **What doesn't persist:** New frames/nodes created via `use_figma` Plugin API
- **Best for:** Token sync, style management, reading designs, screenshots
- **Setup:** Built into Figma, auto-configured when you have the Figma MCP plugin

### 2. figma-console-mcp (Community — Southleft)
- **URL:** localhost WebSocket on ports 9223-9232
- **What persists:** EVERYTHING — frames, nodes, text, fills, strokes, layout
- **Best for:** Building full screen layouts, creating frames programmatically
- **Setup:** Requires Desktop Bridge plugin + local server
- **GitHub:** https://github.com/southleft/figma-console-mcp

---

## Setup Process (Verified Working — 2026-03-31)

### Prerequisites
- Figma Desktop app (not browser)
- Node.js (via nvm or direct install)
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)

### Step 1: Install figma-console-mcp
```bash
npm install -g figma-console-mcp
```

### Step 2: Clone the repo (for Desktop Bridge plugin)
```bash
git clone https://github.com/southleft/figma-console-mcp.git ~/figma-console-mcp
```

### Step 3: Start the MCP server FIRST
```bash
npx figma-console-mcp
```
Wait for: `WebSocket bridge server started` on port 9223.

### Step 4: Import the Desktop Bridge plugin in Figma
1. Open Figma Desktop
2. Open your design file
3. Plugins → Development → Import plugin from manifest
4. Navigate to: `~/figma-console-mcp/figma-desktop-bridge/manifest.json`

**CRITICAL:** If you imported before, re-import to get the latest multi-port scanning code. Figma caches plugin files at the application level.

### Step 5: Run the Desktop Bridge plugin
Plugins → Development → Figma Desktop Bridge

**Verify in Terminal:** You should see:
```
Desktop Bridge plugin connected via WebSocket
fileKey: "YOUR_FILE_KEY"
fileName: "YOUR_FILE_NAME"
```

### Step 6: Add to Claude Code
```bash
cd ~/your-project
claude mcp add figma-console npx figma-console-mcp
```

### Step 7: Launch Claude Code
```bash
claude
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "WebSocket transport not available" | Plugin isn't connected to server | Stop server → close plugin → start server first → then open plugin → re-import manifest if still failing |
| "1 MCP server failed" in Claude Code | Port conflict — another instance running | Kill the other instance (Ctrl+C), let Claude Code manage its own |
| Plugin shows "MCP ready" with pairing code | Plugin can't find local server | Verify server running (`lsof -i :9223`), re-import manifest, ensure server started BEFORE plugin |
| `--remote-debugging-port` doesn't work | Figma blocked CDP access | Not needed. Desktop Bridge uses WebSocket directly |
| `claude` command not found | npm global bin not in PATH | Use full path: `$(npm root -g)/../bin/claude` or `npx @anthropic-ai/claude-code` |
| Claude Code shows `quote>` | Multi-line input mode | Press Ctrl+C to cancel, relaunch |

---

## What Persists vs What Doesn't

### Official Figma MCP (`use_figma`)
| Operation | Persists? |
|---|---|
| Create/modify variables | ✅ |
| Create/modify text styles | ✅ |
| Create/modify effect styles | ✅ |
| Create/modify component variants | ✅ |
| Create new frames on canvas | ❌ |
| Modify existing frame properties | ✅ |

### figma-console-mcp (Desktop Bridge)
| Operation | Persists? |
|---|---|
| Everything | ✅ |

---

## Integration into Development Workflow

### When to use which server

1. **Token/style sync (P2):** Official Figma MCP — faster, always connected
2. **Component building (P3):** Official Figma MCP — component variants persist
3. **Screen building (P4):** figma-console-mcp — only way to create persistent frames
4. **QA/verification (P5):** Official Figma MCP — screenshots and variable audits
5. **Code Connect mapping:** Official Figma MCP — dedicated Code Connect tools

### 50+ figma-console-mcp Tools (grouped)

**File:** `figma_get_status`, `figma_list_open_files`, `figma_get_file_data`
**Variables:** `figma_create_variable`, `figma_create_variable_collection`, `figma_update_variable`, `figma_batch_create_variables`, `figma_setup_design_tokens`
**Components:** `figma_instantiate_component`, `figma_search_components`, `figma_get_library_components`, `figma_analyze_component_set`
**Styles:** `figma_get_styles`, `figma_set_fills`, `figma_set_strokes`, `figma_set_image_fill`, `figma_lint_design`
**Nodes:** `figma_create_child`, `figma_clone_node`, `figma_delete_node`, `figma_move_node`, `figma_resize_node`, `figma_set_text`, `figma_set_instance_properties`
**Screenshots:** `figma_take_screenshot`, `figma_capture_screenshot`
**Navigation:** `figma_navigate`, `figma_reconnect`
