# App Store Assets — Task Breakdown

**PRD:** `docs/product/prd/app-store-assets.md`
**Estimated effort:** 4.0 days
**Critical path:** T1 → T3 → T5 → T8 → T10

## Tasks

| ID | Title | Type | Skill | Effort | Depends On | Status |
|---|---|---|---|---|---|---|
| T1 | Export 1024x1024 master icon from Figma (node 635:2) | design | design | 0.25d | — | pending |
| T2 | Generate all iOS icon sizes (AppIcon.xcassets) | config | dev | 0.25d | T1 | pending |
| T3 | Add xcassets to Xcode project + verify build | config | dev | 0.25d | T2 | pending |
| T4 | Capture 5 canonical screenshots (6.7" + 6.5") | design | design | 1.0d | — | pending |
| T5 | Screenshot template with device frame + captions | design | design | 0.5d | T4 | pending |
| T6 | Write App Store metadata (title, subtitle, keywords, description) | content | marketing | 0.5d | — | pending |
| T7 | Privacy policy URL + support URL | content | marketing | 0.25d | — | pending |
| T8 | App Store Connect listing configuration | config | release | 0.5d | T3, T5, T6, T7 | pending |
| T9 | App Preview video (15-30s, P2) | design | design | 0.5d | T4 | pending |
| T10 | Submission verification + build upload test | test | release | 0.25d | T8 | pending |

## Screenshot Story (5-screen canonical order)

1. **Home / Today** — readiness score, dual CTAs, body composition
2. **Training** — live set log, exercise cards, rest timer
3. **Nutrition** — macro targets, meal log, supplement streak
4. **Stats** — weight + body fat charts, period picker, metric chips
5. **Onboarding** — welcome screen with FitMe brand icon

## Dependencies

- Apple Developer Program enrollment (hard blocker for T8, T10)
- Figma master icon at node 635:2 (exists)
- Simulator screenshots require test data populated
