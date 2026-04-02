# Figma Prototype — Audit & Task List

> Generated from MCP audit + codebase documentation review.  
> File: [FitTracker Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)  
> Date: 2026-04-02

---

## Current State (~40% prototype-ready)

### Pages confirmed (from figma-library-progress.md)

| Page | Content | Status |
|------|---------|--------|
| Cover | Library overview card | Complete |
| Getting Started | Usage guide + review standard | Complete |
| Foundations | Colors, typography, spacing, radius, elevation, motion, UX copy | Complete |
| Components | 9 component families with variants | Complete |
| Patterns | Layout guidance | Complete |
| Platform Adaptations | iPhone runtime specs | Complete |
| Icon Repository | SF Symbol reference | Complete |
| Typography Repository | AppText roles | Complete |
| App Icon + App Store | Icon specs + submission guidelines | Complete |
| Login | Auth screens + integrated runtime board | Complete |
| Main Screen (Home) | Today summary + integrated runtime board | Complete |
| Training | Scheduled session + rest day + runtime board | Complete |
| Nutrition | Meal logging + empty state + runtime board | Complete |
| Stats | Chart tabs + empty state + runtime board | Complete |
| Settings | Grouped dashboard + category detail | Partial |
| Account & Security | Sign-in methods, sync status | Partial |
| Onboarding | Placeholder page | Not started |
| Prototype / iPhone App | Starting flow navigation | Partial |
| Prototype / Flow Map | Navigation overview | Partial |

### Design system foundations (complete)

| Collection | Variables |
|------------|-----------|
| Color / Semantic | 46 |
| Text / Roles | 22 |
| Spacing | 8 |
| Radius | 6 |
| Elevation | 6 |
| Motion | 4 |
| **Total** | **92** |

### Component families (9 complete)

AppButton, AppCard, AppMenuRow, AppSelectionTile, AppInputShell, AppFieldLabel, AppQuietButton, StatusBadge, EmptyStateView

---

## Missing Screens (14 needed for 22+ total)

### Priority 1 — Complete core flows
- [ ] Email Verification (completes auth flow)
- [ ] Meal Entry Sheet (4-tab: smart, manual, template, search)
- [ ] Active Training Session (timer, set entry, in-progress)
- [ ] Training Completion Sheet (volume delta, PRs, notes)

### Priority 2 — Onboarding (new flow)
- [ ] Onboarding Slide 1: Welcome + FitMeLogoLoader animation
- [ ] Onboarding Slide 2: Training features
- [ ] Onboarding Slide 3: Nutrition features
- [ ] Onboarding Slide 4: Recovery + AI features
- [ ] Onboarding Slide 5: Privacy + HealthKit permission

### Priority 3 — Settings detail screens
- [ ] Health & Devices (HealthKit, Watch, scale)
- [ ] Goals & Preferences (units, appearance, goals)
- [ ] Training & Nutrition (nutrition mode, meal slots, thresholds)
- [ ] Data & Sync (sync status, backup, export)

### Priority 4 — State variants
- [ ] Empty states: Home, Training (rest day), Nutrition (no meals), Stats (no data)
- [ ] Loading states: skeleton screens with FitMeLogoLoader
- [ ] Error states: network error, auth failure, sync failed

---

## Navigation Flows to Wire

| Flow | Status | Screens |
|------|--------|---------|
| Auth | Partial | Welcome → AuthHub → [Apple/Email] → Email Verification → Home |
| Tab navigation | Partial | Home ↔ Training ↔ Nutrition ↔ Stats (+ Settings) |
| Training session | Not started | Scheduled → Active Session → Completion |
| Meal logging | Not started | Nutrition → MealEntrySheet → Save → Nutrition |
| Settings drill-down | Partial | Settings → each detail screen → back |
| Onboarding | Not started | Slides (1-5) → Auth |

---

## MCP Automation Limitations

| Capability | MCP Support | Notes |
|------------|-------------|-------|
| Read existing nodes | Yes | `get_metadata`, `get_design_context` |
| Take screenshots | Yes | `get_screenshot` — can export approved screens |
| Read variables/tokens | Yes | `get_variable_defs`, `search_design_system` |
| Create new frames | No | Official MCP cannot persist new frames on canvas |
| Wire prototype hotspots | No | Prototype connections not exposed via API |
| Create component variants | Partial | `use_figma` can create some variants |
| Enumerate pages | No | Must know node IDs; can't list all pages |

**Conclusion:** Screen creation and prototype wiring require manual Figma work or figma-console-mcp (Desktop Bridge). The MCP can assist with auditing, screenshots, and token verification.

---

## Recommended Next Steps

1. **Manual:** Open Figma file and note page/frame node IDs for all product screens
2. **Manual:** Create 14 missing screen designs (Priority 1-3 above)
3. **Manual:** Wire 6 navigation flows end-to-end
4. **MCP-assisted:** Once screens exist, use `get_screenshot` to capture all 6+ screens
5. **Code:** Export screenshots to `docs/screenshots/` and update README placeholder
