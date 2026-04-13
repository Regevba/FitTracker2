# PRD: Marketing Website

> **ID:** Task 16 | **Status:** In Progress | **Priority:** HIGH (RICE 4.3)
> **Last Updated:** 2026-04-12 | **Branch:** feature/marketing-website (merged to main)

---

## Purpose

Build FitMe's public marketing website — the app's front door for organic search, paid acquisition, social sharing, and App Store downloads.

## Business Objective

Establish web presence for FitMe. Currently zero organic traffic, zero SEO footprint, zero web-to-App Store conversion funnel. This site is the foundation for all future marketing.

## Reality Check

- The marketing website code exists in the repo, but it is not the canonical live surface today.
- The canonical `fit-tracker2` Vercel project is currently rooted at `dashboard/`, which means `fit-tracker2.vercel.app` serves the operations control room rather than the public marketing site.
- The marketing site still contains launch blockers such as placeholder GA4 IDs, placeholder App Store URLs, and unverified aggregate-rating metadata.
- Treat this PRD as "implemented in code, not yet truthfully launched."

## What Was Built

### Sections (Single-Page Astro Site)
| Section | Description |
|---------|-------------|
| Nav | Sticky nav with logo, section links, mobile hamburger, Download CTA |
| Hero | Gradient background, "Train Smarter. Live Stronger." headline, App Store badge, phone mockup |
| Features | 6 cards: Training, Nutrition, Recovery, Analytics, AI Coach, Privacy |
| Screenshots | 4 phone mockup cards (Dashboard, Workout, Nutrition, Analytics) |
| How It Works | 3-step flow: Download → Set Goals → Track & Improve |
| Privacy | Dark section: E2E encrypted, zero-knowledge, GDPR, secure sync |
| FAQ | 6-question accordion with native `<details>` elements |
| CTA | Gradient banner with App Store download badge |
| Footer | Product links, legal links, support email |

### Tech Stack
- **Astro** (static site generator) + **Tailwind v4**
- **Vercel** deployment config
- FitMe brand tokens in global.css

### SEO
- JSON-LD `SoftwareApplication` structured data
- Open Graph tags (title, description, type, url, site_name)
- Twitter Card meta tags
- Canonical URL, robots.txt, favicon.svg
- Meta description

### GA4 Web Analytics (3 Custom Events)
| Event | Trigger | Parameters |
|-------|---------|------------|
| `cta_click` | Any CTA button click | cta_location, cta_type |
| `section_view` | Section enters viewport | section_name |
| `faq_expand` | FAQ accordion opened | question_index |

## Key Files
| File | Purpose |
|------|---------|
| `website/src/pages/index.astro` | Main page |
| `website/src/components/*.astro` | 9 components (Nav, Hero, Features, Screenshots, HowItWorks, Privacy, FAQ, CTA, Footer) |
| `website/src/layouts/Layout.astro` | SEO, OG tags, JSON-LD, GA4 gtag.js |
| `website/src/scripts/analytics.js` | GA4 event tracking |
| `website/src/styles/global.css` | Brand tokens |

## Success Metrics

| Metric | Baseline | Target | Timeframe |
|--------|----------|--------|-----------|
| Monthly unique visitors | 0 | 500 | 90 days post-launch |
| App Store CTR | 0% | >5% | 90 days |
| Bounce rate | N/A | <60% | 90 days |
| Avg time on page | N/A | >45 seconds | 90 days |
| Lighthouse score | N/A | >90 all categories | At launch |

## Pre-Launch Checklist
- [ ] Replace `G-XXXXXXXXXX` with real GA4 Measurement ID
- [ ] Update App Store URL when listing is live
- [ ] Connect custom domain (fitme.app)
- [ ] Verify OG preview renders on social platforms
- [ ] Submit sitemap to Google Search Console
- [ ] Remove or verify aggregate rating / review metadata in JSON-LD
- [ ] Decide whether marketing lives in the canonical `fit-tracker2` Vercel project or a separate production project/domain
