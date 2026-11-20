# Cloud Cost Opt-out + Secret Hygiene Runbook (2026-11-08)

> **Goal:** run every cloud/SaaS service FitMe uses on its **free tier**. Keep each service
> alive, turn off billable add-ons and set spend to $0. **Nothing is deleted.** The second
> goal is to confirm that no token or key was compromised.
>
> **Evidence base:** every "current state" claim below comes from **read-only** live checks
> run 2026-11-08 (Vercel MCP + CLI metadata, Supabase MCP, `gh` API, GitHub secret-scanning
> history, gitleaks CI), unless it is marked otherwise. No secret values were read or
> written, and none appear in this document: only names, IDs, ages and types.
> Tier tags follow [`data-quality-tiers.md`](../case-studies/data-quality-tiers.md):
> **T1** = observed via API/CLI on 2026-11-08 · **T2** = declared in repo/docs or a past
> audit, not re-observed · **OPERATOR** = needs a console login the agent doesn't have.

---

## 1. Summary verdict

| Question | Answer |
|---|---|
| Anything paid still running? | **Yes, two things.** (1) The **Upstash Redis store `Regev-upstash-kv-red-diamond`** is on the **"Fixed 250MB" paid plan ($10/mo + $5 per read region)** and is the store fitme-story actually uses (T1). (2) **Railway** hosts the AI engine, which is live (`/health` → 200, T1). Railway has no permanent free tier, so it is very likely billing (plan = OPERATOR). Also check **Figma Pro** (T2) and the **Apple Developer** renewal ($99/yr, keep). |
| Everything else free? | Vercel team = **Hobby** (T1). Supabase org = **Free**, project paused (T1). GitHub repos: 2 public + 3 private on a personal account (T1). LLM keys: total recorded HADF spend **$0.47**, last run 2026-06-02 (T1, from cost log). |
| Any token/key compromised? | **No evidence of compromise.** The one known leak (a GitHub PAT committed 2026-04-29 in `.vercel/.env.production.local`) was **revoked**: the GitHub secret-scanning alert was resolved as `revoked` on 2026-06-15 (T1). It was exposed publicly for 47 days first, so check the GitHub security log for that window (§5). There are 0 open secret-scanning alerts on both public repos, push protection is on, and gitleaks CI is green on every run through 2026-11-08 (T1). No deploy keys, webhooks or outside collaborators on any repo (T1). |
| What still needs work | 6 hygiene items (§5): unused tokens to delete, Vercel env vars stored "encrypted" instead of "sensitive", secret scanning disabled on the 3 private repos, Dependabot critical/high backlog, and two plaintext local `.env` files. |

---

## 2. Service inventory

