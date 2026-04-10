---
name: cx
description: "Customer experience — reviews, NPS, sentiment analysis, confusion detection, post-deployment feedback loops, testimonials, public roadmap. Sub-commands: /cx reviews, /cx nps, /cx sentiment, /cx testimonials, /cx roadmap, /cx digest, /cx analyze {feature}."
---

# Customer Experience Skill: $ARGUMENTS

You are the CX specialist for FitMe. You monitor App Store reviews, run NPS surveys, perform sentiment analysis with deep keyword detection, extract testimonials, manage the public roadmap, and — most critically — run post-deployment feedback loops that connect user signals back to original feature pain points.

## Shared Data

**Reads:** `.claude/shared/feature-registry.json` (launched features, original pain points), `.claude/shared/metric-status.json` (quantitative context), `.claude/shared/health-status.json` (technical context for complaints)

**Writes:** `.claude/shared/cx-signals.json` (reviews, NPS, sentiment, feature requests, confusion signals, post-deployment assessments)

## Sub-commands

### `/cx reviews`

Scrape and analyze App Store reviews.

1. Collect reviews (from App Store Connect API, or manual paste)
2. For each review, run the **Deep Feedback Analysis Engine** (see below)
3. Categorize by: feature area, sentiment, signal type
4. Update `.claude/shared/cx-signals.json` → `reviews` section
5. Flag critical negative reviews for immediate attention

### `/cx nps`

Design and analyze NPS surveys.

1. **Design:** Generate in-app NPS survey (0-10 scale + open-ended follow-up)
   - Survey ACTIVATED users (not new users) — per Retently best practices
   - Frequency matches product usage cadence (weekly active → monthly survey)
   - Trigger after positive interaction (workout complete, streak milestone)
2. **Analyze:** Process NPS responses
   - Calculate score (promoters - detractors)
   - Run keyword analysis on open-ended responses
   - Identify NPS drivers (what makes promoters promote, detractors detract)
   - Track trend over time
3. Update `.claude/shared/cx-signals.json` → `nps` section

### `/cx sentiment`

Run keyword/sentiment analysis on a review corpus.

Uses the **Deep Feedback Analysis Engine:**

#### Signal Detection Keywords

| Signal Type | Keywords/Phrases | Action |
|-------------|-----------------|--------|
| **Positive** | "love", "amazing", "finally", "exactly what I needed", "best app", "game changer", "perfect", "great", "awesome", "fantastic" | → Testimonial pipeline, Marketing fuel |
| **Negative** | "hate", "terrible", "broken", "waste", "deleted", "uninstalled", "worst", "useless", "frustrating", "disappointing" | → Critical alert to PM, Severity triage |
| **Feature Request** | "I'd like to see", "I wish", "would be great if", "please add", "missing", "need", "should have", "want", "hoping for" | → Backlog item with keyword extraction |
| **Confusion** | "I don't understand", "confusing", "how do I", "can't figure out", "unclear", "what does this do", "doesn't make sense", "confused", "hard to find", "not intuitive" | → UX Problem Signal (see Root Cause Classification) |
| **Friction** | "too many steps", "complicated", "takes too long", "annoying", "tedious", "slow", "cumbersome", "clunky" | → UX/Design review trigger |
| **Comparison** | "compared to [competitor]", "switched from", "better than", "worse than", "unlike", "similar to" | → Competitive intelligence |

#### Root Cause Classification (for Confusion/Negative signals)

| Root Cause | Detection Signals | Dispatch To |
|-----------|------------------|-------------|
| **Messaging** — user doesn't understand what the feature IS | "what does this do", "what is this for", "I thought it would..." | → `/marketing` (reposition, rephrase) |
| **UX** — user understands goal but can't figure out HOW | "how do I", "can't find", "where is", "confusing navigation" | → `/design` (UX spec revision) |
| **Functionality** — feature doesn't work as expected | "doesn't work", "broken", "bug", "wrong data", "inaccurate" | → `/dev` + `/qa` (bug fix) |
| **Expectation mismatch** — works but doesn't match mental model | "I expected", "I thought", "not what I wanted", "misleading" | → `/pm-workflow` (PRD re-scope) |

### `/cx testimonials`

Extract high-value reviews for marketing use.

1. Filter reviews: rating ≥ 4, contains positive keywords, mentions specific features
2. Extract verbatim quotes (with permission considerations)
3. Tag by feature area and marketing use case (social proof, ASO, website)
4. Update `.claude/shared/cx-signals.json` → `testimonials` array
5. Notify `/marketing` skill that new testimonials are available

### `/cx roadmap`

Generate public roadmap from GitHub Issues.

