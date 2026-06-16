# Incident: GitHub PAT committed to a public repo via `.vercel/.env.production.local`

- **Date detected:** 2026-06-15 (full-system audit)
- **GitHub secret-scanning alert:** [#1](https://github.com/Regevba/FitTracker2/security/secret-scanning/1) — `github_personal_access_token`, opened 2026-04-29, state `open` at detection time
- **Severity:** P0 — live credential exposed in a **public** repository

## What happened

`.vercel/.env.production.local` was committed in `06fd7d6` (~2026-04-15) and stayed
git-tracked on `main`. It contained:

- `GITHUB_TOKEN` — a classic GitHub PAT (`ghp_…`)
- `VERCEL_OIDC_TOKEN` — a short-lived deploy JWT (`exp` early 2026, expired)

`.gitignore` listed `.vercel/` (line 96) but the rule was added *after* the file was
already tracked, so it never took effect. The whole `.vercel/` directory (11 files,
incl. Vercel build output + `project.json`) was tracked.

Exposure window: ~2 months, publicly readable. GitHub detected the PAT on 2026-04-29
but did **not** auto-revoke it (alert remained `open`).

## Remediation

### 1. Revoke (operator — primary mitigation)
- Revoke the `ghp_…` classic PAT at <https://github.com/settings/tokens>.
- Close secret-scanning alert #1 as **Revoked**.
- Review token scopes + <https://github.com/settings/security-log> for unrecognized activity.
- Rotate the Vercel deploy token if Vercel flags it (OIDC token is expired).

### 2. Stop forward exposure (this branch)
- `git rm -r --cached .vercel/` — untracks all 11 files; local copies retained;
  `.gitignore:96` keeps them out going forward. (`security/untrack-vercel-env-and-secrets`)

### 3. History purge (decide AFTER revoke — optional, disruptive)
The secret remains in git history even after untracking. On a public repo it has
already been scrapeable, so **revocation is the real fix**; a history rewrite is
cosmetic but removes the value from clones going forward.

If chosen, after the token is dead:

```bash
# requires git-filter-repo (https://github.com/newren/git-filter-repo)
git filter-repo --path .vercel/.env.production.local --invert-paths
git push --force-with-lease origin main   # coordinate: rewrites public history
```

Caveats: breaks existing clones/forks; GitHub may retain cached blob refs; all
collaborators must re-clone. Not worth doing until the PAT is confirmed revoked.

## Follow-ups
- Audit other `*.env*` / `.local` patterns repo-wide for tracked secrets (none other
  found in the 2026-06-15 audit secret-scan, but worth a recurring gitleaks gate —
  `.gitleaks.toml` already present; confirm it scans `.vercel/`).
