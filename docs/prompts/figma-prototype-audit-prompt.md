# Prompt: Audit & Fix FitMe Figma Prototype Connections

> Paste into a Claude session with Figma MCP connected.
> Last verified: 2026-04-04 — 28 screens, 58 connections, 0 broken links.

---

```
I need you to audit and fix the Figma prototype connections for the FitMe app.

## File Info
- Figma file key: 0Ai7s3fCFqR5JXDW8JvgmD
- URL: https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD
- Prototype page: "Prototype / iPhone App"
- Starting frame: "Onboarding / Welcome"

## Current State (as of 2026-04-04)
- 28 screens on the Prototype page
- 58 prototype connections wired
- 0 broken links, 0 orphans, 0 dead ends
- Flow starting point set to "Onboarding / Welcome"

## Screens on the Prototype Page

Onboarding:
- Onboarding / Welcome → Onboarding / Training → Onboarding / Nutrition → Onboarding / Recovery & AI → Onboarding / Privacy + Permissions

Auth:
- Login — Email Entry, Login — Returning User, Registration, Email Verification, Face ID Auto-Unlock

Core Tabs:
- Home / Today Summary (hub — connects to all tabs + settings + training + biometrics)
- Training / Rest Day, Training / Upper Push Active, Session Completion
- Nutrition / Today
- Stats
- Manual Biometric Entry (overlay from Home)
- Rest Timer Overlay (overlay from Training)

Meal Entry (4-tab modal):
- MealEntry / Smart Tab, MealEntry / Manual Tab, MealEntry / Template Tab, MealEntry / Search Tab

Settings:
- Settings / Dashboard → Settings / Account & Security, Settings / Health & Devices, Settings / Goals & Preferences, Settings / Training & Nutrition, Settings / Data & Sync

## Expected Navigation Flows

1. **Onboarding**: Welcome → Training → Nutrition → Recovery → Privacy → Login
2. **Auth (email)**: Login Email → Registration → Email Verification → Home
3. **Auth (returning)**: Login Returning → Face ID → Home
4. **Tab bar** (on Home, Training, Nutrition, Stats): Tab / Home ↔ Tab / Training Plan ↔ Tab / Nutrition ↔ Tab / Stats
5. **Training**: Rest Day → Active Session → Session Completion → Home (Done button) or Training (frame click)
6. **Nutrition**: Today → MealEntry (Smart) → tab switching between all 4 tabs → back to Today
7. **Settings**: Dashboard → each detail screen → back to Dashboard (frame click)
8. **Overlays**: Home METRICS → Manual Biometric Entry → Home, Training Active → Rest Timer → Training Active

## Task

1. **Audit all connections** — Run a script on the Prototype page to find:
   - All screens and their outgoing connections
   - Broken links (destinationId points to deleted node)
   - Orphan screens (no incoming or outgoing)
   - Dead ends (incoming but no outgoing)
   - Missing expected connections from the flows above

2. **Fix any issues found**:
   - Re-wire broken links
   - Connect orphan screens
   - Add back buttons to dead-end screens
   - Wire tab bar connections if missing (children named "Tab / Home", "Tab / Training Plan", etc.)

3. **Verify tab bar wiring** — On each screen with a tab bar:
   - Find the "Tab Bar" frame → "Tabs" container → individual "Tab / {name}" children
   - Each tab should have ON_CLICK → NAVIGATE to the corresponding screen
   - Use SMART_ANIMATE with EASE_IN_AND_OUT, 0.2s duration

4. **Report** — List all connections after fixing, grouped by flow.

## Important Notes
- Tab bar child names: "Tab / Home", "Tab / Training Plan", "Tab / Nutrition", "Tab / Stats"
- Use SMART_ANIMATE transitions (0.2-0.3s) for all navigation
- Settings detail screens use frame click → back to Dashboard
- MealEntry tabs should support switching between all 4 tabs
- Flow starting point must remain "Onboarding / Welcome"
```
