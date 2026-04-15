# Sentry Error Tracking — Setup Guide

> **Priority:** High (pre-launch blocker)
> **Adapter location:** `.claude/integrations/sentry/`
> **Consuming skills:** /ops, /cx, /qa

## Why Sentry?

The `crash_free_rate` guardrail (>99.5%) in `health-status.json` currently shows `null` — there's no crash reporting wired. Sentry fills this gap and feeds real data to three skills:
- `/ops health` — crash-free rate, error counts, top issues
- `/cx analyze` — crash-correlated user impact signals
- `/qa security` — error regression detection

## Step 1: Create Sentry Project

1. Sign up at [sentry.io](https://sentry.io) (free tier: 5K errors/month)
2. Create a new project: **Platform = Apple (iOS)**, **Project name = FitMe**
3. Note the **DSN** (Data Source Name) — looks like `https://abc123@o456.ingest.sentry.io/789`

## Step 2: Add Sentry SDK to Xcode

Add via SPM (Swift Package Manager):

1. In Xcode: File → Add Package Dependencies
2. URL: `https://github.com/getsentry/sentry-cocoa.git`
3. Version: Up to Next Major (currently 8.x)
4. Add `Sentry` framework to the FitTracker target

Initialize in `FitTrackerApp.swift`:

```swift
import Sentry

@main
struct FitTrackerApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "YOUR_DSN_HERE"  // from Step 1
            options.tracesSampleRate = 1.0  // 100% for now, reduce at scale
            options.profilesSampleRate = 1.0
            options.enableAutoSessionTracking = true  // required for crash-free rate
            options.attachScreenshot = true
            options.enableUserInteractionTracing = true
            
            #if DEBUG
            options.debug = true
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
        }
    }
    // ... existing body
}
```

**Important:** `enableAutoSessionTracking = true` is required for crash-free rate computation. Without it, Sentry reports error counts but not the crash-free percentage.

## Step 3: Generate Auth Token for MCP

1. Go to Sentry → Settings → Auth Tokens
2. Create a new token with scopes: `project:read`, `event:read`, `org:read`
3. Save as environment variable:

```bash
# Add to ~/.zshrc or .env
export SENTRY_AUTH_TOKEN="sntrys_YOUR_TOKEN_HERE"
export SENTRY_ORG_SLUG="your-org-slug"
export SENTRY_PROJECT_SLUG="fitme"
```

## Step 4: Connect Sentry MCP

The Sentry hosted MCP is available at `https://mcp.sentry.dev`. Add to Claude Code MCP config:

```json
{
  "mcpServers": {
    "sentry": {
      "url": "https://mcp.sentry.dev/sse",
      "env": {
        "SENTRY_AUTH_TOKEN": "sntrys_YOUR_TOKEN_HERE"
      }
    }
  }
}
```

## Step 5: Verify Integration

After setup, run `/ops health` — it should now pull real data from Sentry via the adapter:

```
Sentry MCP → schema.json (validate) → mapping.json (normalize) → validation gate → health-status.json
```

Expected fields populated:
- `quality_gates.crash_free_rate.current` — real percentage
- `error_tracking.error_count` — total errors in period
- `error_tracking.top_issues` — top 5 unresolved issues
- `error_tracking.affected_users` — unique users with errors

## Step 6: Set Up Alerts in Sentry Dashboard

Recommended alert rules:

| Alert | Condition | Action |
|---|---|---|
| Crash spike | >5 crashes in 1 hour | Email + Slack |
| New issue regression | Previously resolved issue reappears | Email |
| Error rate spike | Error count >2x baseline | Email |
| Crash-free rate drop | Below 99.0% (our P0 threshold) | Email + Slack |

## Cost

| Tier | Errors/month | Price |
|---|---|---|
| Developer (free) | 5,000 | $0 |
| Team | 50,000 | $26/month |
| Business | 100,000+ | $80+/month |

For a pre-launch solo-dev project, the free tier is sufficient. Upgrade when daily active users exceed ~1,000.

## Adapter Contract

The adapter at `.claude/integrations/sentry/` handles all normalization:
- `adapter.md` — how to call the MCP tools
- `schema.json` — expected response shape validation
- `mapping.json` — Sentry field names → shared layer field names

If Sentry changes its MCP API, update the adapter files — no skill changes needed.
