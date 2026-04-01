# FitTracker2 — Master Backlog & Roadmap Plan

## Context
Following the successful merge of Design System v2 (PR #17) and CI fixes, the user wants to define and document the full project backlog across 8 work streams. Each task requires individual approval before execution. This plan serves as the docs & backlog definition.

---

## Task 1: Figma Working Prototype
**Approval needed:** Yes  
**Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD` (connected, Regev Barak Pro plan)

### What exists
- 22 screens across 7 product pages (approved and locked)
- Pages: Login (7 screens), Home (2), Nutrition (3), Training (4), Settings (6), Stats (1), Account (1)
- Partial prototype flows wired (auth → home, tab navigation)
- Component library: 6 atomic + 7 composite components
- 43 colorsets, 118 Figma variables

### Scope
- [ ] Audit current file structure via `get_metadata`
- [ ] Wire complete end-to-end prototype flow across all 22+ screens
- [ ] **NEW: Onboarding flow** — design welcome/walkthrough screens (3-5 slides)
  - Sketching or 3D animation style for onboarding illustrations
  - Cover: welcome, key features, permissions (HealthKit/notifications), get started
- [ ] **NEW: Live animations** — prototype animated transitions and micro-interactions
  - FitMeLogoLoader (breathe/rotate/pulse/shimmer) as loading states
  - Tab transitions, sheet presentations, card taps
  - Onboarding slide transitions with animation specs
- [ ] **NEW: Logo & custom icons** — integrate user-provided logo and icon assets
  - Generate logo from `FitMeLogoLoader.swift` (4 animation modes × 3 sizes)
  - Create static logo component in Figma based on the FitMe brand mark
  - Place custom icons alongside SF Symbol references
  - Update Icon Repository page
- [ ] **NEW: Onboarding illustration language** — define visual style
  - **DECIDED: Hand-drawn sketching style** (warm, approachable)
  - Apply consistently across onboarding slides + empty states + feature highlights
  - Line-art with brand colors (#FA8F40 orange, #8AC7FF blue accents)
- [ ] Add missing states: loading (FitMeLogoLoader), empty, error
- [ ] Create "Prototype / Full App Demo" page
- [ ] Connect all areas: Onboarding → Auth → Home → Training → Nutrition → Stats → Settings → Account

### Tools: Figma MCP (`get_metadata`, `get_design_context`, `use_figma`, `create_new_file`)

---

## Task 2: Android Design System Investigation
**Approval needed:** Yes

### 2.1 What we have (iOS)
- 92 semantic tokens (57 colors, 9 spacing, 9 radius, 20 typography, motion, shadows)
- 43 asset catalog colorsets (Light + Dark)
- 13 shared components with contracts
- Token pipeline: `tokens.json` → Style Dictionary → Swift
- `docs/design-system/android-adaptation.md` — strategy doc exists

### 2.2 What adapts directly
- Color hex values (platform-agnostic)
- Spacing (4pt grid = MD3 base unit)
- Radius (maps to MD3 shape scale)
- Shadow/elevation → MD3 elevation
- Backend (Supabase + AI Engine) — fully portable
- `design-tokens/tokens.json` — can add Android output via Style Dictionary

### 2.3 Gaps
| iOS | Android Equivalent | Status |
|-----|-------------------|--------|
| SF Pro Rounded | Roboto / Nunito | Needs mapping |
| SF Mono | JetBrains Mono / Roboto Mono | Needs mapping |
| Spring physics animations | Material easing curves | Needs translation |
| Tab bar | BottomNavigationBar + NavigationRail | Needs redesign |
| SwiftUI components | Jetpack Compose MD3 | Needs rebuild |
| HealthKit | Google Health Connect | Needs new integration |
| Apple Sign In | Google Sign In | Needs new provider |
| Foundation Models (iOS 26) | Gemini Nano / TF Lite | Needs research |
| SF Symbols (87 icons) | Material Symbols | Needs 1:1 mapping |
| Keychain | EncryptedSharedPreferences | Needs migration |
| CloudKit sync | (remove — Supabase covers this) | N/A |

### 2.4 What needs to change
- Add Android platform to `sd.config.js` (Style Dictionary)
- Expand Figma "Platform Adaptations" page
- Add MD3 variant column to component contracts
- Create adaptive navigation specs (compact/medium/expanded)

### 2.5 Asset conversion research
- [ ] iOS colorsets → `colors.xml` / Compose `Color` objects
- [ ] SF Symbols → Material Symbols mapping table
- [ ] Compose theme generation from `tokens.json`
- [ ] iOS animation presets → Material motion specs

### Key files
- `docs/design-system/android-adaptation.md`
- `design-tokens/tokens.json`, `sd.config.js`
- `docs/design-system/responsive-handoff-rules.md`

---

## Task 3: Android Full App Build Research
**Approval needed:** Yes

### Current iOS architecture
| Layer | iOS | Portable? |
|-------|-----|-----------|
| UI | SwiftUI (declarative) | No — needs Compose |
| State | ObservableObject / @StateObject | No — needs ViewModel |
| Auth | Apple Sign In + Supabase Auth | Partial (Supabase portable) |
| Data | EncryptedDataStore (local) | No — needs Room + encryption |
| Sync | CloudKit + Supabase | Supabase yes, CloudKit no |
| Health | HealthKit | No — needs Health Connect |
| AI | Foundation Models + Cloud API | Cloud yes, on-device needs research |
| Crypto | CryptoKit (AES-GCM) | No — needs Tink/JCA |
| Backend | Supabase (Postgres + Auth + Realtime) | Yes — supabase-kt exists |
| AI Engine | FastAPI on Railway | Yes — REST API, fully portable |

### Research deliverables
- [ ] Native Kotlin+Compose vs React Native vs KMP — pros/cons matrix
- [ ] Architecture mapping: SwiftUI→Compose, ObservableObject→ViewModel, etc.
- [ ] Platform API mapping: HealthKit→Health Connect, Keychain→EncryptedSharedPrefs
- [ ] Supabase Android SDK (supabase-kt) compatibility
- [ ] Google Health Connect scope and permissions
- [ ] On-device ML: Gemini Nano vs TF Lite vs ML Kit
- [ ] Effort estimate per approach

### Key files to scan
- `FitTracker/FitTrackerApp.swift` — 57 lines, wires 10 services
- `FitTracker/Services/` — Auth, Encryption, HealthKit, CloudKit, Supabase
- `FitTracker/AI/` — AIOrchestrator, AIEngineClient, FoundationModelService
- `FitTracker/Models/DomainModels.swift` — data models
- `ai-engine/` & `backend/` — fully portable

---

## Task 4: Google Analytics Integration
**Approval needed:** Yes

### Scope
- [ ] Define analytics goals (engagement, retention, funnel conversion)
- [ ] Create event taxonomy with naming conventions
- [ ] Map all screens → `screen_view` events
- [ ] Map all user actions → custom events
- [ ] Define user properties (training phase, app version, platform)
- [ ] Define conversion funnels: onboarding → first workout → first meal → weekly streak
- [ ] Define custom dimensions: day type, nutrition adherence, readiness score
- [ ] Integration plan: Firebase Analytics SDK (iOS + future Android)
- [ ] Privacy: GDPR consent, data retention, opt-out
- [ ] Dashboard requirements

### Screens to map (25 views)
Auth (4) · Home (1) · Training (1) · Nutrition (4) · Stats (2) · Settings (2) · Shared (9) · Root (1) · DesignSystem (1)

---

## Task 5: Skills Feature
**Approval needed:** Yes — needs specification first

### Status
- Referenced in prior sessions as a planned feature
- No formal spec found in `docs/` directory
- Master plan (`docs/superpowers/specs/2026-03-30-fittracker-master-plan-design.md`) may contain references

### Deliverables needed
- [ ] Retrieve any prior specs from docs or conversation history
- [ ] Define skill categories and progression model
- [ ] Design data model
- [ ] Design UI screens
- [ ] Integrate with training + stats systems

---

## Task 6: Full Memory & Backlog Dump
**Approval needed:** Yes

### Sources to compile into structured backlog
| Source | Content |
|--------|---------|
| `README.md` | Project overview, current state |
| `CHANGELOG.md` | 5-phase milestone history (Feb 28 → Mar 29) |
| `docs/design-system/feature-memory.md` | Feature tracking entries |
| `docs/design-system/gap-review-and-backlog.md` | Known gaps |
| `docs/design-system/deferred-phone-otp-task.md` | Deferred: phone OTP registration |
| `docs/project/resume-handoff-2026-03-29.md` | Latest handoff state |
| `docs/superpowers/specs/*` | v2 redesign + master plan |
| Session work today | CI fixes, PR #17 merge, PR #18, design system audit |

### Output: structured doc with Done / In Progress / Planned / Backlog categories

---

## Task 7: Notion MCP Integration
**Approval needed:** Yes — requires session restart

### Finding
User added Notion MCP to Claude Code config, but it's **not yet visible** in this session's tool list. This likely requires a **session restart** for the MCP server to initialize.

### Next steps
1. Restart Claude Code session to pick up Notion MCP server
2. Once connected, verify with `notion_search` or similar tool
3. Create FitTracker workspace structure in Notion:
   - **Roadmap** database (timeline view)
   - **Backlog** database (kanban: Done / In Progress / Planned / Backlog)
   - **Design System** page (token reference)
   - **Research** pages (Android, Analytics, Marketing)
4. Transfer all backlog items from Task 6 into Notion databases

### Alternatives (if Notion is unavailable after restart)
1. Use **GitHub Issues + Project board** as backlog
2. Generate **Markdown backlog doc** to paste into Notion manually

---

## Task 8: Marketing Mini-Site
**Approval needed:** Yes

### Deliverables
- [ ] Define site structure: hero, features, screenshots, download CTA
- [ ] Choose stack: static site (Astro/Next.js) or simple HTML/Tailwind
- [ ] Source screenshots from Figma or Simulator
- [ ] Write copy: tagline, feature descriptions
- [ ] Design using FitTracker brand tokens (#FA8F40 primary, #8AC7FF secondary)
- [ ] Deploy: Vercel / Netlify / GitHub Pages
- [ ] App Store / Play Store badges
- [ ] SEO + Open Graph metadata

### Brand assets available
- Brand name: **FitMe** (per `AppBrand.name`)
- Primary: #FA8F40 (orange), Secondary: #8AC7FF (blue)
- FitMeLogoLoader animation system in code
- 22 screens available for screenshots

---

## Execution Order (recommended)
1. **Task 7** — Notion setup (quick, unblocks backlog management)
2. **Task 6** — Full backlog dump (foundation for everything else)
3. **Task 1** — Figma prototype (visual foundation)
4. **Task 4** — Analytics definition (measurement before building)
5. **Task 2** — Android design system investigation
6. **Task 3** — Android build research
7. **Task 5** — Skills feature spec
8. **Task 8** — Marketing mini-site

## Verification
Each task produces a reviewable deliverable (Figma prototype, research doc, event taxonomy, backlog doc, deployed site) that can be verified independently.
