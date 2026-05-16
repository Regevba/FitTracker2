# GA4 Access Binding — Setup & Recovery Guide

**Audience:** operator (one-time setup OR recovery) · **Created:** 2026-05-15 · **Status:** in production — recovery paths validated by operator workflow on 2026-05-15

> Companion to [`ga4-mcp-setup-guide.md`](./ga4-mcp-setup-guide.md). Use this guide when the GA4 UI rejects your service account at "Step 3 — Grant the service account read access to your GA4 property", OR when the daily GA4 anomaly check returns `403 PERMISSION_DENIED`.

---

## What this guide solves

Binding a Google Cloud service account to GA4 property `531124395` so the GA4 MCP server can read events. The happy path is documented in [`ga4-mcp-setup-guide.md`](./ga4-mcp-setup-guide.md) Step 3 — paste the SA email in the GA4 UI → click Add. This guide covers the failure modes when that doesn't work and gives three recovery paths plus pivot options.

---

## Why the happy path can fail

Two failure modes have been observed stacking on this binding:

### Failure mode 1 — GA4 UI rejects the SA email

The UI returns the error: `This email doesn't match a Google account`.

**Three known causes:**

1. **Identity-propagation lag** — Google's identity backend takes 2–7 minutes after SA creation to recognize the new identity, sometimes up to 30 minutes. Adding the SA before propagation completes triggers the error.
2. **"Notify by email" checkbox left CHECKED** — service accounts have no inbox, so the email validation step fails silently and surfaces as "doesn't match a Google account". This is the **most common cause** because the checkbox defaults to checked.
3. **Service account created on/after 2026-04-23** — Google introduced a behavior change on that date that prevents newly-created SAs from being added to GA4 properties via the UI. Documented in [Google Analytics Community thread #431700589](https://support.google.com/analytics/thread/431700589/service-accounts-created-after-april-23-2025-cannot-be-added-to-ga4-properties). No public fix timeline as of 2026-05-15.

### Failure mode 2 — OAuth Playground blocks the API workaround

If you try to fall back to the [GA4 Admin API accessBindings](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1alpha/properties.accessBindings/create) endpoint via OAuth Playground to mint a token, Google's [Advanced Protection Program (APP)](https://landing.google.com/advancedprotection/) blocks the OAuth flow with: `Access blocked: this action is blocked by Advanced Protection`.

APP blocks all OAuth flows to apps not on Google's approved list — including OAuth Playground itself when it requests elevated scopes like `analytics.edit`. This affects only APP-enrolled accounts, but **there is no per-app override toggle**.

---

## Prerequisites

- Owner or Editor role on the FitMe GA4 property `531124395`
- Owner role on GCP project `fitme-490515`
- Service account `ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com` already created per [`ga4-mcp-setup-guide.md`](./ga4-mcp-setup-guide.md) Step 2
- ssh-agent loaded with your commit-signing key (verify: `ssh-add -l`)

---

## Path 1 — Retry the GA4 UI (HIGH likelihood, ~10 min)

**Use first.** Resolves ~90% of cases that hit failure-mode 1 causes (1) and (2). Only fails if cause (3) applies (post-April-23 SA cutoff).

1. **Wait 10 minutes** from the moment the service account was created. If a previous attempt within the window failed, wait the **remainder of 30 minutes** before retrying.
2. Open <https://analytics.google.com> → click the **Admin** cog (bottom-left)
3. In the **Property** column (NOT the Account column), confirm you're on **FitMe app** (Property `531124395`)
4. Click **Property Access Management**
5. Click the blue **`+`** button (top-right) → **Add users**
6. Paste exactly: `ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com`
7. **UNCHECK "Notify new users by email"** ← critical; failing to uncheck this is the most common silent-failure cause
8. Under **Direct roles and data restrictions**, select **Viewer**
9. Click the blue **Add** button

**Expected outcomes:**

| Outcome | Meaning | Next |
|---|---|---|
| ✅ Success — SA appears in user list | Binding complete | Verify per § Verification below |
| ❌ "doesn't match a Google account" (after 30-min wait) | Cause (3) likely — proceed to Path 2 or Path 3 | Path 2 first if you have a non-APP admin account; otherwise Path 3 |

---

## Path 2 — Add from a non-APP Google account (MEDIUM, 5 min if available)

**Use when:** Path 1 failed AND you have another Google account that (a) has Admin role on property `531124395`, and (b) is NOT enrolled in APP.

### Prerequisites — confirm before starting

1. You have the other account's credentials (password / 2FA / passkey)
2. The other account is already Admin on the property — verify in GA4 → Admin → **Account Access Management** AND **Property Access Management**. If not yet admin, grant it from your current admin account first.
3. The other account is NOT APP-enrolled. Verify at <https://myaccount.google.com/security> with that account signed in — look for "Advanced Protection Program" section. If "ON" or shield icon active → still APP-enrolled, won't work.

### Steps

1. Open an **incognito / private window** (`Cmd+Shift+N` Chrome, `Cmd+Shift+P` Firefox/Safari)
2. Open <https://analytics.google.com> in the incognito window
3. Sign in with the **non-APP account**
4. Follow Path 1 steps 4–9
5. Close the incognito window
6. Verify per § Verification below

### When Path 2 still fails

If the same "doesn't match a Google account" error appears even from a non-APP account, the failure is on the SA side (post-April-23-2025 cutoff), not on your account side. Proceed to Path 3 to get a diagnostic API response, then pivot per § Pivot Options below.

---

## Path 3 — Configure your own OAuth client + use in OAuth Playground (MEDIUM-HIGH, 15-20 min)

**Use when:** Path 1 + 2 failed, OR you don't have a non-APP admin account available.

**Why this bypasses APP:** Advanced Protection trusts OAuth clients YOU own (in YOUR GCP project). Google's Playground is a third-party client from APP's perspective; your own client isn't.

**Diagnostic value:** even if the final API call fails because of the April-23 SA cutoff, the API returns a specific typed error message (the UI just says "doesn't match a Google account"). The API response tells us exactly what's blocking.

### Phase A — Enable the Analytics Admin API (1 min)

Often skipped in walkthroughs; causes a confusing 403 at the curl step.

1. Open <https://console.cloud.google.com/apis/library/analyticsadmin.googleapis.com?project=fitme-490515>
2. Click the blue **ENABLE** button
3. Wait for "API enabled" confirmation

### Phase B — Configure OAuth consent (5 min)

Google rolled out a new **Google Auth Platform** UI (as of ~Q1 2026) that replaces the old single-page wizard with a sidebar-driven layout. Each setting lives on its own sidebar item. Use this path:

4. Open <https://console.cloud.google.com/auth/overview?project=fitme-490515>
5. You'll land on **Google Auth Platform → Overview**. The left sidebar shows: Overview, Branding, Audience, Clients, Data Access, Verification Center, Settings.

**B-1: Branding** (sets App information)

6. Click **Branding** in the left sidebar
7. Fill in:
   - **App name:** `ga4-admin-binding-cli` (or any string; only you see it)
   - **User support email:** your Gmail
   - **Developer contact email:** your Gmail
8. Click **Save**

**B-2: Audience** (sets User Type + Test users)

9. Click **Audience** in the left sidebar
10. Confirm **User type = External**. If not set, click and select External.
11. Confirm **Publishing status = Testing** (default for new projects)
12. Scroll to **Test users** section → click **+ Add users** → enter your own Gmail → **Save**

**B-3: Data Access** (adds the scope)

13. Click **Data Access** in the left sidebar
14. Click **Add or remove scopes**
15. In the filter box, paste: `analytics.edit`
16. Tick the row showing `…/auth/analytics.edit` (description: "Edit Google Analytics management entities")
17. Click **Update** → click **Save**

> **Legacy UI fallback:** if your console still shows the old single-page wizard at <https://console.cloud.google.com/apis/credentials/consent?project=fitme-490515>, the equivalent flow is: pick User Type = External → CREATE → fill App info + developer email → SAVE AND CONTINUE → ADD OR REMOVE SCOPES (filter `analytics.edit`) → SAVE AND CONTINUE → + ADD USERS (your Gmail) → SAVE AND CONTINUE → BACK TO DASHBOARD. Same effective configuration.

### Phase C — Create OAuth Client ID (2 min)

**New UI path:**

18. Click **Clients** in the left sidebar (same Google Auth Platform UI from Phase B)
19. Click **+ Create client**
20. **Application type:** select **Web application**
21. **Name:** `ga4-playground-client` (or any string)
22. **Authorized redirect URIs:** click **+ Add URI** → paste exactly: `https://developers.google.com/oauthplayground`
23. Click **Create**
24. The created-client dialog appears. Copy **both** values to a scratch file:
    - **Client ID** (looks like `1234567890-abc…apps.googleusercontent.com`)
    - **Client secret** (looks like `GOCSPX-…`)

> **Legacy UI fallback:** at <https://console.cloud.google.com/apis/credentials?project=fitme-490515> → **+ CREATE CREDENTIALS** → **OAuth client ID** → same fields. Identical result.

### Phase D — Authorize via OAuth Playground (3 min)

24. Open <https://developers.google.com/oauthplayground>
25. Click the **gear icon** ⚙ (top-right corner)
26. **OAuth 2.0 configuration** panel slides out on the right
27. Tick the checkbox **"Use your own OAuth credentials"**
28. Paste your **Client ID** + **Client secret** from step 22
29. Click **Close** (the gear panel)
30. **Step 1 — Select & authorize APIs** (left panel, top):
    - Scroll down (or use the filter box) → find **Google Analytics Admin API v1alpha**
    - Tick `https://www.googleapis.com/auth/analytics.edit`
31. Click the blue **Authorize APIs** button
32. Google's consent screen appears → sign in with your APP-enrolled Gmail. **This is the moment of truth:** APP should NOT block this flow because YOU own the OAuth client. You'll see a regular consent screen asking to grant `analytics.edit` to "ga4-admin-binding-cli"
33. You may see a yellow "Google hasn't verified this app" warning → click **Advanced** → **Go to ga4-admin-binding-cli (unsafe)**. Safe because you own it.
34. Click **Allow** on the consent screen
35. You're redirected back to OAuth Playground. **Step 2 — Exchange authorization code for tokens** is now highlighted on the left.
36. Click **Exchange authorization code for tokens** (blue button)
37. Right pane shows a response with `access_token: "ya29.…"` — **copy the access token value** (the long string after `"access_token":` and before the next comma; do NOT copy the quotes)

### Phase E — Bind the service account via curl (1 min)

38. In your terminal:

    ```bash
    export TOKEN="ya29.PASTE_THE_TOKEN_HERE"

    curl -i -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"user":"ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com","roles":["predefinedRoles/viewer"]}' \
      https://analyticsadmin.googleapis.com/v1alpha/properties/531124395/accessBindings
    ```

39. **Possible responses:**

    | Status | Meaning | Next |
    |---|---|---|
    | `HTTP/2 200` + JSON with `name: "properties/531124395/accessBindings/…"` | ✅ Success — SA is bound | Verify per § Verification below |
    | `HTTP/2 400` + `INVALID_ARGUMENT` mentioning "user not found" or "not a Google account" | Likely the April 23 cutoff | Pivot per § Pivot Options below |
    | `HTTP/2 403` + `PERMISSION_DENIED` | Your user account isn't actually admin on the property | Verify Admin in GA4 UI first |
    | `HTTP/2 403` + `Google Analytics Admin API has not been used in project…` | Phase A wasn't completed | Go back to Phase A |
    | `HTTP/2 401` + `invalid_token` | Access token expired (>1h since step 36) | Re-do Phase D steps 30–37 |

---

## Pivot Options — when all 3 paths fail (April 23 cutoff confirmed)

If Path 3's API call returns "user not found" / "not a Google account" / similar, the SA itself is in the post-April-23-2025 blocked cohort. Three pivot options:

### Pivot A — Use a default GCP service account

The GCP project's implicit default service accounts pre-date the April-23 cutoff if the project was created before then.

```bash
# Check what default SAs exist in the project
gcloud iam service-accounts list --project=fitme-490515

# Look for accounts like:
#   - <project-number>-compute@developer.gserviceaccount.com   (Compute Engine default)
#   - <project-number>@cloudservices.gserviceaccount.com       (Google APIs Service Agent)
```

If a default SA exists AND was created before 2026-04-23, reconfigure the GA4 MCP to use that SA's key file. Generate a new key for it via Console → IAM & Admin → Service Accounts → `<default-sa>` → KEYS → ADD KEY.

### Pivot B — Switch from service account to user OAuth

The GA4 MCP server can be reconfigured to use user OAuth credentials instead of a service account. The user account (the operator) already has GA4 admin, so no binding is needed — the OAuth consent flow grants access directly.

**High-level steps:**

1. Set up an OAuth client in your GCP project (same procedure as Path 3 Phases A–C, but with `analytics.readonly` scope instead of `analytics.edit`)
2. Reconfigure the GA4 MCP server config to use OAuth client ID + secret instead of `GOOGLE_APPLICATION_CREDENTIALS=…sa-key.json`
3. Run the MCP server once interactively to complete the consent flow → refresh token gets stored locally
4. From then on, all MCP queries use the refresh token; no SA needed

The exact MCP server config keys depend on which GA4 MCP implementation you're using — check the server's `README.md` for OAuth env var names. The bundled Vercel `ga4-mcp` server supports `OAUTH_CLIENT_ID` + `OAUTH_CLIENT_SECRET` env vars.

### Pivot C — Wait for Google fix

The [Google Analytics Community thread](https://support.google.com/analytics/thread/431700589/service-accounts-created-after-april-23-2025-cannot-be-added-to-ga4-properties) is the canonical bug report. As of 2026-05-15, no public timeline. Subscribe for updates.

---

## What NOT to try

- **Don't `gcloud auth application-default login --scopes=analytics.edit`** from an APP-enrolled account — confirmed broken via [issuetracker #227765489](https://issuetracker.google.com/issues/227765489); APP blocks the OAuth consent at the sensitive-scope boundary
- **Don't recreate the service account** if Path 1/2/3 fail — same SA-create date constraint will apply
- **Don't expect a brand-new dedicated Google account to work for OAuth Test users immediately** — Google's OAuth Platform rejects Test users with "Email addresses must be associated with an active Google Account" when the account is <24-48h old and lacks phone verification + multi-context sign-in history. The same young-account state blocks `gcloud auth application-default login --scopes=analytics.readonly` from the dedicated account with "This app is blocked: this app tried to access sensitive info". A dedicated account becomes usable for sensitive scopes after ~7-30 days of warming up. Confirmed via 2026-05-16 session.

## Pivot D — Brief APP cycle on primary account (RECOMMENDED when dedicated isn't usable yet)

**Use when:** Path 1-3 + Pivots A-C all fail, AND the dedicated account is too young for sensitive-scope grants.

**Why this is safe:** APP only blocks the **initial OAuth consent flow**. Once the refresh token is issued, the MCP server uses it to mint access tokens server-to-server **without any consent screen** — APP doesn't gate that. So a 3-minute APP-off window to mint the initial token leaves you back at full APP protection while the MCP works indefinitely.

### Steps (5 min total, ~3 min APP-off)

1. Sign into primary account in a regular Chrome window
2. <https://myaccount.google.com/advanced-protection> → **Turn off Advanced Protection** → confirm with security key
3. Wait 60 seconds for propagation
4. Run:

    ```bash
    gcloud auth application-default login --account=<primary>@gmail.com \
      --scopes=https://www.googleapis.com/auth/analytics.readonly,https://www.googleapis.com/auth/cloud-platform
    ```

5. Complete browser consent (no "blocked" page this time because APP is off)
6. `gcloud auth application-default set-quota-project fitme-490515`
7. **Immediately re-enable APP** at the same URL
8. The ADC file now has primary's tokens with the analytics scope; MCP keeps using them indefinitely via refresh

**Total APP-off window: 3 minutes.** The refresh token survives APP re-enable; no further consent screens.

---

## Verification (after any path succeeds)

1. **API verification** (from terminal):

   ```bash
   # List access bindings on the property — should include the SA
   curl -H "Authorization: Bearer $TOKEN" \
     https://analyticsadmin.googleapis.com/v1alpha/properties/531124395/accessBindings | python3 -m json.tool
   ```

2. **MCP verification** (in any Claude Code session): invoke any `mcp__ga4__*` tool with a small date range. If it returns data instead of `403 PERMISSION_DENIED`, the binding works.

3. **Daily checklist verification**: re-run the [GA4 anomaly check](../../.claude/integrity/ga4-anomaly-checklist.md) — pre-flight should succeed.

4. **Log the resolution** to the analytics-observability feature log:

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

## Cross-references

- [`ga4-mcp-setup-guide.md`](./ga4-mcp-setup-guide.md) — primary MCP setup (this guide handles its Step 3 failure modes)
- [`.claude/integrity/ga4-anomaly-checklist.md`](../../.claude/integrity/ga4-anomaly-checklist.md) — daily operator checklist that points back here on 403
- [`docs/master-plan/analytics-master-plan-2026-05-13.md`](../master-plan/analytics-master-plan-2026-05-13.md) — analytics-observability epic plan
- Memory entry: `project_session_2026_05_15_ga4_access_binding_blocked`

## External references

- [Service accounts created after April 23, 2025 cannot be added to GA4 properties — GA Community thread](https://support.google.com/analytics/thread/431700589/service-accounts-created-after-april-23-2025-cannot-be-added-to-ga4-properties)
- [Advanced Protection Program FAQ — Google Account Help](https://support.google.com/accounts/answer/7539956)
- [Navigating AppScript Restrictions in APP — Medium / Lucas Nogueira](https://medium.com/google-cloud/navigating-appscript-restrictions-in-googles-advanced-protection-program-32e201dc98c8)
- [GA4 Admin API — accessBindings.create reference](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1alpha/properties.accessBindings/create)
- [issuetracker #227765489 — gcloud auth application-default login --scopes fails on APP accounts](https://issuetracker.google.com/issues/227765489)
- [Domain-restricted sharing — GCP Org Policy docs](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains)

Last refreshed: 2026-05-15.
