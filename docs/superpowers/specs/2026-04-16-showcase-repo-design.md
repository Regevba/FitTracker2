# Showcase Repo Design Spec

> **Date:** 2026-04-16
> **Status:** Approved — execute next session
> **Audience:** Professional (primary), Community (secondary), Academic (bonus)
> **Curation:** Heavy — rewritten for external readers, self-contained, narrative-driven

---

## 1. Repo Identity

- **Name:** `fitme-showcase` (or `fitme-engineering`)
- **Visibility:** Public
- **Tagline:** "How a solo developer built and measured an AI-orchestrated product management framework across 16 shipped features"

---

## 2. Structure

```
fitme-showcase/
├── README.md                          # Showcase entry point — the story
│
├── 01-product-vision/
│   ├── README.md                      # Product overview (from repo README)
│   ├── master-prd.md                  # From PRD.md — vision, personas, metrics
│   ├── readiness-score-formula.md     # From prd/readiness-score-formula-v2.md
│   ├── ai-engine.md                   # From prd/ai-engine-v2.md
│   ├── smart-reminders.md             # From prd/smart-reminders.md
│   ├── ai-recommendation-ui.md        # From prd/ai-recommendation-ui.md
│   └── user-profile.md               # From prd/user-profile-settings.md
│
├── 02-process-framework/
│   ├── README.md                      # Framework intro + why it exists
│   ├── pm-lifecycle.md                # From process/product-management-lifecycle.md
│   ├── skills-architecture.md         # From skills/architecture.md + architecture-one-pager.md
│   ├── skills-ecosystem.md            # From skills/README.md
│   ├── pm-workflow-hub.md             # From skills/pm-workflow.md
│   ├── framework-evolution.md         # From skills/evolution.md — v1.0 → v7.0 timeline
│   └── project-governance.md          # From CLAUDE.md — rules, branching, CI, design system
│
├── 03-design-system/
│   ├── README.md                      # Design system intro
│   ├── ux-foundations.md              # From design-system/ux-foundations.md (13 principles)
│   ├── governance.md                  # From design-system/design-system-governance.md
│   └── v2-refactor-methodology.md     # From design-system/v2-refactor-checklist.md
│
├── 04-case-studies/
│   ├── README.md                      # Case study index + methodology
│   ├── 01-onboarding-pilot.md         # From pm-workflow-showcase-onboarding.md
│   ├── 02-framework-evolution.md      # From pm-workflow-evolution-v1-to-v4.md (6.5x speedup)
│   ├── 03-parallel-stress-test.md     # From v5.1-parallel-stress-test-case-study.md
│   ├── 04-measurement-v6.md           # From framework-measurement-v6-case-study.md
│   ├── 05-hadf-v7.0.md               # From hadf-hardware-aware-dispatch-case-study.md
│   ├── 06-full-system-audit.md        # From meta-analysis-full-system-audit-v7.0-case-study.md
│   ├── 07-auth-flow-velocity.md       # From onboarding-v2-auth-flow-v5.1-case-study.md
│   ├── 08-ai-engine-architecture.md   # From ai-engine-architecture-v5.1-case-study.md
│   ├── normalization-model.md         # From normalization-framework.md
│   ├── meta-analysis.md              # From meta-analysis/what-if-v6-from-day-one.md
│   └── meta-analysis-validation.md    # From meta-analysis/meta-analysis-validation.md
│
├── 05-research/
│   ├── README.md                      # Research intro — why a fitness app led to chip design
│   ├── soc-software-architecture.md   # From architecture/soc-software-architecture-research.md
│   ├── hadf-design.md                 # From specs/hadf-hardware-aware-dispatch-design.md
│   ├── hadf-reference-impl.md         # From architecture/hadf-reference-implementations.md
│   ├── parallel-write-safety.md       # From architecture/parallel-code-write-safety-research.md
│   ├── framework-to-hardware.md       # NEW — synthesized from memory + mapping research
│   └── orchid-accelerator.md          # From specs/orchid-ai-accelerator-design.md
│
└── LICENSE                            # MIT or CC-BY-4.0
```

---

## 3. Heavy Curation Rules

For every doc copied into the showcase:

### Must Do
- Rewrite the title as a hook (question or "How we..." framing)
- Add a Context section (2-3 sentences) for zero-background readers
- Add a "Bottom Line" or "Key Takeaways" section at the end
- Strip ALL internal file paths, `.claude/` references, `/Volumes/DevSSD/` paths
- Strip personal details (email, health program, Supabase project IDs)
- Remove references to specific commit SHAs, branch names, PR numbers (unless adding a "shipped as PR #X" adds credibility)
- Replace internal cross-references with relative links within the showcase repo

### Should Do
- Restructure sections for storytelling (problem → approach → result → what we learned)
- Editorialized section headers ("Every New Capability Costs Before It Pays" not "Regressions")
- Collapse implementation details — keep the *what* and *why*, drop the *where in the repo*
- Target ~65-70% of original length