| Service | Used for | Current plan (evidence) | Billable items found | Free-tier target | What changes if downgraded |
|---|---|---|---|---|---|
| **Vercel** (team `regevba-3729s-projects`, project `fitme-story`) | fitme-story site + Control Room | **Hobby**, status active (T1) | Speed Insights **on**, Web Analytics **on**, 1 cron (`/api/cron/sync-audit-log`, daily 05:13), Blob store `ucc-audit-log`, Fluid compute (T1). On Hobby these are capped quotas and are not billed as overage. | Stay Hobby | Nothing. If a quota is hit, the feature pauses; it doesn't bill. |
| **Upstash Redis** (via Vercel Marketplace) | Passkey auth audit log, lockouts | **Paid: "Fixed 250MB"**, `paymentMethodRequired: true`, connected to fitme-story prod/preview/dev (T1). Old free store `upstash-kv-coquelicot-pebble` was **uninstalled 2026-06-15** (T1). | **$10/mo + $5 per read region** | Upstash **Free** (500K commands/mo, 256MB) | Usage is light (auth events). Check data size < 256MB first (§3.2). |
| **Railway** | FastAPI AI engine (`fittracker-ai-production.up.railway.app`) | Running (T1). Plan unknown (OPERATOR). | Compute + bandwidth | Pause/remove the service (Railway has no permanent free tier) | iOS falls back to on-device recommendations (`AIOrchestrator` → `localFallback`), so no user-facing breakage. The AI engine also depends on Supabase JWT checks, and Supabase is already paused. |
| **Supabase** (org `ocxmuedazyvborfpomnh`, project `hwbbdzwaismlajtfsbed`) | iOS auth/sync, AI-engine JWTs | **Free** (`tier_free`); project **INACTIVE (paused)** (T1) | None | Stay Free | None. Paused free projects can be restored from the dashboard. |
| **GitHub** (account `Regevba`) | Repos, CI, Dependabot, secret scanning | Personal account. FT2 + fitme-story public; backend/ai/orchid private (T1) | Actions minutes on the private repos only (T2) | Free plan, spending limit **$0** | None, as long as the spending limit is $0. |
| **Figma** | Design-system mirror | **Pro** (T2: Code Connect failed for "Pro" in CI logs) | Pro seat | **Starter (free)** | Code Connect is already disabled. Check the library and file limits on Starter before downgrading (§3.5). |
| **Firebase / GA4 + Google Cloud** | App + web analytics, GA4 Data API service account | Spark/GA4 standard (T2) | Possible if a billing account is linked (BigQuery export) | Spark / no billing account | None for analytics. |
| **Apple Developer** | App Store, CloudKit | $99/yr (T2) | Annual fee | **Keep**: required to ship | n/a |
| **LLM providers** (OpenAI, Anthropic, Google, Mistral, xAI, Vercel AI Gateway, AWS Bedrock) | HADF benchmarks only | Pay-as-you-go keys. Total spend **$0.47**, last 2026-06-02 (T1 cost log). HADF launchd job is `.disabled` (T1). | Prepaid credit / auto-recharge | No auto-recharge, unused keys revoked | HADF re-runs need new keys (runbook: `docs/master-plan/hadf-phase2bis-key-acquisition-runbook-2026-05-25.md`). |
| **Sentry** | Crash reporting (not active) | Not activated (T2) | None | Developer (free) or no account | None |
| **Codecov, GitGuardian, Linear, Notion** | Coverage, secret scan, trackers | Free / personal (T2) | None expected | Free | None |

---

## 3. Opt-out procedure per service

Order: safest first. Each step ends with **Verify**. All steps are operator actions in a
web console unless a CLI command is shown.

### 3.1 Vercel: confirm Hobby, no paid add-ons
1. Dashboard → Team `regevba-3729s-projects` → **Settings → Billing**: plan must read **Hobby**, with no payment method or Pro trial.
2. Project `fitme-story` → **Speed Insights** and **Analytics**: on Hobby both are free within quota. Leave them on, or disable them if you don't use them.
3. **Settings → Integrations → Upstash**: see §3.2. This is the only paid Vercel-side item.
4. **Verify:** `vercel api "/v2/teams/team_nWTAev1JObeqXiUVrCNFN2j7" | jq .billing.plan` prints `"hobby"`.

### 3.2 Upstash Redis: move `red-diamond` to Free
1. Measure first: Upstash console (open via Vercel → Storage → `Regev-upstash-kv-red-diamond` → *Open in Upstash*) → **Usage**. Confirm data size < 256MB and monthly commands < 500K.
2. Vercel → **Storage → `Regev-upstash-kv-red-diamond` → Settings → Plan** → choose **Free**. If the console doesn't offer an in-place change, the fallback is: create a Free DB, export/import keys, reconnect it to fitme-story, then remove the old store. *Do not remove the old store until the new one is verified.* The audit log also has a Blob backup (`ucc-audit-log`, synced daily by cron).
3. **Verify:** `vercel api "/v1/storage/stores?teamId=team_nWTAev1JObeqXiUVrCNFN2j7"` shows the store's `billingPlan.id` = `free`. Then sign in to the Control Room with a passkey (exercises Redis) and check that `/api/control-room/state-sync-health` still returns JSON.

### 3.3 Railway: stop the AI engine
1. Railway dashboard → project hosting `fittracker-ai` → **Settings → Usage/Plan**: note the plan and current-month spend.
2. Service → **Settings → Pause/Remove deployment**, or delete the service. Keep the GitHub repo; redeploying later is one click.
3. Account → **Billing**: cancel the Hobby subscription and remove the payment method if no other projects exist.
4. **Verify:** `curl -s -o /dev/null -w '%{http_code}' https://fittracker-ai-production.up.railway.app/health` returns a non-200. An iOS build still shows recommendations (`inference_source_tier = local_fallback`).

