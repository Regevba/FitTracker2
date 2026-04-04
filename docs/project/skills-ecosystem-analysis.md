# FitMe Skills & Automation Ecosystem — Gap Analysis

> **Purpose:** Map every skill, automation, and operational area — what exists, what's missing, and how everything connects.
> **Approach:** Bottom-up (what's built) + Top-down (what a complete product org needs)
> **Date:** 2026-04-04

---

## Part 1: What Exists Today

### Skills & Automations Inventory

| ID | Name | Type | Area | Status |
|----|------|------|------|--------|
| S1 | `/pm-workflow` | Claude Code Skill | PM | Shipped v1.2 |
| H1 | SessionStart hook | Shell hook | PM/Tracking | Active |
| H2 | Stop hook (git check) | Shell hook | Dev/Git | Active |
| A1 | Token pipeline (`make tokens`) | Makefile + Node | Design System | Active |
| A2 | Token drift detection (`make tokens-check`) | CI gate | Design System/QA | Active |
| A3 | CI pipeline (build + test) | GitHub Actions | Dev/QA | Active |
| A4 | Feature state tracking | JSON state machine | PM | Active |
| A5 | Analytics instrumentation gate | PM Skill phase | Analytics/QA | Active |
| A6 | Design system compliance gateway | PM Skill phase | Design/QA | Active |
| A7 | GitHub Issue label sync | PM Skill automation | PM/Tracking | Active |

### Existing Prompts (Claude Console / MCP)

| ID | Prompt | Tool | Area | Status |
|----|--------|------|------|--------|
| P1 | Figma prototype build (22+ screens) | Claude Console + Figma MCP | Design | Current |
| P2 | Figma MCP automation guide | Figma MCP setup | Design/Dev | Current |
| P3 | Iteration 2 master spec (20 screens) | Figma reference | Design | Current |
| P4 | Iteration 2 section prompts (6 copy-paste) | Claude Console + figma-console-mcp | Design | Current |
| P5 | Screen build manual (15 screens) | Figma manual reference | Design | Superseded |
| P6 | Notion workspace setup | Claude Console + Notion MCP | PM | Current |
| P7 | Figma prototype audit | Claude Console + Figma MCP | Design/QA | Current |
| P8 | Dashboard GitHub Issues | Claude Console + GitHub MCP | PM/Dev | Partial |

---

## Part 2: Functional Area Coverage Map

### Legend
- **Green:** Automated/skilled — has dedicated skill, hook, or pipeline
- **Yellow:** Partially covered — documented or manual process exists
- **Red:** Missing — no skill, automation, or process

| # | Functional Area | Sub-area | Coverage | What Exists | What's Missing |
|---|----------------|----------|----------|-------------|----------------|
| **1** | **Product Management** | | | | |
| 1.1 | Feature lifecycle | | Green | `/pm-workflow` skill, state.json, 9 phases | — |
| 1.2 | Backlog prioritization | | Yellow | RICE matrix in roadmap.md, manual | Automated RICE calculator, backlog grooming skill |
| 1.3 | Roadmap planning | | Yellow | master-backlog-roadmap.md, manual | Roadmap update automation, dependency tracking |
| 1.4 | Sprint/iteration planning | | Red | — | Sprint skill, velocity tracking, capacity planning |
| 1.5 | Stakeholder updates | | Red | — | Status report generator, weekly digest |
| | | | | | |
| **2** | **Design & UX** | | | | |
| 2.1 | Design system governance | | Green | Token pipeline, compliance gateway, CI gate | — |
| 2.2 | Figma prototype building | | Green | 7 prompts (P1-P5, P7), MCP guide | — |
| 2.3 | UX research & principles | | Yellow | UX research phase in pm-workflow | User research skill, usability testing |
| 2.4 | Design review | | Yellow | Feature development gateway (5-stage) | Automated design review, visual regression |
| 2.5 | Accessibility audit | | Yellow | WCAG AA contrast validation (DEBUG) | Full accessibility audit skill, VoiceOver testing |
| 2.6 | App Store visual assets | | Yellow | `docs/design-system/app-store-assets.md` | Screenshot generator, preview video automation |
| | | | | | |
| **3** | **Development** | | | | |
| 3.1 | CI/CD pipeline | | Green | GitHub Actions (token + build + test) | CD (deploy automation), staging environments |
| 3.2 | Code review | | Yellow | PM workflow Phase 6, high-risk file list | Automated code review skill, lint/format checks |
| 3.3 | Dependency management | | Red | — | Dependency update skill, security audit |
| 3.4 | Performance monitoring | | Red | — | Performance profiling, cold start tracking |
| 3.5 | Error tracking | | Red | — | Crashlytics/Sentry integration, error dashboard |
| 3.6 | Release management | | Red | — | Version bump, release notes, TestFlight deploy |
| 3.7 | Database migrations | | Red | — | Schema migration tracking (Supabase) |
| | | | | | |
| **4** | **Quality Assurance** | | | | |
| 4.1 | Unit testing | | Green | XCTest suite, analytics tests (23) | Coverage reporting, test generation |
| 4.2 | Integration testing | | Red | — | API integration tests, sync tests |
| 4.3 | UI testing | | Red | — | XCUITest, screenshot testing |
| 4.4 | Regression testing | | Yellow | Post-merge analytics regression | Full regression suite |
| 4.5 | Performance testing | | Red | — | Load testing, Lighthouse CI |
| 4.6 | Security testing | | Red | — | OWASP scan, encryption validation |
| | | | | | |
| **5** | **Analytics & Data** | | | | |
| 5.1 | Event taxonomy | | Green | GA4 taxonomy CSV, instrumentation gate | — |
| 5.2 | Analytics dashboards | | Red | — | GA4 dashboard templates, custom dashboards |
| 5.3 | Funnel analysis | | Red | — | Conversion funnel setup, cohort analysis |
| 5.4 | A/B testing | | Red | — | Feature flags, experiment framework |
| 5.5 | Data export/reporting | | Yellow | GDPR data export | Automated metric reports, weekly digest |
| | | | | | |
| **6** | **Customer Experience (CX)** | | | | |
| 6.1 | Review monitoring | | Red | Task 15.1 planned | App Store review scraper, sentiment analysis |
| 6.2 | In-app review prompts | | Red | Task 15.2 planned | SKStoreReviewController timing logic |
| 6.3 | NPS/CSAT surveys | | Red | Task 15.3 planned | In-app survey skill, dashboard |
| 6.4 | High-rating pipeline | | Red | Task 15.4 planned | Auto-email → approve → post to website |
| 6.5 | Low-rating follow-up | | Red | Task 15.5 planned | Dynamic email with text box |
| 6.6 | Public roadmap | | Red | Task 15.6 planned | Auto-update from GitHub Issues |
| 6.7 | Live user dashboard | | Red | Task 15.7 planned | GA4 Realtime integration |
| 6.8 | Keyword/sentiment analysis | | Red | Task 15.8 planned | AI review analysis |
| 6.9 | Follow-through dashboard | | Red | Task 15.9 planned | Fixed vs working-on tracker |
| 6.10 | Support email workflow | | Red | — | Email triage, response templates |
| | | | | | |
| **7** | **Marketing** | | | | |
| 7.1 | SEO | | Yellow | Website has meta/OG/JSON-LD, robots.txt | Search Console setup, keyword tracking |
| 7.2 | Content marketing | | Red | — | Blog/content skill, editorial calendar |
| 7.3 | Social media | | Red | — | Social posting, content calendar |
| 7.4 | Email marketing | | Red | — | Drip campaigns, onboarding emails |
| 7.5 | Referral program | | Red | — | Referral system design |
| | | | | | |
| **8** | **Product Marketing** | | | | |
| 8.1 | Positioning & messaging | | Yellow | PRD has elevator pitch, value props | Messaging framework, ICP docs |
| 8.2 | Competitive analysis | | Yellow | PRD competitive table | Automated competitor tracking |
| 8.3 | App Store Optimization (ASO) | | Red | Task 19 planned | Listing optimization, keyword bidding |
| 8.4 | Launch materials | | Red | — | Press kit, feature announcements |
| 8.5 | Comparison pages | | Red | Task 19 planned | vs MyFitnessPal, vs Strong, etc. |
| | | | | | |
| **9** | **Paid Acquisition** | | | | |
| 9.1 | Google Ads | | Red | Task 19 planned | Campaign setup, keyword strategy |
| 9.2 | Apple Search Ads | | Red | Task 19 planned | Basic + advanced keyword bidding |
| 9.3 | Meta (FB/IG) | | Red | Task 19 planned | Install campaigns, retargeting |
| 9.4 | Attribution tracking | | Red | Task 19 planned | UTM strategy, Firebase Dynamic Links |
| | | | | | |
| **10** | **Operations** | | | | |
| 10.1 | Incident response | | Red | — | On-call, runbook, escalation |
| 10.2 | Infrastructure monitoring | | Red | — | Railway health, Supabase monitoring |
| 10.3 | Cost tracking | | Red | — | Cloud spend tracking, alerts |
| 10.4 | Legal/compliance | | Green | GDPR shipped | Terms of Service, Privacy Policy pages |

---

## Part 3: Coverage Summary

| Area | Green | Yellow | Red | Total | Coverage |
|------|-------|--------|-----|-------|----------|
| Product Management | 2 | 2 | 2 | 6 | 50% |
| Design & UX | 2 | 3 | 1 | 6 | 58% |
| Development | 1 | 1 | 5 | 7 | 21% |
| Quality Assurance | 1 | 1 | 4 | 6 | 25% |
| Analytics & Data | 1 | 1 | 3 | 5 | 30% |
| Customer Experience | 0 | 0 | 10 | 10 | 0% |
| Marketing | 0 | 1 | 4 | 5 | 10% |
| Product Marketing | 0 | 2 | 3 | 5 | 20% |
| Paid Acquisition | 0 | 0 | 4 | 4 | 0% |
| Operations | 1 | 0 | 3 | 4 | 13% |
| **Total** | **8** | **11** | **39** | **58** | **24%** |

---

## Part 4: How Everything Connects (System Map)

```
                    ┌─────────────────────────────────────┐
                    │         PRODUCT STRATEGY             │
                    │  PRD → Metrics → Roadmap → Backlog   │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │      /pm-workflow SKILL (Hub)         │
                    │  Research → PRD → Tasks → UX →       │
                    │  Implement → Test → Review → Merge    │
                    └──┬───────┬────────┬──────┬──────────┘
                       │       │        │      │
           ┌───────────▼┐  ┌──▼────┐ ┌─▼──┐ ┌─▼──────────┐
           │Design System│  │  Dev  │ │ QA │ │  Analytics  │
           │Token Pipeline│ │  CI   │ │Tests│ │GA4 Taxonomy │
           │Figma Prompts │ │GitHub │ │Gate │ │Consent Gate │
           │Compliance GW │ │Actions│ │    │ │Regression   │
           └──────────────┘ └───────┘ └────┘ └────────────┘
                                                    │
                    ┌───────────────────────────────▼──────┐
                    │        MISSING LAYERS                 │
                    │                                       │
                    │  ┌─CX──────┐  ┌─Marketing──┐         │
                    │  │Reviews  │  │SEO/ASO     │         │
                    │  │NPS/CSAT │  │Paid Ads    │         │
                    │  │Sentiment│  │Content     │         │
                    │  │Support  │  │Email       │         │
                    │  └─────────┘  └────────────┘         │
                    │                                       │
                    │  ┌─Ops─────┐  ┌─Growth─────┐         │
                    │  │Monitor  │  │Attribution │         │
                    │  │Incident │  │Referrals   │         │
                    │  │Cost     │  │A/B Testing │         │
                    │  └─────────┘  └────────────┘         │
                    └──────────────────────────────────────┘
```

**Key insight:** The `/pm-workflow` skill is the central hub that connects PM, Design, Dev, QA, and Analytics. But post-launch operations (CX, Marketing, Growth, Ops) have zero automation. This is the biggest gap.

---

## Part 5: Recommended New Skills & Automations (Prioritized)

### Tier 1 — Critical (before App Store launch)

| # | Skill/Automation | Area | Why Critical | Effort |
|---|-----------------|------|-------------|--------|
| N1 | `/release` skill | Dev | Version bump, changelog, TestFlight deploy | 1 day |
| N2 | `/aso` skill | Product Marketing | App Store listing optimization | 2 days |
| N3 | `/cx-monitor` skill | CX | Review scraping + sentiment analysis | 3 days |
| N4 | App Store screenshot generator | Design | Automated from Figma/simulator | 2 days |
| N5 | Error tracking setup (Crashlytics) | Dev/Ops | Crash-free rate monitoring | 1 day |

### Tier 2 — High (first month post-launch)

| # | Skill/Automation | Area | Why | Effort |
|---|-----------------|------|-----|--------|
| N6 | `/nps` skill | CX | In-app NPS survey + dashboard | 2 days |
| N7 | `/campaign` skill | Marketing | UTM link generator + attribution | 1 day |
| N8 | GA4 dashboard templates | Analytics | Pre-built dashboards for key funnels | 1 day |
| N9 | `/weekly-digest` skill | PM/Ops | Automated status report | 1 day |
| N10 | Performance monitoring hook | Dev | Cold start, sync latency tracking | 1 day |

### Tier 3 — Medium (quarter 1)

| # | Skill/Automation | Area | Why | Effort |
|---|-----------------|------|-----|--------|
| N11 | `/competitor-watch` skill | Product Marketing | Track competitor updates | 2 days |
| N12 | A/B testing framework | Analytics | Feature flags + experiment tracking | 3 days |
| N13 | `/content` skill | Marketing | Blog post generator + SEO | 2 days |
| N14 | Email automation setup | Marketing | Onboarding drip, re-engagement | 3 days |
| N15 | Visual regression testing | QA/Design | Screenshot comparison CI | 2 days |

---

## Part 6: Best Practices Comparison

### What top fitness apps automate (industry benchmark)

| Practice | Strava | MyFitnessPal | Hevy | FitMe |
|----------|--------|--------------|------|-------|
| CI/CD pipeline | Yes | Yes | Yes | **Yes** |
| Automated testing | Yes | Yes | Yes | **Partial** (unit only) |
| Feature flags | Yes | Yes | Yes | **No** |
| A/B testing | Yes | Yes | No | **No** |
| Crash monitoring | Yes | Yes | Yes | **No** |
| Review monitoring | Yes | Yes | Yes | **No** |
| ASO automation | Yes | Yes | Yes | **No** |
| Email marketing | Yes | Yes | Yes | **No** |
| NPS/CSAT | Yes | Yes | No | **No** |
| Design system CI | No | No | No | **Yes** (unique) |
| PM lifecycle skill | No | No | No | **Yes** (unique) |
| Analytics instrumentation gate | No | No | No | **Yes** (unique) |

**FitMe's unique advantages:** Design system CI, PM lifecycle automation, analytics instrumentation gate. These are genuinely novel.

**FitMe's biggest gaps vs industry:** Crash monitoring, feature flags, review monitoring, ASO, email marketing.
