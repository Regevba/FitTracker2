# Control-Room Analytics Setup Guide

**Audience:** operator (one-time setup) · **Created:** 2026-05-14 · **Phase:** analytics-observability 3.A

> Companion to [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md) §7.1 Sub-system A and the in-app `/control-room/analytics` route shipped in `fitme-story` (PR TBD). After completing this guide, operators have a passkey-gated dashboard that surfaces event volume, drift trend, and taxonomy health.

---

## What this gets you

After completing this setup, you can:

1. Open `https://fitme-story.vercel.app/control-room/analytics` in a browser
2. Authenticate via passkey (existing UCC auth flow; no new credentials)
3. See live event firing rate, CSV drift trend, taxonomy health %, and the last 30 minutes of GA4 events

---

## Prerequisites

- UCC passkey enrolled (per [UCC passkey auth setup guide](ucc-passkey-auth-setup-guide.md))
- GA4 MCP configured (per [GA4 MCP setup guide](ga4-mcp-setup-guide.md)) — required only for the live-data tiles (Tile 1 EventVolumeTile, Tile 4 RecentEventsStream)
- 5-10 minutes

---

## Calibration window note (2026-05-14 → 2026-06-04)

During the Phase 1.B Calibration Protocol soak window, the in-app dashboard ships with **fixture-rendered tiles only** for the GA4-backed metrics (Tile 1, Tile 4). The static tiles (Tile 2 DriftTrendTile, Tile 3 TaxonomyHealthTile, Tile 5 ForwardDeclaredEventsTile) DO show live data because they read static files (CSV + sync-status JSON), not GA4.

After 2026-06-04 the GA4-backed tiles are wired live in a follow-up PR. See master plan §7.5 (calibration safety classification) for why this split exists.

---

## Step 1 — Verify the route deploys

1. Push this PR; Vercel auto-deploys a preview URL
2. Open `https://<preview-url>/control-room/analytics` in a browser
3. Expected: passkey prompt → after auth, the route loads in <3s with all 5 tiles visible

If the route 404s: check `fitme-story/src/app/control-room/analytics/page.tsx` exists in the deployed branch + check `fitme-story/next.config.ts` route configuration.

---

## Step 2 — Verify the static tiles render real data

The static tiles read source files at request time:

- **Tile 2 DriftTrendTile** reads `.claude/shared/external-sync-status.json::sources.analytics.analytics_taxonomy_status.drift_count`. Expected: shows "0" with a green band (current state).
- **Tile 3 TaxonomyHealthTile** runs `python3 scripts/cross-reference-analytics-enum-csv.py --json`. Expected: shows ≥95% with a green scorecard.
- **Tile 5 ForwardDeclaredEventsTile** reads `docs/product/analytics-taxonomy.csv` filtered to `[FORWARD-DECLARED]` Notes. Expected: shows 2 entries (`design_system_component_expand`, `design_system_code_copy`).

If any static tile shows "Error fetching": check the Vercel function logs (`vercel logs <deployment-url>`).

---

## Step 3 — Verify the GA4-backed tiles show fixture data (calibration window)

During 2026-05-14 → 2026-06-04, Tile 1 + Tile 4 render fixture data (deterministic, hand-authored). The fixture data is in `fitme-story/src/lib/control-room/analytics-fixtures.ts`.

Expected: each tile shows a "Fixture data — live binding deferred to 2026-06-04" badge in the corner. After 2026-06-04 this badge disappears once live binding ships.

---

## Step 4 — (Post-2026-06-04) verify live GA4 binding

Once the live-binding PR ships:

1. Confirm `GA4_PROPERTY_ID` + `GOOGLE_APPLICATION_CREDENTIALS` env vars are set on Vercel (Settings → Environment Variables, both Production and Preview)
2. Confirm the GA4 service account has Viewer access to the FitMe property (per GA4 MCP setup guide Step 3)
3. Open the dashboard in a browser
4. Tile 1 EventVolumeTile should show today's live event count (compare against GA4 web UI Realtime view as ground truth)
5. Tile 4 RecentEventsStream should show events from the last 30 minutes; firing a test event from the iOS app should appear within ~1 minute

---

## Troubleshooting

### Passkey prompt fails to load

- Verify UCC auth flow is configured (`UCC_AUTH_MODE=passkey` env var on Vercel)
- Check browser supports WebAuthn (Chrome, Safari, Firefox modern versions all do)

### Static tile shows "Error fetching"

- Check Vercel function logs via `vercel logs <deployment-url>`
- Most common cause: source file path not included in the deployed bundle
- Workaround: ensure `next.config.ts` `outputFileTracingIncludes` covers the relevant paths

### GA4 tile shows "0 events" but app is firing events

- Check the GA4 property ID matches what the iOS app is sending to (verify in `Info.plist` or `GoogleService-Info.plist`)
- GA4 has a 24-48 hour aggregation lag for the standard Reporting API; for live verification use the Realtime API (Tile 4)
- Verify the service account has Viewer access (re-do GA4 MCP setup guide Step 3)

---

## Cross-references

- Master plan §7.1: [`../master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md)
- Metric definitions: [`../master-plan/analytics-dashboard-metric-definitions.md`](../master-plan/analytics-dashboard-metric-definitions.md)
- Looker alternative: [`../analytics/looker-studio-template.md`](../analytics/looker-studio-template.md)
- GA4 MCP prerequisite: [`ga4-mcp-setup-guide.md`](ga4-mcp-setup-guide.md)
- UCC passkey prerequisite: [`ucc-passkey-auth-setup-guide.md`](ucc-passkey-auth-setup-guide.md)
- Calibration safety classification: master plan §7.5