### Must Not
- Expose Swift source code, AppTheme tokens, or DesignTokens values
- Include `.claude/features/` state files or cache metrics
- Reference specific Supabase/Firebase/Sentry credentials or project IDs
- Include session handoffs, dated checkpoints, or internal diary entries

---

## 4. Showcase README

The root README.md is the most important file. Structure:

```markdown
# FitMe Engineering Showcase

> How a solo developer built and measured an AI-orchestrated product management
> framework across 16 shipped features — from v1.0 to hardware-aware dispatch.

## What This Is
[2-3 paragraphs: FitMe is an iOS fitness app. The interesting part isn't the app
— it's how it was built. AI-assisted PM framework evolved through 7 major versions,
measured with deterministic instrumentation, documented in 16 case studies.]

## The Numbers
[Key metrics table: 16 features, 6.5x speedup, 12.4x parallel throughput,
185 audit findings, 7 framework versions, ~120 min per major feature]

## Start Here
[Guided reading order for different audiences:
- "I have 5 minutes" → read 04-case-studies/README.md
- "I want the technical story" → start at 02-process-framework/
- "I want the research" → jump to 05-research/
- "I want everything" → read in order 01 → 05]

## About
[Brief: Built by Regev, iOS developer. School project that evolved into a
framework research platform. All docs are from real shipped work, not
hypotheticals.]
```

---

## 5. Source → Showcase Mapping

| Source (FitTracker2) | Showcase Target | Curation Notes |
|---|---|---|
| README.md | 01-product-vision/README.md | Strip tech stack details, focus on product story |
| CLAUDE.md | 02-process-framework/project-governance.md | Reframe as "how we enforce quality" |
| docs/product/PRD.md | 01-product-vision/master-prd.md | Keep vision/personas/metrics, drop internal tracking |
| docs/skills/evolution.md | 02-process-framework/framework-evolution.md | Highlight the v1→v7.0 arc, trim per-feature tables |
| docs/skills/architecture.md | 02-process-framework/skills-architecture.md | Heavy trim from 1900 → ~800 lines, keep diagrams |
| docs/design-system/ux-foundations.md | 03-design-system/ux-foundations.md | Light trim, already external-quality |
| 8 case studies | 04-case-studies/01-08 | Full heavy curation per rules above |
| meta-analysis + normalization | 04-case-studies/meta-* + normalization | Already have heavy-curated sample |
| architecture research (3 files) | 05-research/ | Strip implementation paths, keep the ideas |
| Orchid spec | 05-research/orchid-accelerator.md | Trim to architecture + novel contribution |
| HADF spec | 05-research/hadf-design.md | Trim to 5-layer architecture + fingerprinting method |

---

## 6. Files Explicitly Excluded

| Category | Count | Reason |
|---|---|---|
| Session handoffs/diaries | 7 | Time-specific internal state |
| Superseded plan versions | 4 | Noise — keep only latest |
| Templates/checklists | 5 | Procedural, not showcase-worthy |
| App Store/marketing | 4 | Off-topic for engineering showcase |
| Setup guides | 6 | Infrastructure-specific |
| Figma prompts (most) | 8 | Internal automation, not the story |
| Dated audits/closures | 6 | Superseded by latest versions |
| LOW-rated docs | 41 | Per inventory assessment |

---

## 7. Execution Plan (Next Session)

1. Create `fitme-showcase` repo on GitHub (public)
2. Scaffold directory structure
3. Write the showcase README.md first (sets the tone)
4. Heavy-curate Act 1 (product vision) — 6 docs
5. Heavy-curate Act 2 (process framework) — 6 docs
6. Heavy-curate Act 3 (design system) — 3 docs
7. Heavy-curate Act 4 (case studies) — 11 docs (already have 1 sample)
8. Heavy-curate Act 5 (research) — 6 docs
9. Add LICENSE (CC-BY-4.0 recommended for docs-only repo)
10. Final review pass — check for leaked paths, credentials, internal references
11. Push and verify rendering on GitHub

**Estimated effort:** ~2-3 hours of curation work across 32 docs.

---

## 8. Sync Strategy

Light sync script for future updates:

```bash
#!/bin/bash
# sync-showcase.sh — run from FitTracker2 root
# Only copies source files; curation is manual
DEST="../fitme-showcase"
echo "Syncing source files to $DEST/.source/"
mkdir -p "$DEST/.source"
# Copy raw sources for reference during re-curation
cp docs/case-studies/hadf-*.md "$DEST/.source/"
cp docs/case-studies/framework-measurement-*.md "$DEST/.source/"
# ... etc
echo "Sources synced. Manual curation required for public-facing files."
```

The sync copies raw sources into a `.source/` directory (gitignored) so you can diff against the curated versions when the originals change.
