# GA4 Anomaly Check — Daily Operator Checklist

> **Tracked as:** B3 in [`.claude/shared/must-have-cadence-followups.md`](../shared/must-have-cadence-followups.md)
> **Cadence:** Daily, operator-run (no automation yet)
> **Owner:** Operator + GA4 MCP
> **Source:** `analytics-observability` epic (active feature, Phase 1.A shipped)

This checklist exists because there is **no scheduled GA4 anomaly job today** and GA4 only became MCP-queryable on 2026-05-14 (FIT-142). Until the automation lands (`/analytics watch` daily routine), the operator runs the queries below at the start of each working session and writes any anomaly to the `analytics-observability` feature log.

---

## Pre-flight (≤30 seconds)

1. **MCP connection check** — invoke any `mcp__ga4__*` tool with trivial args (e.g., `mcp__ga4__getActiveUsers` for the last hour). If it returns a result, GA4 MCP is reachable.
2. **Access binding check** — if any GA4 query returns `403 Permission denied` or `User does not have access to property 531124395`, the service-account access binding is incomplete. Jump to [§ Access Binding Recovery](#access-binding-recovery) below for the 3-path procedure.

If pre-flight fails AND recovery cannot be completed in this session → log "GA4 anomaly check SKIPPED — MCP access blocked" in the feature log and skip the rest of the checklist for the day.

---

## Baseline query set (≤2 minutes)

Run these three queries in order. Capture the result as scratch notes — no commit required unless an anomaly fires.

### Query 1 — Event volume, last 24h

```
mcp__ga4__getEvents period=last_24h
```

**What you're looking for:**
- Total event count vs prior-day baseline
- Any event category dropping to zero unexpectedly (e.g., `screen_view`, `sign_in`, `nutrition_meal_logged`)
- Any new event names appearing (could indicate uninstrumented release leak)

### Query 2 — Daily screen views, last 7 days

```
mcp__ga4__runReport metric=screen_view dimension=date period=last_7d
```

**What you're looking for:**
- Day-over-day deltas across the week
- Weekend-vs-weekday rhythm intact (or expected break)
- Any single day at <50% of the trailing 6-day median → potential outage or instrumentation regression

### Query 3 — Conversions, last 24h

```
mcp__ga4__runReport metric=conversions period=last_24h
```

**What you're looking for:**
- Funnel completion (onboarding → first_workout → first_meal_logged) within historic range
- Sign-in conversion rate (sign_in_completed / sign_in_started) within ±10% of trailing-7d average

---

## Anomaly criteria

Flag as an **anomaly** if any of the following:

| Signal | Threshold | Severity |
|---|---|---|
| Single event volume dropped vs prior day | **> 30%** | HIGH |
| Single screen_view dropped vs trailing-7d median | **> 30%** | HIGH |
| Event name vanished entirely (count = 0) | n/a | CRITICAL |
| New unknown event name appeared | n/a | MEDIUM (investigate, may be benign release) |
| Conversion funnel completion rate dropped | **> 15%** | HIGH |
| GA4 query returned error / timeout / partial | n/a | LOW (re-run once; if persists, file `/ops incident`) |

Single-anomaly within range (<30% / <15%) → record in feature log but do NOT escalate. Day-to-day noise is expected.

---

## When an anomaly fires

1. **Log it** — append to `.claude/logs/analytics-observability.log.json` via `python3 scripts/append-feature-log.py analytics-observability "ga4-anomaly-<YYYY-MM-DD>" "<one-line summary>"`
2. **Triage** — root-cause one level deep:
   - Schema regression? → dispatch `/analytics validate`
   - Sudden traffic drop? → dispatch `/ops health` (check Vercel + GA4 dashboard separately)
   - Funnel break? → dispatch `/cx analyze <feature>` if a specific funnel breaks
3. **Decide** — is this an operational issue, a release regression, or a measurement artifact? Document the decision in the feature log entry.

If **two consecutive days** show the same anomaly, escalate to a feature-grade investigation via `/pm-workflow analytics-observability` (resume the active feature).

---

## Cadence + retirement

| Stage | Status | Cadence | Notes |
|---|---|---|---|
| **Manual (today)** | active | daily, operator-run | This checklist |
| **Semi-automated (Phase 2.A.2)** | partially shipped | `/analytics watch` CLI sub-command (PR #345) | Live CLI; not yet wired to a daily routine |
| **Fully automated (Phase 2.B+)** | planned | scheduled remote agent (Linear routine + GA4 MCP) | Retires this manual checklist |

When the daily routine ships, this file becomes a historical reference. Until then, the operator is the routine.

---

## Access Binding Recovery

Use this section when pre-flight returns `403 PERMISSION_DENIED` because the service account `ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com` is not yet bound to property `531124395`. Three paths, ranked by likelihood × ease. **Try Path 1 first; it resolves ~90% of cases.**

### Context — why this happens

Two separate failure modes have been observed stacking on this binding:

1. **GA4 UI rejected the SA email** with "not a Google account" — *primary* failure mode, has known causes
2. **OAuth Playground blocks the workaround** with "this action is blocked by Advanced Protection" — *secondary* failure mode triggered only when the operator's Google account is enrolled in the [Advanced Protection Program (APP)](https://landing.google.com/advancedprotection/)

APP blocks ALL OAuth flows to apps not on Google's approved list, EVEN first-party tools like the OAuth Playground when they request elevated scopes (`analytics.edit` qualifies). This is by design — there is no per-app override toggle.

If we solve mode #1 we don't need to invoke any OAuth flow at all, so #2 becomes irrelevant.

### Path 1 — Retry the GA4 UI (HIGH likelihood, ~10 min)

Most "not a Google account" rejections are caused by **identity-propagation lag** (service-account email recognition takes 2–7 minutes after creation, sometimes up to 30 min) OR by **the "Notify by email" checkbox being left checked** (the SA has no inbox; email validation fails silently and surfaces as "not a Google account").

1. **Wait 10 minutes** from the moment the service account was created (or longer if previous attempts failed within that window)
2. Open <https://analytics.google.com> → click the **Admin** cog
3. In the **Property** column (NOT the Account column), confirm you're on **FitMe app** (Property `531124395`)
4. Click **Property Access Management**
5. Click the blue **`+`** button → **Add users**
6. Paste exactly: `ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com`
7. **UNCHECK "Notify new users by email"** ← critical; failing to do this is the most common silent-failure cause
8. Under **Direct roles and data restrictions**, select **Viewer**
9. Click the blue **Add** button

If still rejected after a 30-minute total wait → escalate to Path 2 or Path 3.

### Path 2 — Add from a non-APP Google account (MEDIUM, 5 min if available)

If you have access to another Google account that has Admin on property `531124395` AND is NOT enrolled in APP, the simplest workaround is to use that account for the one-time add:

1. Sign into GA4 with the non-APP account (incognito window, or temporary sign-out)
2. Follow Path 1 steps 2–9
3. Sign back into the primary account; verify the SA appears in Property Access Management

### Path 3 — Configure your own OAuth client + OAuth Playground (MEDIUM-HIGH, 15 min)

This unblocks OAuth Playground use even on an APP-enrolled account, because APP trusts OAuth clients owned by the same user. Documented in the [Medium "Navigating AppScript Restrictions" walkthrough](https://medium.com/google-cloud/navigating-appscript-restrictions-in-googles-advanced-protection-program-32e201dc98c8).

1. Open <https://console.cloud.google.com> → select project `fitme-490515`
2. **APIs & Services** → **OAuth consent screen**
   - User Type: **External**
   - Publishing status: **Testing**
   - App name: any (e.g. "ga4-admin-binding-cli")
   - User support email + developer email: your own
3. Under **Audience** → **Add Users** → add your own Gmail as a test user
4. Under **Data access** → **Add or Remove Scopes** → search and add `https://www.googleapis.com/auth/analytics.edit`
5. **APIs & Services** → **Credentials** → **+ Create Credentials** → **OAuth client ID**
   - Application type: **Web application**
   - Authorized redirect URI: `https://developers.google.com/oauthplayground`
   - Save → copy **Client ID + Client Secret** to a scratch buffer
6. Open <https://developers.google.com/oauthplayground>
7. Click the **gear icon** (top right) → check **"Use your own OAuth credentials"** → paste Client ID + Client Secret → **Close**
8. Step 1 — in the scopes box, type/select `https://www.googleapis.com/auth/analytics.edit` → **Authorize APIs**
9. APP now allows the flow because you own the OAuth client
10. Step 2 — **Exchange authorization code for tokens** → copy the `ya29.…` access token (1h TTL)
11. Run the binding curl (replace `<paste-token>` with the token from step 10):

    ```bash
    curl -X POST \
      -H "Authorization: Bearer ya29.<paste-token>" \
      -H "Content-Type: application/json" \
      -d '{"user":"ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com","roles":["predefinedRoles/viewer"]}' \
      https://analyticsadmin.googleapis.com/v1alpha/properties/531124395/accessBindings
    ```

12. Expected response: 200 OK with the new binding resource. Re-run the daily pre-flight to verify.

### What NOT to try

- **Don't disable APP** for this — security downgrade for a one-time admin task, plus APP has a cool-down (~24h) after re-enabling that adds operational friction
- **Don't `gcloud auth application-default login --scopes=analytics.edit`** from an APP account — [issuetracker #227765489](https://issuetracker.google.com/issues/227765489) (closed unresolved); APP blocks the same flow at the OAuth boundary
- **Don't recreate the service account** — it is correctly configured per the memory record; the binding is the only missing piece

### Verification after recovery

```bash
# In a Claude session:
# Invoke any mcp__ga4__* tool — should return data instead of 403
# Then proceed with the daily baseline queries below
```

Log the resolution to the feature log:

```bash
python3 scripts/append-feature-log.py \
  --feature analytics-observability \
  --event-type ga4_access_binding_resolved \
  --phase implementation \
  --summary "GA4 access binding resolved via Path <1|2|3> on YYYY-MM-DD" \
  --status complete \
  --actor operator
```

---

## Reference

- GA4 property: `531124395` (FitMe app)
- GCP project: `fitme-490515`
- Service account: `ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com`
- MCP setup: [`docs/setup/firebase-setup-guide.md`](../../docs/setup/firebase-setup-guide.md)
- Active feature: [`.claude/features/analytics-observability/`](../features/analytics-observability/)
- Taxonomy: [`docs/product/analytics-taxonomy.csv`](../../docs/product/analytics-taxonomy.csv)
- Naming convention: CLAUDE.md → "Analytics Naming Convention" section (screen-prefix rule, est. 2026-04-08)

Last refreshed: 2026-05-15.