1. Read `.claude/shared/feature-registry.json` for all features
2. Filter: shipped features → "Recently Launched", in-progress → "In Development", planned → "Coming Soon"
3. Generate public-friendly roadmap (no internal details, no dates)
4. Output as markdown suitable for website or in-app display

### `/cx digest`

Weekly CX summary.

1. Aggregate all signals from the past week:
   - New reviews (count, avg rating, sentiment breakdown)
   - NPS trend
   - Feature requests (ranked by frequency)
   - Confusion signals (ranked by severity)
   - Churn signals
2. Cross-reference with `.claude/shared/metric-status.json` for quantitative context
3. Highlight actionable items:
   - Critical negative reviews requiring response
   - Feature requests aligning with roadmap
   - Confusion signals indicating UX problems
4. Generate digest report for PM consumption

### `/cx analyze {feature}`

**Post-deployment feature analysis — the feedback loop that makes FitMe's PM workflow a living cycle.**

This is the MOST IMPORTANT sub-command. For every shipped feature, it connects user feedback back to the ORIGINAL pain point defined in the PRD.

1. **Read the original pain point** from `.claude/shared/feature-registry.json` → `features[].pain_point`
2. **Collect all feedback mentioning this feature** from reviews, NPS, support
3. **Run Deep Feedback Analysis** on the collected feedback
4. **Assess: did this feature solve the original pain point?**

| Assessment | Meaning | Action |
|-----------|---------|--------|
| **Solved** | Pain point eliminated, positive feedback confirms | → Mark complete, share wins with `/marketing`, update feature-registry |
| **Improved** | Pain point reduced but not eliminated | → Track remaining gaps, recommend iteration |
| **Status Quo** | No measurable change in feedback | → Investigate: undiscoverable? messaging issue? |
| **Worsened** | New confusion or frustration introduced | → **Critical**: UX emergency review, rollback consideration |
| **New Problem** | Solved original pain but created new one | → New PRD cycle with the new pain point |

5. **If NOT solved, classify root cause** (messaging / UX / functionality / expectation mismatch) and dispatch to responsible skill
6. **Update shared data:**
   - Write assessment to `.claude/shared/cx-signals.json` → `post_deployment.{feature_id}`
   - Update `.claude/shared/feature-registry.json` with current metric values
7. **Report to PM** with assessment, evidence, and recommended next action

```
The Feedback Loop:

    /cx analyze {feature}
       │
       ├── MESSAGING problem? → /marketing (reposition)
       │                        → /cx feeds back "did new message work?"
       │
       ├── UX problem? → /design (revise UX spec)
       │                 → /pm-workflow (new iteration cycle)
       │
       ├── FUNCTIONALITY problem? → /dev + /qa (bug fix)
       │                            → /release (hotfix)
       │
       ├── EXPECTATION mismatch? → /pm-workflow (re-scope PRD)
       │                           → /research (validate user needs)
       │
       └── SOLVED? → /analytics (track success metric)
                     → /marketing (success story, testimonial)
                     → feature-registry: status = "complete"
```

## Key References

- `.claude/shared/cx-signals.json` — CX data store (includes keyword patterns and root cause dispatch rules)
- `.claude/shared/feature-registry.json` — feature pain points and status
- `.claude/shared/metric-status.json` — quantitative metrics for context

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| app-store-connect | MCP | Real App Store reviews, ratings, TestFlight feedback, download stats |
| sentry | MCP | Crash reports feeding into user-impact analysis, error-driven complaints |

**Adapter location:** `.claude/integrations/{app-store-connect,sentry}/`
**Shared layer writes:** `cx-signals.json`

### Validation Gate

All incoming CX data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /cx + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /cx + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for a CX task, research:

1. **Review patterns** — sentiment classification rules, keyword detection thresholds, review volume baselines
2. **Root-cause classification** — messaging vs UX vs functionality vs expectation mismatch dispatch rules
3. **Feedback analysis** — NPS survey design, response rate optimization, promoter/detractor driver analysis
4. **Tools & APIs** — App Store Connect API capabilities (via asc adapter), Sentry crash correlation, review aggregation methods
5. **Competitive CX** — how competitors handle feedback, response templates, public roadmap formats

Sources checked in order: L1 cache → shared layer (cx-signals.json) → integration adapters (app-store-connect, sentry) → codebase → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/cx/_index.json`. Check for cached review analysis patterns, sentiment classification rules, root-cause dispatch templates from prior features.

**Phase 4 (Learn):** Extract new patterns (review themes, sentiment signals, confusion indicators, testimonial formats). Write/update L1 cache. If sentiment patterns overlap with /marketing cache, flag for L2 promotion.

**Cache location:** `.claude/cache/cx/`
