---
date: 2026-06-03
artifact_type: lighthouse-run
target: https://fitme-story.vercel.app/
runner: lighthouse@latest (npx), headless Chrome
purpose: Phase 2.A OP-08 / OP-09 — Lighthouse + Rich Results scorecard on production
phase_e_safe: true
work_type: chore
---

# Lighthouse run — fitme-story.vercel.app — 2026-06-03

Routine post-Phase-1 SEO + perf scorecard. No regressions detected.

## Scores

| Category | Score |
|---|---|
| Performance | **84** |
| Accessibility | **100** ✅ |
| Best Practices | **100** ✅ |
| SEO | **100** ✅ |
| Agentic-browsing | **100** ✅ |

## SEO = 100 confirms

The JSON-LD wiring + Sitelinks Search Box that shipped via fitme-story PR #163 (`feat(seo): C1 — JSON-LD wiring + Sitelinks Search Box + sitemap improvements`) remains intact. No structured-data regressions; rich-results eligibility preserved.

## Performance 84 — top 4 cost drivers (not regressions; routine bundle tuning headroom)

| Audit | Score | Remediation |
|---|---|---|
| `largest-contentful-paint` | 43 | LCP is the hero/og-image rendering path; review prefetch/preload + critical-CSS inlining |
| `render-blocking-insight` | 50 | Async/defer non-critical CSS + 3rd-party scripts |
| `unused-javascript` | 0 | ~650 ms wall-time available via dead-code elimination + dynamic imports |
| `legacy-javascript-insight` | 0 | Drop legacy bundles on modern targets (Vercel auto-handles via Next.js) |

None of these are user-visible breakage; all are perf headroom items for a future optimization pass.

## Artifact

Full Lighthouse JSON: [`home.json`](home.json) (~590 KB).

## Reproduce

```bash
npx -y lighthouse@latest https://fitme-story.vercel.app/ \
  --output=json --output-path=./home.json \
  --chrome-flags="--headless --no-sandbox" --quiet
```

## Related

- `docs/master-plan/fitme-story-discoverability-plan-2026-05-20.md` §Phase 2.A OP-08 / OP-09
- fitme-story PR #163 (JSON-LD wiring)
- fitme-story PR #164 (Lighthouse SEO false-positive fix on preview deploys + production scorecard)
