# fitme-story Discoverability Plan — 2026-05-20

> **Trigger:** 2026-05-20 GA4 audit revealed `fitme-story.vercel.app` has **0 recorded visitors in 30 days** (legacy `fit-tracker2.vercel.app` dashboard captured 4 web users). The site is invisible despite being the canonical showcase of the framework work.
>
> **Owner:** Operator
> **Target horizon:** 2026-05-21 (post-v7.9 freeze) → 2026-06-30 (~5 weeks)
> **Goal:** 50+ unique organic visitors per week to `fitme-story.vercel.app/*` by 2026-06-30

## 1. Current State (verified 2026-05-20)

### What's already in place ✅

| Surface | Status | Detail |
|---|---|---|
| GA4 property | Configured | `G-XE4E1JGWRZ` injected via `NEXT_PUBLIC_GA_ID` |
| GA tag delivery | Verified | `@next/third-parties/google` mounts in root layout; curl confirms `gtag/js` in rendered HTML on all routes |
| Sitemap | Generated | `src/app/sitemap.ts` outputs 13 static routes + dynamic case studies + framework versions |
| Robots | Generated | `src/app/robots.ts` allows `/` everywhere, disallows `/control-room/*` (correct) |
| Root metadata | Basic | Title + description set; **no OpenGraph or Twitter Card** |
| Vercel deploy | Active | HTTP 200 on all sampled public routes (/, /framework, /case-studies, /design-system, /glossary) |
| Content | Substantial | 25+ case studies, 4 framework versions documented, dev-guide, dispatch flow diagram, design system showcase |

### What's missing ❌

| Gap | Severity | Why it matters |
|---|---|---|
| Zero recorded visitors | 🔴 P0 | Showcase has no audience |
| No Google Search Console verification | 🔴 P0 | Google may not know the site exists |
| No OpenGraph metadata | 🟡 P1 | Social shares produce bare links instead of rich previews |
| No social presence pointing in | 🟡 P1 | LinkedIn/Twitter/dev.to/HN all silent |
| No backlinks from legacy `fit-tracker2.vercel.app` | 🟡 P1 | 4 existing web users on the old dashboard can't discover the new site |
| No 301 redirect from legacy URL | 🟡 P1 | Same — captures legacy traffic + preserves SEO equity if Google indexed old URL |
| No per-page metadata (case studies) | 🟡 P2 | Each case study should have its own title/description/OG image |
| No analytics tied to engagement | 🟢 P3 | Once traffic exists, dashboard event helpers (Phase 3.B) need wiring |
| Dashboard `_*` event helpers defined but never called | 🟢 P3 | Phase 3.B is the wire-up; planned for post-Phase-E (~06-04) |

## 2. Gap Analysis — Why 0 Visitors?

Three causes, ordered by likelihood:

### 1. Nobody knows the URL exists (90% of the gap)
- Operator hasn't promoted it
- No backlinks from indexed sources (GitHub README, social, etc.)
- Google Search Console not set up → likely not crawled yet
- The 4 legacy users found `fit-tracker2.vercel.app` via direct/referral, but had no signal pointing at the new domain

### 2. Operator self-traffic filtered (5% of the gap)
- GA4 may have an internal-traffic filter excluding the operator's IP
- Worth checking GA4 admin → Data settings → Data filters
- Doesn't affect external visitors, but explains why operator's own visits today (S1+S2+S3 during T20) don't show

### 3. Possible content-blocker on operator's browser (5% of the gap)
- uBlock/Brave/DNT browser feature may suppress gtag.js
- Test: open `fitme-story.vercel.app` in a private/incognito window with no extensions, then check GA4 Realtime
- Doesn't affect external visitors; only operator-side noise

## 3. Action Plan (ordered by impact ÷ effort)

### Phase 1 — Foundation (~2h, target 2026-05-21 → 05-23)

