# Development Dashboard — Post-Launch Activation Guide

> Feature complete as of 2026-04-02. This guide covers the steps to make the dashboard fully operational.

---

## 1. Create GitHub Issues (T14)

The dashboard reads from GitHub Issues as its primary live data source. Currently it runs on static data (`dashboard/src/data/features.json`).

### Option A: Claude Console (recommended)

1. Open [claude.ai](https://claude.ai) in a session that has **GitHub MCP** connected
2. Paste the prompt from the PM workflow session (the original `docs/project/github-issues-prompt.md` was removed during the April 2026 docs reorganization)
3. Claude will create:
   - 26 labels (11 phase + 4 priority + 9 category + 2 spare)
   - 6 milestones (Phase 0–5)
   - 37 issues (11 closed/shipped + 11 open/planned + 15 open/backlog)
4. Record the issue numbers and update `dashboard/src/data/features.json` if needed

### Option B: GitHub CLI (`gh`)

```bash
# Install gh if needed: brew install gh
# Authenticate: gh auth login

# Create labels (example — repeat for all 26)
gh label create "phase:research" --color 9CA3AF --repo Regevba/FitTracker2
gh label create "priority:critical" --color DC2626 --repo Regevba/FitTracker2
gh label create "category:product" --color 3B82F6 --repo Regevba/FitTracker2

# Create milestone
gh api repos/Regevba/FitTracker2/milestones -f title="Phase 0: Foundation" -f state=closed -f description="PRD, metrics, backlog, roadmap"

# Create issue (example)
gh issue create --repo Regevba/FitTracker2 \
  --title "Training Tracking" \
  --label "phase:done,category:product" \
  --milestone "Phase 0: Foundation" \
  --body "87 exercises, RPE, PRs, rest timer, cardio, photo capture. Shipped 2026-03-14."

# Close shipped issues
gh issue close <number> --repo Regevba/FitTracker2
```

### Option C: Skip for now

The dashboard works with static data. GitHub Issues enrich it with live labels for drag-drop sync but aren't required for the core experience.

---

## 2. Deploy to Vercel

### First-time setup

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import `Regevba/FitTracker2`
3. Configure:
   - **Root Directory:** `dashboard`
   - **Framework Preset:** Astro
   - **Build Command:** `npm run build`
   - **Output Directory:** `dist`
4. Environment variables (optional):
   - `GITHUB_TOKEN` — Personal access token (read-only, `public_repo` scope) for live GitHub Issue fetching at build time
5. Deploy

### Automatic deploys

Vercel auto-deploys on push to `main`. The dashboard rebuilds with fresh data on every commit.

### Custom domain (optional)

In Vercel project settings → Domains → Add `dashboard.fitme.app` or similar.

---

## 3. Enable Analytics

### Vercel Analytics (recommended)

1. In Vercel dashboard → your project → Analytics → Enable
2. This gives you:
   - Page views per week (primary metric)
   - Unique visitors
   - Web Vitals (LCP, FID, CLS)
3. No code changes needed — Vercel injects the analytics script automatically

### Connect to PRD metrics

| PRD Metric | How to Measure | Source |
|------------|---------------|--------|
| Dashboard page views/week | Vercel Analytics → Page Views | Auto |
| Priority changes/week | Add event tracking on drag-drop | Code change needed |
| Time to find feature status | Add Performance Observer | Code change needed |
| External shares | Track outbound link clicks | Code change needed |

### Adding event tracking (future)

```jsx
// In KanbanBoard.jsx handleDragEnd:
if (typeof window !== 'undefined' && window.va) {
  window.va('event', { name: 'priority_change', data: { from: oldPhase, to: targetPhase } });
}
```

---

## 4. Connect Live GitHub Data

Currently the dashboard uses `features.json` (static). To fetch live from GitHub:

### Update `index.astro` frontmatter:

```javascript
// Replace static import with live fetch
import { fetchIssues } from '../scripts/github.js';

const token = import.meta.env.GITHUB_TOKEN;
let githubIssues = [];
try {
  githubIssues = await fetchIssues(token);
} catch (e) {
  console.warn('GitHub API unavailable, using static data');
}

// Merge with static data
const { alerts, sources } = reconcile({
  githubIssues,
  staticFeatures: allFeatures,
  stateFiles: parsedData ? [/* state files */] : [],
});
```

### Set environment variable

In Vercel: Settings → Environment Variables → Add:
- Key: `GITHUB_TOKEN`
- Value: `ghp_...` (your PAT with `public_repo` scope)
- Environment: Production + Preview

---

## 5. Scheduled Rebuilds (optional)

To keep data fresh without manual pushes:

### Vercel Cron (recommended)

Add to `vercel.json`:
```json
{
  "crons": [{ "path": "/api/rebuild", "schedule": "0 */6 * * *" }]
}
```

### GitHub Actions alternative

```yaml
# .github/workflows/rebuild-dashboard.yml
name: Rebuild Dashboard
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:
jobs:
  rebuild:
    runs-on: ubuntu-latest
    steps:
      - run: curl -X POST "${{ secrets.VERCEL_DEPLOY_HOOK }}"
```

---

## 6. First Metrics Review

Per the PRD, the first metrics review should happen **2 weeks after launch**.

### Review checklist

- [ ] Dashboard page views/week — target: 10
- [ ] Priority changes/week — target: 1
- [ ] Time to find feature status — target: < 10 seconds
- [ ] External shares — target: 3
- [ ] Kill criteria check: < 5 unique visitors/week after 60 days AND developer stops using it

### Schedule

Add to your calendar:
- **2 weeks post-deploy:** First metrics review
- **Monthly:** Ongoing metrics check
- **60 days post-deploy:** Kill criteria evaluation

---

## 7. Drag-Drop → GitHub Sync (future)

When GitHub Issues exist and the token is configured, drag-drop on the kanban board can update GitHub labels in real-time:

1. User drags card from "Backlog" to "Research"
2. Dashboard calls `updateIssueLabels()` (already implemented in `github.js`)
3. Removes `phase:backlog`, adds `phase:research`
4. Next `/pm-workflow` invocation detects the change and asks user to confirm

This completes the bidirectional sync loop:
```
/pm-workflow → state.json → GitHub labels → Dashboard → drag-drop → GitHub labels → /pm-workflow
```

---

## Quick Start Summary

| Step | Time | Priority |
|------|------|----------|
| 1. Create GitHub Issues | 10 min | High — enables live data |
| 2. Deploy to Vercel | 5 min | High — makes it accessible |
| 3. Enable analytics | 2 min | Medium — tracks success metrics |
| 4. Connect live GitHub data | 10 min | Medium — enables auto-refresh |
| 5. Scheduled rebuilds | 5 min | Low — convenience |
| 6. First metrics review | 30 min | Required — 2 weeks post-deploy |
| 7. Drag-drop sync | Future | Low — nice-to-have |

**Total activation time: ~30 minutes**