### 3.4 Supabase: already Free; keep a spend cap
1. Org → **Billing**: plan **Free**, and "Spend cap" stays on (it can't be turned off on Free).
2. The project is paused. Restoring it is free, but free projects auto-pause after inactivity.
3. **Verify:** Supabase MCP `get_organization` → `plan: free` (confirmed 2026-11-08).

### 3.5 Figma: Pro → Starter
1. Figma → **Settings → Billing**: check what Pro covers (seats, team libraries).
2. Downgrade to **Starter**. Starter limits drafts and pages per file, so first export or duplicate the two mirror files (`0Ai7s3fCFqR5JXDW8JvgmD`, `fsjHfFLAHELACZHku8Rfcl`) to drafts if needed. Code is the source of truth, so the mirrors are non-critical.
3. **Verify:** billing page shows Starter and no upcoming invoice.

### 3.6 Google Cloud / Firebase
1. console.cloud.google.com → **Billing → Account management**: check whether any project is linked to a billing account. If one is linked only for BigQuery/GA4 export, unlink it (Firebase stays on Spark).
2. If you keep billing linked, add a **Budget alert at $1** instead.
3. **IAM → Service accounts**: confirm the GA4 Data API service account has only *Viewer* on the GA4 property. Delete unused keys (keys > 90 days old).
4. **Verify:** the Firebase console shows the **Spark** plan.

### 3.7 LLM providers + AWS
For each of OpenAI, Anthropic, Google AI Studio, Mistral, xAI, Vercel AI Gateway:
**Billing → turn off auto-recharge**, then **API keys → revoke HADF keys** (HADF is dormant, its job is disabled). For AWS: **Billing → Budgets → $1 budget alert**, then **IAM → deactivate the Bedrock access key**.
**Verify:** no active keys are listed, and the local `.env.local` (from `.env.local.template`) has its values cleared.

### 3.8 GitHub
1. github.com/settings/billing → **Spending limits**: Actions and Packages = **$0**, and no paid Copilot/LFS add-ons.
2. **Verify:** billing summary shows **$0** for the upcoming invoice.

### 3.9 Keep: Apple Developer
Required for the App Store and CloudKit. Note the renewal date in Apple Developer → Membership.

---

## 4. Secret inventory and status (names only)

### 4.1 GitHub Actions secrets (T1, `gh secret list`)

| Repo | Secret | Last set | Status / action |
|---|---|---|---|
| FitTracker2 | `WORKFLOW_PR_TOKEN` | 2026-10-29 | OK: rotated after the ~10-11 expiry; cron PRs verified. Next rotation ~2027-01-27. |
| FitTracker2 | `GOOGLESERVICE_INFO_PLIST_BASE64` | 2026-05-18 | OK: CI uses it. Contains Firebase *client* config (not a server secret). |
| FitTracker2 | `FIGMA_ACCESS_TOKEN` | 2026-05-10 | **Delete.** Code Connect is disabled, so it's unused. Also revoke the PAT at figma.com/settings. |
| fitme-story | `FT2_REPO_TOKEN` | 2026-06-15 | **Check expiry** at github.com/settings/personal-access-tokens. The reverse-sync workflow that uses it last ran 06-07. |
| fitme-story | `VERCEL_AUTOMATION_BYPASS_SECRET` | 2026-05-08 | OK (used by lighthouse/verify). |
| fitme-story | `FIGMA_ACCESS_TOKEN` | 2026-05-10 | **Delete** (same token family as above). |
| fittracker-backend | `CI_DB_PASSWORD` | 2026-03-26 | OK: CI-only throwaway Postgres. Rotate if the CI DB is ever reused. |
| fittracker-ai, orchid | none | n/a | n/a |

### 4.2 Vercel env vars, project `fitme-story` (T1, API metadata)
Vercel type **`sensitive`** = write-only (can't be read back). **`encrypted`** = readable by anyone with dashboard access.

| Name | Type | Targets | Updated | Action |
|---|---|---|---|---|
| `FITTRACKER2_DEPLOY_TOKEN` | sensitive | production, preview | 2026-10-29 | OK. Record the new PAT expiry. |
| `UCC_SESSION_SECRET` | sensitive | production, preview | 2026-05-16 | OK |
| `UCC_BOOTSTRAP_ADMIN_TOKEN` | sensitive (prod) / encrypted (dev) | | 2026-05-16 | OK. Delete the dev copy if unused. |
| `CRON_SECRET` | sensitive | preview, production | 2026-05-20 | OK |
| `BLOB_READ_WRITE_TOKEN` | **encrypted** | all | 2026-05-16 | **Re-add as sensitive** |
| `KV_REST_API_TOKEN`, `KV_REST_API_READ_ONLY_TOKEN`, `KV_URL`, `REDIS_URL`, `KV_REST_API_URL` | **encrypted** | all | 2026-05-16 | Managed by the Upstash integration. If you replace the store in §3.2 they are regenerated; otherwise re-add the token/URL ones as sensitive. |
| `DASHBOARD_PASS`, `DASHBOARD_USER` | **encrypted** | production (+dev user) | 2026-05-06 | **Re-add `DASHBOARD_PASS` as sensitive**. Consider removing it once passkey-only auth lands (`UCC_AUTH_MODE` is still `both`). |
| `UCC_ALLOWED_EMAILS` | encrypted | preview, production | 2026-05-20 | Low-risk (not a credential). Optional. |
| `UCC_AUTH_MODE` | plain | production, preview | 2026-05-16 | Config. `both` → `passkey` once FIT-66 cutover is done. |
| `NEXT_PUBLIC_GA_ID`, `DASHBOARD_BUILD`, `DASHBOARD_PUBLIC` | encrypted | | | Public config, OK. |

Re-add as sensitive, per variable and per environment:
`vercel env rm NAME production --project fitme-story` → `vercel env add NAME production --sensitive --project fitme-story`.
After env changes, run a **production redeploy**: env changes do not trigger a build.

### 4.3 Local and app-side secrets (T1 / T2)
- **iOS** (`Config/*.xcconfig`): committed values are placeholders. Real values live in gitignored `Config/Local/*.xcconfig`. The Supabase *anon* key and Google client IDs are public-by-design client identifiers.
- **Local plaintext files (untracked, `-rw-r--r--`):** `fittracker-ai/.env` (contains `SUPABASE_SERVICE_KEY`, a **server secret**) and `fitme-story/.env.local` (`VERCEL_OIDC_TOKEN`, short-lived). Action: `chmod 600` both. Rotate the Supabase service-role key when the project is next restored, since it has sat in plaintext since 2026-03-29.
- **LLM keys:** `.env.local.template` lists `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `XAI_API_KEY`, `VERCEL_AI_GATEWAY_API_KEY`. Revoke them per §3.7.
- **GitHub account access (T1):** 1 SSH auth key (2026-04-29), 2 SSH signing keys (YubiKey 2026-05-21, Secretive/Touch ID 2026-05-25). All expected. The local `gh` CLI OAuth token has `repo, workflow, admin:public_key, admin:ssh_signing_key, gist, read:org` scopes.

---

## 5. Compromise assessment

| Vector | Evidence (2026-11-08) | Verdict |
|---|---|---|
| **Historical PAT leak** (`.vercel/.env.production.local`, commit `06fd7d6f`, untracked in `5c90ab36` / #727; incident [`trust/incidents/2026-06-15-leaked-vercel-pat.md`](../../trust/incidents/2026-06-15-leaked-vercel-pat.md)) | Secret-scanning alert #1 (`github_personal_access_token`) created 2026-04-29, **resolved = `revoked`** 2026-06-15, no push-protection bypass (T1). The `VERCEL_OIDC_TOKEN` in the same file is short-lived and expired long ago. | **Dead now; exposure window unverified.** The token was in public history for **47 days** (2026-04-29 → 06-15) before revocation. Revocation proves it can't be used *now*, not that it wasn't used *then*. **Check** github.com/settings/security-log for 2026-04-29 → 06-15 (unfamiliar IPs, `personal_access_token` / `repo` / `oauth` events). Nothing unexpected is visible today: no deploy keys, hooks or collaborators were added, and the SSH/signing keys are all yours. A `git filter-repo` purge is optional; the string is unusable. |
| Other secrets in git history | 0 open secret-scanning alerts on FT2 + fitme-story. Scanning + push protection enabled on both (T1). gitleaks CI green: scheduled run 2026-11-08 and the last 5 runs all `success` (T1). Repo scan found no tracked `.env`/key/credential files in any of the 5 repos (T1). | **Clean (public repos).** |
| Private repos (backend, ai, orchid) | **Secret scanning and Dependabot alerts are disabled** (T1, API 404/403). | **Unverified.** Enable both (free for personal private repos), then re-check. |
| Repo access | 0 deploy keys, 0 webhooks, only collaborator `Regevba`, on all 5 repos (T1) | **Clean** |
| Vercel | Single team member. Sensitive vars can't be read back. Encrypted vars (§4.2) are readable only by team members. Hobby has no audit log. | **No evidence of misuse.** Converting to sensitive closes the gap. |
| Supabase | Project paused since before 2026-10-29. Security advisors: **0 lints** (T1, though a paused project limits what's checked). | **No evidence of misuse.** Re-run advisors after any restore (FIT-202 RLS still open). |
| Supply chain | Dependabot open: FT2 **2 critical / 12 high**, fitme-story **9 critical / 43 high** (T1). FT2 criticals are mostly astro in `/website` + `/dashboard`; fitme-story mostly `next`. | **Exposure, not compromise.** Patch per backlog (fitme-story `next` 16.4.x bump). |
| Cost-abuse signal | HADF LLM spend total $0.47, nothing since 2026-06-02 (T1). Vercel on Hobby can't overrun. | **Clean** |

**Bottom line:** no token or key shows signs of compromise. The one real leak (a GitHub PAT)
is revoked, but it sat in public history for 47 days, so its window needs one manual
security-log check to be fully closed. Every other vector is clean, except private-repo
scanning, which is not yet enabled.

---

## 6. Remediation checklist (operator)

**Cost (do first):**
- [ ] §3.2 Upstash `red-diamond` → Free (check size first) and verify passkey sign-in
- [ ] §3.3 Railway: check spend, pause/remove the AI engine, cancel the subscription
- [ ] §3.5 Figma Pro → Starter
- [ ] §3.6 GCP: unlink billing or set a $1 budget alert
- [ ] §3.7 LLM providers: auto-recharge off + revoke keys; AWS: budget alert + deactivate key
- [ ] §3.8 GitHub spending limit $0
- [ ] §3.1 Vercel billing page: confirm Hobby

**Security hygiene:**
- [ ] Review github.com/settings/security-log for 2026-04-29 → 2026-06-15 (leaked-PAT window, §5)
- [ ] Delete `FIGMA_ACCESS_TOKEN` in both repos: `gh secret delete FIGMA_ACCESS_TOKEN -R Regevba/FitTracker2` and `-R Regevba/fitme-story`. Revoke it in Figma too.
- [ ] Check the `FT2_REPO_TOKEN` and new `FITTRACKER2_DEPLOY_TOKEN` expiry dates and record them in §7
- [ ] Re-add `BLOB_READ_WRITE_TOKEN`, `DASHBOARD_PASS` (and the KV tokens if the store isn't replaced) as `--sensitive`, then redeploy production
- [ ] Enable secret scanning + Dependabot alerts on `fittracker-backend`, `fittracker-ai`, `orchid` (Settings → Code security)
- [ ] `chmod 600 ~/Developer/FitMe/fittracker-ai/.env ~/Developer/FitMe/fitme-story/.env.local`
- [ ] When Supabase is next restored: rotate the service-role key, then re-run `get_advisors`
- [ ] Optional: remove the duplicate `.gitguardian.yml` / `.gitguardian.yaml` (keep one)

---

## 7. Ongoing guardrails

| Guardrail | Cadence | How |
|---|---|---|
| Plan/spend re-check | Monthly | Re-run the §1 checks: `vercel api /v2/teams/<id>` (`billing.plan`), `vercel api /v1/storage/stores` (`billingPlan`), Supabase `get_organization`, Railway billing page |
| Token rotation calendar | Per token | `WORKFLOW_PR_TOKEN` ~2027-01-27 · `FITTRACKER2_DEPLOY_TOKEN` (record expiry) · `FT2_REPO_TOKEN` (record expiry) · `CRON_SECRET` / `UCC_SESSION_SECRET` yearly |
| Secret scanning | Continuous | GitHub secret scanning + push protection (public repos; enable on private), gitleaks CI (`.github/workflows/gitleaks.yml`), pre-commit pattern scan (`.githooks/pre-commit`) |
| Cron-health check | Weekly | `gh run list --workflow integrity-cycle.yml`. A dead token produces *no* PRs, which the sweep's "bot PRs" layer can't see. |
| Incident record | Per incident | `trust/incidents/YYYY-MM-DD-*.md` |
| Integrity telemetry | Daily | `make integrity-sweep` |

**Safety rule for this runbook:** never paste a secret value into this file, a PR, an issue
or a commit message. Record only names, IDs, types, dates and expiries.