| # | Action | Effort | Effect | Status |
|---|---|---|---|---|
| **P1.1** | Submit `fitme-story.vercel.app` to Google Search Console + verify via DNS TXT or HTML meta tag | 30 min | Google starts crawling the site; baseline traffic data available | ⏳ pending (operator action — Google account auth required) |
| **P1.2** | Submit sitemap URL (`/sitemap.xml`) to Search Console | 5 min | All 13+ static + dynamic routes prioritized for crawl | ⏳ pending (gated on P1.1) |
| ~~**P1.3**~~ | ~~Add OpenGraph + Twitter Card meta tags to root layout~~ | ~~45 min~~ | ~~Social shares produce rich previews~~ | ✅ **SHIPPED 2026-05-21** via fitme-story root layout + `src/lib/seo.ts::buildMetadata()` helper + per-page `generateMetadata`. Verified live via `curl https://fitme-story.vercel.app \| grep og:`. All openGraph + twitter:card meta present on every page. |
| ~~**P1.4**~~ | ~~Create OG image at 1200×630~~ | ~~30 min~~ | ~~Visual asset for social previews~~ | ✅ **SHIPPED 2026-05-21** via [`fitme-story/src/app/opengraph-image.tsx`](https://github.com/Regevba/fitme-story/blob/main/src/app/opengraph-image.tsx) — Next.js ImageResponse generates the 1200×630 PNG at runtime at `/opengraph-image`. Auto-applied via Next.js Metadata API auto-detection. ⚠ **2026-05-27 live bug discovered + fixed:** `buildMetadata()` was hardcoding `og:image` URL as `/og.png` which 404'd → social previews silently broken for 6 days; fixed via [fitme-story PR #156](https://github.com/Regevba/fitme-story/pull/156) (`fix(seo): og:image defaults to /opengraph-image`) + 6 regression tests in `src/lib/seo.test.ts`. |
| **P1.5** | Verify GA Realtime sees a visit from incognito window | 5 min | Confirms wiring once and for all | ⏳ pending (operator action — needs incognito browser visit + GA4 Realtime tab check). **GA4 7-day backward check 2026-05-27:** 0 fitme-story.vercel.app sessions in 2026-05-21 → 05-27 window (only iOS app traffic present); confirms P1.1 GSC verification is the gating step. |

**Outcome (so far):** P1.3 + P1.4 SHIPPED (with 1 silent-bug post-deploy fix); P1.1 + P1.2 + P1.5 pending operator actions (Google account auth + browser visit).

**Phase 1 lesson captured:** the `og:image` URL must round-trip via curl HEAD after every layout/seo.ts change. The 6-day silent-404 reproduced because no test asserted the URL resolved to 200. Closed via [fitme-story `src/lib/seo.test.ts`](https://github.com/Regevba/fitme-story/blob/main/src/lib/seo.test.ts) — 6 unit tests pin the contract. A v7.9.1 candidate could extend this to a deployed-URL HEAD probe in CI; queued informally.

### Phase 2 — Crosslinking (~2h, target 2026-05-23 → 05-25)

| # | Action | Effort | Effect |
|---|---|---|---|
| **P2.1** | Add `fitme-story.vercel.app` link to **FT2 README.md** (in description + top section) | 15 min | Anyone landing on FT2 GitHub repo finds the showcase |
| **P2.2** | Add `fitme-story.vercel.app` link to **fitme-story repo README.md** (in description) | 10 min | Same for fitme-story GitHub repo |
| **P2.3** | Set up **301 redirect** from `fit-tracker2.vercel.app/*` → `fitme-story.vercel.app/control-room/*` (preserve query strings — `?view=board` etc map to canonical routes) | 1h | Captures the 4 existing legacy web users + future legacy traffic + preserves SEO equity |
| **P2.4** | Update `fit-tracker2.vercel.app` deploy with a temporary banner: "Moved to fitme-story.vercel.app" before redirect lands | 15 min | Soft migration notice for any cached users |

**Outcome:** existing 4 web users (and any future legacy traffic) flow to the new site.

### Phase 3 — Promotion (~3h, target 2026-05-26 → 05-30)

| # | Action | Effort | Effect |
|---|---|---|---|
| **P3.1** | Write a launch announcement (1-page narrative: "I shipped an AI-orchestrated PM framework alongside a fitness app — here's the showcase") | 1h | Asset for social posts + HN/dev.to |
| **P3.2** | Post to LinkedIn from operator's profile | 5 min | Reach professional network (likely 50-200 impressions on launch) |
| **P3.3** | Post to Hacker News "Show HN: I shipped an AI-orchestrated PM framework..." | 5 min | Reaches 100-1000+ targeted readers if it gets traction |
| **P3.4** | Cross-post 2-3 representative case studies to dev.to or hashnode (canonical link back to fitme-story) | 2h | SEO juice + community visibility |
| **P3.5** | Update operator's Twitter/X profile bio with `fitme-story.vercel.app` link | 5 min | Passive surface for any inbound interest |

**Outcome:** first wave of intentional visitors lands on the site.

### Phase 4 — Measure + Iterate (~1h setup + ongoing, target 2026-06-04+)

| # | Action | Effort | Effect |
|---|---|---|---|
| **P4.1** | Set up GA4 conversion goals: `page_view` on `/framework/dev-guide` + `/case-studies/[slug]` (any) | 30 min | Measure which content engages |
| **P4.2** | Daily B3 GA4 anomaly check (per existing cadence followup) — include fitme-story session count | passive | Catches traffic spikes or drops |
| **P4.3** | Weekly summary: top 5 pages, top 3 referrers, bounce rate, avg time-on-page | 15 min/wk | Continuous improvement loop |
| **P4.4** | **Phase 3.B wire-up** (POST-PHASE-E exit ~2026-06-04): call the 8 typed dashboard event helpers from `/control-room/*` page components | 4-6h | Granular engagement signals on the actual control-room work |

**Outcome:** data-driven iteration once organic traffic exists.

## 4. Success Metrics

| Metric | 2026-05-20 baseline | 2026-06-30 target |
|---|---|---|
| Weekly unique visitors to `fitme-story.vercel.app/*` | **0** | **50+** |
| Total sessions per week | 0 | 100+ |
| Search Console verified | No | Yes |
| Indexed pages | Unknown | 15+ |
| Social share-quality OG cards | Bare links | Rich previews on LinkedIn + Twitter |
| External backlinks pointing in | 0 | 5+ (FT2 README + fitme-story README + 2-3 cross-posts + HN/social) |
| Top traffic source | n/a | "(organic) / google" or "(referral) / hacker news" |
| Dashboard `_*` events firing (Phase 3.B) | 0 | 1+ event types live (target post-2026-06-04) |

## 5. Kill Criteria (when to pivot)

If by **2026-06-30** the site still has <10 weekly unique visitors despite Phase 1+2+3 complete:
- The content is not what people want — re-evaluate scope/positioning
- OR the audience is too niche — pivot to a different distribution channel
- OR the framework story isn't compelling enough — invest in narrative quality

## 6. Risk Register

| Risk | Mitigation |
|---|---|
| Hacker News post doesn't get traction → no organic traffic | Multiple distribution channels in Phase 3 (LinkedIn + dev.to + Twitter); not all-eggs-one-basket |
| Search Console verification fails due to DNS/hosting limits on Vercel | Use HTML meta tag verification as fallback (no DNS edit needed) |
| Operator's IP becomes filtered, hiding all post-launch data | Phase 1.5 verifies wiring in incognito; ongoing checks via Realtime tab |
| Phase 3.B dashboard event wiring breaks production (~06-04) | Phase 3.B is post-Phase-E and on its own feature branch with normal PM workflow gates |

## 7. Calendar

| Week | Phase | Active hours |
|---|---|---|
| 2026-05-21 → 05-23 (post-v7.9 freeze) | Phase 1 (Foundation) | 2h |
| 2026-05-23 → 05-25 | Phase 2 (Crosslinking) | 2h |
| 2026-05-26 → 05-30 | Phase 3 (Promotion) | 3h |
| 2026-06-04+ (post-Phase-E) | Phase 4 (Measure + Iterate + Phase 3.B wiring) | 4-6h setup + ongoing |

**Total active effort: ~11-13 hours over 5 weeks**

## 8. Cross-References

- GA wiring verification: confirmed 2026-05-20 via curl + grep
- GA audit findings: [`project_session_2026_05_20_v7_9_eve_ga4_audit.md`](../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_20_v7_9_eve_ga4_audit.md)
- Sitemap source: [`fitme-story/src/app/sitemap.ts`](https://github.com/Regevba/fitme-story/blob/main/src/app/sitemap.ts)
- Robots source: [`fitme-story/src/app/robots.ts`](https://github.com/Regevba/fitme-story/blob/main/src/app/robots.ts)
- Analytics module: [`fitme-story/src/lib/control-room/analytics.ts`](https://github.com/Regevba/fitme-story/blob/main/src/lib/control-room/analytics.ts) (8 typed event helpers, no current call-sites)
- Phase 3.B context: `analytics-observability` feature state.json, deferred to post-Phase-E
