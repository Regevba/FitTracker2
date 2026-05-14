# GA4 MCP Setup Guide

**Audience:** operator (one-time setup) · **Created:** 2026-05-13 · **Updated:** 2026-05-14 (env var name corrected `GA4_PROPERTY_ID` → `GA_PROPERTY_ID`; absolute-path requirement for Claude Desktop documented) · **Phase:** analytics-observability 2.B.1 · **Status:** verified operational 2026-05-14 by operator (FIT-142)

> Companion to [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md) §6.2 Sub-system B. Once this guide is followed, the `/analytics poll` sub-command becomes operational and the audit's "GA4 MCP not connected" finding resolves to "connected".

---

## What this gets you

After completing this setup, you can:

1. **Run `/analytics poll`** in any Claude Code session to query the GA4 Realtime API and see events firing against the production FitMe property in real time
2. **Refresh `external-sync-status.json::sources.analytics.runtime_health`** automatically — `firebase` + `crash_free_rate` move from `unknown` to live values
3. **Cross-validate the local mirror** (Phase 2.A) against production by comparing local-tee output to GA4's Realtime view
4. **Unblock Phase 1.B `GA4_MCP_DISCONNECTED`** advisory gate — once connected, the gate stops firing

---

## Prerequisites

- Owner or Editor access to the FitMe Google Analytics 4 property
- A Google Cloud project (any project; can be a fresh one)
- Local Claude Code CLI authenticated and able to register MCP servers
- 15-30 minutes (most time is in Google Cloud Console clicking)

---

## Step 1 — Get your GA4 Property ID

