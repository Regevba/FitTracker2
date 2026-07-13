# Bot-PR CI-trigger setup — `WORKFLOW_PR_TOKEN` (Option B)

> **One-time operator setup.** Until this secret exists, the automated snapshot
> crons keep working but their PRs **deadlock** (they never trigger the required
> checks and sit open forever). This doc closes that.

## The problem

`main` requires 3 status checks (`integrity`, `Build and Test`, `try-repo-harness`)
before any PR merges. GitHub **deliberately does not run workflows on PRs opened
by the default `GITHUB_TOKEN`** (a recursion guard). So every PR from
`integrity-cycle.yml` (every 72h) and `framework-status-weekly.yml` (Mondays)
opened as `github-actions[bot]` → its required checks stay `expected` → the PR
can never merge. Empirically this stranded ~13 bot PRs (3 abandoned) before the
2026-07-13 cleanup.

## The fix (Option B)

Have the two crons open their PRs with a **Personal Access Token (PAT)** instead
of `GITHUB_TOKEN`. A PAT-opened PR is authored by a real user, so it **triggers
the required-check workflows**; the workflows already enable **auto-merge**, so
the PR lands the moment the checks go green. GitHub's squash-merge commit stays
**verified** — no branch-protection change, no signature relaxation.

The workflows read `secrets.WORKFLOW_PR_TOKEN` and fall back to `GITHUB_TOKEN`
when it is unset (so nothing breaks before you do this — you just keep the old
deadlock until the secret lands).

## Steps

1. **Create a fine-grained PAT** at
   <https://github.com/settings/personal-access-tokens/new>:
   - **Resource owner:** `Regevba`
   - **Repository access:** Only select repositories → **`Regevba/FitTracker2`**
   - **Repository permissions:**
     - **Contents:** Read and write (push the snapshot branch)
     - **Pull requests:** Read and write (open the PR + enable auto-merge)
     - Metadata: Read-only (auto-granted)
   - **Expiration:** 90 days (calendar a rotation; see below). Longer is fine if
     you prefer fewer rotations.

2. **Add it as a repo secret** named exactly **`WORKFLOW_PR_TOKEN`**:
   ```bash
   gh secret set WORKFLOW_PR_TOKEN --repo Regevba/FitTracker2
   # paste the token when prompted
   ```

3. **Confirm "Allow auto-merge" is enabled** (it already is on this repo, but to
   be sure): repo **Settings → General → Pull Requests → Allow auto-merge** = on.

4. **Verify** on the next cron fire (or trigger one now):
   ```bash
   gh workflow run integrity-cycle.yml --repo Regevba/FitTracker2   # workflow_dispatch
   ```
   Within a few minutes the opened PR should show `Build and Test` + `integrity` +
   `try-repo-harness` running (not `expected`), then auto-merge. Or run the soak
   check: `python3 scripts/check-bot-pr-health.py`.

## Rotation

The PAT expires (90 days if you followed above). When it does, the crons silently
fall back to `GITHUB_TOKEN` → the deadlock returns. Re-run step 1–2 to rotate.
A calendar reminder is tracked in
[`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md).

## Why not Option A (bot bypass on branch protection)?

Considered and rejected 2026-07-13: `main` is a **User** repo (classic protection
has no per-app bypass) with **signed commits + enforce-admins** on, so Option A
required migrating protection to a ruleset **and** rewriting the crons to make
signed API commits. Option B needs one secret and weakens nothing. If Option B
proves unreliable over its soak window, Option A is the documented next step.
