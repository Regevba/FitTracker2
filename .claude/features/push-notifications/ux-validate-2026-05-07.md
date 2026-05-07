# UX Validation Report — push-notifications-v2

**Phase:** 3 (UX/Integration), Step 3d (`/ux validate`)
**Date:** 2026-05-07
**Spec:** `.claude/features/push-notifications/ux-spec.md`

---

## 1. Nielsen's 10 Heuristics (0–4 scale: 0=fail, 4=excellent)

| # | Heuristic | Score | Notes |
|---|---|---|---|
| 1 | Visibility of system status | **4** | Settings row dynamic CTA shows current authorization state. Priming view hides on grant. Banner appears once on denial, then quiet. State machine documented. |
| 2 | Match between system and real world | **4** | Copy is plain English ("Stay on track with smart reminders"); benefit-framed not mechanism-framed; no jargon. |
| 3 | User control and freedom | **4** | "Not now" preserves OS one-shot privilege; swipe-down-to-dismiss equivalent; settings entry always available; banner dismissible permanently. |
| 4 | Consistency and standards | **4** | Sheet+CTA pattern matches iOS HealthKit / Strava / Hevy. AppText/AppSpacing/AppRadius tokens used throughout. SF Symbols for icons. |
| 5 | Error prevention | **4** | Client-side state machine prevents calling `requestAuthorization()` if already known denied (routes to Settings). One-time banner — never re-prompt. Idempotent deep-link router. |
| 6 | Recognition rather than recall | **4** | Settings row label changes by state. Category list visible on priming (not "you'll get reminders"). Banner names what's off ("Notifications are off"). |
| 7 | Flexibility and efficiency | **3** | Settings row supports quick re-entry; sheet detents support both glance + full read. **Note:** P2-deferred preferences sub-screen would lift this to 4 (per-type granular toggles). |
| 8 | Aesthetic and minimalist design | **4** | Single primary CTA per surface. Hero icon + title + body + 3 categories — no over-decoration. Bell.badge.fill is iconic. |
| 9 | Help users recognize, diagnose, recover from errors | **4** | Denial → banner explicitly says "Notifications are off" + "Open Settings" with one-tap recovery. Cold-start race handled (queue pendingDeepLink). |
| 10 | Help and documentation | **3** | No in-app help docs (priming text IS the help). **Note:** acceptable for v2; no dedicated help link inside the priming sheet to settings/privacy policy. Could add in P2. |

**Overall heuristic score: 38/40 (95%).** No failures. Two 3-of-4 scores are explicit P2-deferral acknowledgments, not violations.

---

## 2. 13 ux-foundations Principles — Compliance Check

| # | Principle | Verdict | Evidence in spec |
|---|---|---|---|
| 1 | Fitts's Law | ✓ Pass | Primary CTA height = `AppSize.ctaHeight` (48pt), full-width, sheet-anchored bottom — ideal thumb zone (§2.1) |
| 2 | Hick's Law | ✓ Pass | One primary CTA + one secondary action per sheet. No choice fan-out. |
| 3 | Jakob's Law | ✓ Pass | Sheet+CTA matches iOS HealthKit and competitor apps (§7) |
| 4 | Progressive Disclosure | ✓ Pass | Title + body + 3-category summary; no all-9-example dump (§7) |
| 5 | Recognition over Recall | ✓ Pass | Settings row dynamic label; category list on priming (§7) |
| 6 | Consistency | ✓ Pass | All tokens semantic; component reuse > new components (§8 inventory shows 1 revived + 4 new platform pieces, no parallel-DS-divergence) |
| 7 | Feedback | ✓ Pass — critical for v2 | DeepLinkRouter routing as trust contract (§7); haptic on grant (§5) |
| 8 | Error Prevention | ✓ Pass | State machine + UserDefaults flag (§7) |
| 9 | Readiness-First | n/a | Not a Home/dashboard surface; doesn't apply |
| 10 | Zero-Friction Logging | n/a | No data-entry surface |
| 11 | Privacy by Default | ✓ Pass | Local notifications only; consent-gated analytics; content never logged (§7) |
| 12 | Progressive Profiling | ✓ Pass — critical for v2 | Trigger is post-first-workout-completed, not first-app-open (§7) |
| 13 | Celebration Not Guilt | ✓ Pass | readinessAlert low: "Consider a light session or rest"; no badge counts; no "you missed" framing (§7, §2.4) |

**Principle verdict:** 11/11 applicable principles pass. 2 not-applicable (Readiness-First, Zero-Friction Logging).

---

## 3. State Coverage

Per §4 of spec — every surface has all required states (default/loading/empty/error/success/disabled), with explicit "n/a" rationales where a state doesn't apply.

| Surface | All states covered? |
|---|---|
| PrimingView (sheet) | ✓ — initial / denied / granted (no loading or empty needed) |
| SettingsDeepLinkBanner | ✓ — visible / hidden (states are conditional, not asynchronous) |
| Settings → Notifications row | ✓ — 3 distinct labels per authorization state |
| Delivered notification | ✓ — banner+sound default; suppressed-with-reason for caps; tap routes |

**State coverage verdict: PASS.**

---

## 4. Accessibility Coverage

Per §6 of spec.

| Check | Verdict |
|---|---|
| All interactive elements have `accessibilityLabel` | ✓ — 6 of 6 (CTA, Not Now, Open Settings, Dismiss X, Settings row, Category list) |
| All buttons ≥ 44pt tap target | ✓ — primary CTA 48pt; default Button frames pass; dismiss X is 32pt visual + 12pt touch slop = 44pt+ effective |
| Dynamic Type support | ✓ — all text uses scaling tokens (`AppText.*`) |
| VoiceOver decorative-icon hiding | ✓ — bell icon `.accessibilityHidden(true)` |
| Reduce Motion alternative | ✓ — banner slide-in respects `accessibilityReduceMotion` |
| Color contrast (WCAG AA) | Deferred to `/design preflight` + `/design audit` (token compliance is a /design concern) |

**Accessibility verdict: PASS at /ux level.** /design will validate WCAG AA contrast at the next step.

---

## 5. CX Signal Cross-Reference

`grep -i "notif\|reminder\|alert\|deep.link\|priming\|permission" .claude/shared/cx-signals.json` → 0 matches.

v1's `notification_*` events have never fired in production (zero GA4 history per Phase 9 v1 case study). Smart-reminders' deep links don't route, so user complaints about "tapped reminder, nothing happened" would be the symptom — none surfaced.

**CX signal verdict: silent (no negative signal; no positive signal). No spec changes triggered.**

---

## 6. Findings Summary

| Severity | Count | Notes |
|---|---|---|
| BLOCKING | 0 | — |
| Should-fix (heuristic gap) | 0 | — |
| Defer-to-P2 (acknowledged) | 2 | (a) Per-type preferences sub-screen for granular control (Heuristic #7 partial); (b) In-app help/privacy link from priming sheet (Heuristic #10 partial) |

**Both deferred items are already in PRD §"P2 — Later / Stretch" (PN-19 preferences UI).** Heuristic #10 (in-sheet help link) added to backlog as a follow-on enhancement under preferences UI work.

---

## 7. Verdict

**PASS — proceed to `/ux preflight` (P0 gate).**

Spec is heuristically sound, principle-compliant, accessibility-complete at /ux level, and state-covered. No blocking findings.