1. Open [analytics.google.com](https://analytics.google.com)
2. Select the FitMe property
3. Admin (gear icon, lower-left) → Property Settings (under "Property" column)
4. Copy the **Property ID** (numeric, e.g. `123456789`) — NOT the Measurement ID (which starts with `G-`)

Save this as `GA_PROPERTY_ID` for Step 5.

---

## Step 2 — Create a Google Cloud service account

The MCP server needs Google API credentials. Service account = recommended (vs. OAuth) because it's headless, long-lived, and revocable.

1. Open [console.cloud.google.com](https://console.cloud.google.com)
2. Pick a project (or create one — name doesn't matter, e.g. `fitme-analytics-mcp`)
3. Enable the **Google Analytics Data API**:
   - Search for "Google Analytics Data API" in the top search bar
   - Click "ENABLE"
4. Open **IAM & Admin → Service Accounts** (sidebar)
5. Click **+ CREATE SERVICE ACCOUNT**
   - Name: `ga4-mcp-reader` (or similar)
   - Description: `Read-only access to FitMe GA4 property for mcp-server-ga4`
   - Skip the optional "grant access" steps (we grant access in GA4, not GCP)
6. Click **DONE**
7. Click into the new service account → **KEYS** tab → **ADD KEY → Create new key**
   - Key type: **JSON**
   - Click **CREATE** — a `.json` file downloads
8. Move the downloaded file to a permanent location, e.g.:
   ```sh
   mkdir -p ~/.config/ga4-mcp
   mv ~/Downloads/<some-project>-<some-hash>.json ~/.config/ga4-mcp/service-account.json
   chmod 600 ~/.config/ga4-mcp/service-account.json
   ```
9. Note the service account email (visible in IAM → Service Accounts column "Email"; format: `ga4-mcp-reader@<project-id>.iam.gserviceaccount.com`)

> **Security note:** the JSON file is the equivalent of a password for read access to GA4. Store it outside the repo (`~/.config/ga4-mcp/` is a good choice). Never commit it. The repo's `.gitignore` already excludes `*-service-account.json` patterns.

---

## Step 3 — Grant the service account read access to your GA4 property

GCP service accounts have no GA access by default — you must grant it inside Google Analytics:

1. Back in [analytics.google.com](https://analytics.google.com) → Admin → Property → **Property access management**
2. Click **+** (top-right) → **Add users**
3. Email address: paste the service account email from Step 2.9 (e.g. `ga4-mcp-reader@<project-id>.iam.gserviceaccount.com`)
4. Direct roles: **Viewer** (read-only is sufficient for `/analytics poll`)
5. Uncheck "Notify new users by email" (service accounts don't have inboxes)
6. Click **Add**

Verify: the service account should appear in the property access list with role "Viewer".

---

## Step 4 — Install `mcp-server-ga4`

The MCP server is a Node.js package. Install it globally so Claude Code can spawn it:

```sh
npm install -g mcp-server-ga4
```

Verify the install:

```sh
which mcp-server-ga4
mcp-server-ga4 --version
```

> If `npm install -g` requires sudo on your machine, prefer `npm install -g --prefix=~/.npm-global` and add `~/.npm-global/bin` to your PATH.

> **Alternative:** if `mcp-server-ga4` is not on npm yet, see the maintained fork at [github.com/harshfolio/mcp-server-ga4](https://github.com/harshfolio/mcp-server-ga4) for build-from-source instructions.

---

## Step 5 — Register the MCP server with Claude Code

Add the server to your Claude Code MCP configuration. **There are two separate configs depending on which interface you use:**

- **Claude Code CLI (terminal):** use `claude mcp add` — modifies `~/.claude.json` (preferred for analytics-skill work since `/pm-workflow`, `/analytics`, etc. run in CLI)
- **Claude Desktop (macOS app):** edit `~/Library/Application Support/Claude/claude_desktop_config.json`

> ⚠️ **`claude mcp list` and `/mcp` inside a Claude Code CLI session read the CLI config (`~/.claude.json`), not the Claude Desktop one.** They are completely separate configs that don't share state.

### Option A — Claude Code CLI (recommended)

One-line command (substitute your real Property ID and binary path):

```bash
claude mcp add ga4 \
  --env GA_PROPERTY_ID=123456789 \
  --env GOOGLE_APPLICATION_CREDENTIALS=/Users/YOU/.config/ga4-mcp/service-account.json \
  -- /Users/YOU/.nvm/versions/node/vXX.X.X/bin/mcp-server-ga4
```

The binary path after `--` should be the output of `which mcp-server-ga4` (Step 4). **Use absolute path** — nvm-managed binaries are not on the GUI app's PATH and the CLI's spawn behavior is more reliable with the absolute path too.

After running, verify:

```bash
claude mcp list
```

`ga4: ... - ✓ Connected` should appear in the list.

> ⚠️ **Currently-running Claude Code CLI sessions won't see the new server.** `claude mcp add` writes the config but running sessions only load MCP servers at boot. Exit (`exit`) + relaunch (`claude`) any active session before `/mcp` inside Claude Code will show `ga4`.

### Option B — Claude Desktop config (parallel; for Claude Desktop app users)

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` and add (or merge) this top-level `mcpServers` block:

```json
{
  "mcpServers": {
    "ga4": {
      "command": "/Users/YOU/.nvm/versions/node/vXX.X.X/bin/mcp-server-ga4",
      "args": [],
      "env": {
        "GA_PROPERTY_ID": "123456789",
        "GOOGLE_APPLICATION_CREDENTIALS": "/Users/YOU/.config/ga4-mcp/service-account.json"
      }
    }
  }
}
```

Replace:

- `/Users/YOU/.nvm/versions/node/vXX.X.X/bin/mcp-server-ga4` with the absolute output of `which mcp-server-ga4` (Step 4). **Must be absolute** — Claude Desktop is a GUI app and does NOT inherit your shell PATH; relative `"mcp-server-ga4"` will fail validation with a "could not be loaded" popup.
- `123456789` with your Property ID from Step 1
- `/Users/YOU/.config/ga4-mcp/service-account.json` with the absolute path from Step 2.8

Then **fully quit Claude Desktop** (`osascript -e 'quit app "Claude"'` or Cmd+Q in the app) and reopen (`open -a Claude`). MCP servers only register on app launch — closing the window is not enough.

> **Why two env vars?** `GA_PROPERTY_ID` tells the server which property to query. `GOOGLE_APPLICATION_CREDENTIALS` is the standard Google SDK env var pointing at the service account JSON.

---

## Step 6 — Verify connectivity

In a Claude Code session:

```
/mcp ga4
```

Expected: the GA4 server should appear in the connected list. If you see `disconnected` or auth errors, check:

1. Path to service account JSON is absolute and the file is readable
2. Service account has Viewer access to the GA4 property (Step 3)
3. Google Analytics Data API is enabled in the GCP project (Step 2.3)
4. Property ID is the numeric ID, not the `G-` Measurement ID

Then run:

```
/analytics poll
```

Expected output (when GA4 has recent traffic):

```
GA4 Realtime — last 30 minutes (property 123456789)
  active users: 7
  events:
    home_action_tap          12
    nutrition_meal_logged     5
    training_session_started  3
    ...
```

---

## Step 7 — Update `external-sync-status.json`

Once connected, refresh the analytics block to reflect the live status:

```sh
python3 scripts/refresh-external-sync-status.py --section analytics
```

Or manually edit `.claude/shared/external-sync-status.json` and set:

```json
"sources.analytics.runtime_health.firebase": "connected"
"sources.analytics.analytics_taxonomy_status.ga4_mcp_connected": true
```

This closes the audit finding from 2026-05-13 ("GA4 MCP defined but not connected").

---

## Troubleshooting

### "PERMISSION_DENIED" or "403 Forbidden" from the API

The service account lacks access. Re-do Step 3 — grant Viewer role to the service-account email inside the GA4 property's Access Management.

### "API has not been used in project X before or it is disabled"

Re-do Step 2.3 — enable the **Google Analytics Data API** (not the Reporting API or Management API; specifically the Data API).

### MCP server doesn't appear in `/mcp` list

- Check the `.mcp.json` is in the right location for your Claude Code variant
- Check that `mcp-server-ga4` is on PATH (`which mcp-server-ga4`)
- Check Claude Code logs for spawn errors

### `/analytics poll` returns 0 events

Either GA4 has no recent traffic (try opening the iOS app or fitme-story dev server in a different terminal), or the wrong property ID is configured. Verify against Realtime view in the analytics.google.com UI.

### Service account credentials expired or compromised

1. In GCP Console → IAM → Service Accounts → click the service account → KEYS
2. **DELETE** the old key
3. Create a new one (Step 2.7)
4. Replace the JSON file at `~/.config/ga4-mcp/service-account.json`
5. Restart Claude Code

---

## Cross-references

- Phase 2.B.1 spec: [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md) §6.2
- GA4 MCP adapter description: [`.claude/integrations/ga4/adapter.md`](../../.claude/integrations/ga4/adapter.md)
- `/analytics poll` SKILL.md section: [`.claude/skills/analytics/SKILL.md`](../../.claude/skills/analytics/SKILL.md) `/analytics poll`
- Audit finding (origin): [`docs/master-plan/analytics-observability-decisions-log-2026-05-13.md`](../master-plan/analytics-observability-decisions-log-2026-05-13.md) §2.3 ("GA4 MCP is configured but NOT connected")
- Companion local-mirror sink (alternative dev observability): [`scripts/analytics-watch-server.py`](../../scripts/analytics-watch-server.py) (Phase 2.A.1)
