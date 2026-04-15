# Onboarding v2 Auth Flow — Task Breakdown

> **Phase:** Tasks (Phase 2)
> **Work Type:** Feature
> **Total Tasks:** 12
> **Estimated Effort:** ~3 days

---

## Dependency Graph

```
T1 (fix session restore)
│
T2 (OnboardingAuthView)
├── T3 (OnboardingSuccessView)
│   └── T4 (OnboardingView container — wire steps 5-7)
│       └── T5 (simplify FitTrackerApp rootView)
│           └── T6 (persist profile on sign-up)
│
T7 (fix "Intermediate" truncation)          ┐
T8 (update OnboardingProgressBar for 8 steps)│ parallel, independent
T9 (analytics events + params)              ┘
│
T10 (returning user shortcut — "Log In")
│
T11 (analytics convenience methods + taxonomy CSV)
│
T12 (build verification + regression tests)
```

---

## Tasks

### T1: Fix session restore freeze
- **Type:** backend
- **Skill:** dev
- **Complexity:** heavyweight
- **Files:** `SignInService.swift`
- **Depends on:** —
- **Details:** Wrap `supabase.auth.session` call in `Task.detached` with 5s timeout using `withThrowingTaskGroup`. If timeout or error, clear stored session and let rootView show auth. Remove blocking `await` on main actor.
- **Acceptance:** App launch with real Supabase credentials does not freeze. Valid session → Home. Expired/failed → onboarding/auth.

### T2: Create OnboardingAuthView
- **Type:** ui
- **Skill:** dev
- **Complexity:** heavyweight
- **Files:** new `FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift`
- **Depends on:** —
- **Details:** Onboarding-styled auth screen with Email, Google, Apple buttons. Reuses `SignInService` methods (signInWithEmail, signInWithGoogle, signInWithApple). Onboarding visual style (AppGradient.screenBackground, AppColor tokens). "Already have an account? Log In" link. Inline error banner for failures. Takes `onAuthenticated: (UserSession) -> Void` and `onLogin: () -> Void` callbacks.
- **Acceptance:** Screen renders with 3 auth options + login link. Tapping each fires the correct SignInService method.

### T3: Create OnboardingSuccessView
- **Type:** ui
- **Skill:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/Views/Onboarding/v2/OnboardingSuccessView.swift`
- **Depends on:** T2
- **Details:** Animated checkmark (scale + opacity transition) + "Welcome to FitMe, {name}!" using display name from active session. Auto-advances after 2s via `.task { try? await Task.sleep(for: .seconds(2)); onContinue() }`. Tap anywhere to skip. Uses AppMotion tokens, respects reduceMotion.
- **Acceptance:** Animation plays, name shows, auto-advances after 2s. Tap skips.

### T4: Wire new steps into OnboardingView container
- **Type:** ui
- **Skill:** dev
- **Complexity:** heavyweight
- **Files:** `OnboardingView.swift`
- **Depends on:** T2, T3
- **Details:** Update `totalSteps` from 6 → 8. Add OnboardingAuthView at tag 5 with `onAuthenticated` callback that advances to step 6. Add OnboardingSuccessView at tag 6. Move OnboardingFirstActionView to tag 7. Update `stepName()` mapping. Handle returning user: `onLogin` callback skips to `completeOnboarding()` directly.
- **Acceptance:** Full 8-step flow works end-to-end in simulator.

### T5: Simplify FitTrackerApp rootView
- **Type:** backend
- **Skill:** dev
- **Complexity:** heavyweight
- **Files:** `FitTrackerApp.swift`
- **Depends on:** T1, T4
- **Details:** Remove `AuthHubView` from rootView. After `hasCompletedOnboarding = true`, user is already authenticated → show RootTabView. If not authenticated AND onboarding complete → reset `hasCompletedOnboarding` to force re-onboarding (catches edge case of sign-out). Keep biometric lock flow.
- **Acceptance:** rootView has 3 states: onboarding → RootTabView → biometric lock. No AuthHubView.

### T6: Persist profile data on sign-up
- **Type:** backend
- **Skill:** dev
- **Complexity:** lightweight
- **Files:** `OnboardingView.swift`, `SupabaseSyncService.swift`
- **Depends on:** T4, T5
- **Details:** After successful auth in step 5, trigger `supabaseSync.pushPendingChanges()` to sync profile, goals, preferences set in steps 1-3 to Supabase immediately.
- **Acceptance:** After sign-up, Supabase `sync_records` table has the user's profile data.

### T7: Fix "Intermediate" text truncation
- **Type:** ui
- **Skill:** dev
- **Complexity:** lightweight
- **Files:** `OnboardingProfileView.swift`
- **Depends on:** —
- **Details:** Add `.minimumScaleFactor(0.8)` and `.lineLimit(1)` to `ExperienceCard` label Text view.
- **Acceptance:** "Intermediate" displays fully on all supported screen sizes.

### T8: Update OnboardingProgressBar for 8 steps
- **Type:** ui
- **Skill:** dev
- **Complexity:** lightweight
- **Files:** `OnboardingProgressBar.swift`, `OnboardingView.swift`
- **Depends on:** —
- **Details:** Update progress bar to reflect 8 total steps. Hide on steps 0 (welcome), 5 (auth), and 6 (success). Show on steps 1-4 and 7.
- **Acceptance:** Progress bar renders correctly for 8 steps with proper hide/show logic.

### T9: Add analytics event constants + params
- **Type:** analytics
- **Skill:** analytics
- **Complexity:** lightweight
- **Files:** `AnalyticsProvider.swift`
- **Depends on:** —
- **Details:** Add 5 event constants: `onboarding_auth_method_selected`, `onboarding_auth_completed`, `onboarding_auth_failed`, `onboarding_success_shown`, `session_restore_result`. Add 4 param constants: `method`, `is_new_account`, `error_type`, `result` (check for duplicates — `method` may already exist). Add `restore_time_ms` as int param.
- **Acceptance:** Constants compile, no duplicates with existing enums.

### T10: Returning user shortcut
- **Type:** ui
- **Skill:** dev
- **Complexity:** lightweight
- **Files:** `OnboardingAuthView.swift`, `OnboardingView.swift`
- **Depends on:** T2, T4
- **Details:** "Log In" link on OnboardingAuthView shows email login or Google/Apple. On successful login, call `onLogin()` which triggers `completeOnboarding()` → skip success + first action → go to Home.
- **Acceptance:** Returning user can log in at step 5 and reach Home without steps 6-7.

### T11: Analytics convenience methods + taxonomy CSV
- **Type:** analytics
- **Skill:** analytics
- **Complexity:** lightweight
- **Files:** `AnalyticsService.swift`, `docs/product/analytics-taxonomy.csv`
- **Depends on:** T9
- **Details:** Add typed convenience methods: `logOnboardingAuthMethodSelected(method:)`, `logOnboardingAuthCompleted(method:isNewAccount:)`, `logOnboardingAuthFailed(method:errorType:)`, `logOnboardingSuccessShown()`, `logSessionRestoreResult(result:timeMs:)`. Add rows to taxonomy CSV.
- **Acceptance:** Methods compile, events fire correctly when called.

### T12: Build verification + regression tests
- **Type:** test
- **Skill:** qa
- **Complexity:** heavyweight
- **Files:** `FitTrackerTests/`
- **Depends on:** T5, T6, T9, T11
- **Details:** Run full build + test suite. Verify all 197+ tests pass. Verify new analytics events fire correctly. Verify no regressions in existing onboarding events. Test session restore timeout path.
- **Acceptance:** Build succeeds, all tests pass, no regressions.

---

## Task Summary

| ID | Task | Type | Complexity | Depends On | Lane |
|---|---|---|---|---|---|
| T1 | Fix session restore freeze | backend | heavyweight | — | P-core |
| T2 | OnboardingAuthView | ui | heavyweight | — | P-core |
| T3 | OnboardingSuccessView | ui | lightweight | T2 | E-core |
| T4 | Wire steps into OnboardingView | ui | heavyweight | T2, T3 | P-core |
| T5 | Simplify rootView | backend | heavyweight | T1, T4 | P-core |
| T6 | Persist profile on sign-up | backend | lightweight | T4, T5 | E-core |
| T7 | Fix "Intermediate" truncation | ui | lightweight | — | E-core |
| T8 | Update progress bar | ui | lightweight | — | E-core |
| T9 | Analytics event constants | analytics | lightweight | — | E-core |
| T10 | Returning user shortcut | ui | lightweight | T2, T4 | E-core |
| T11 | Analytics convenience methods | analytics | lightweight | T9 | E-core |
| T12 | Build verification | test | heavyweight | T5, T6, T9, T11 | P-core |

**Parallel opportunities (E-core first):**
- T1, T2, T7, T8, T9 can all start immediately (no dependencies)
- T3, T11 unblock after T2 and T9 respectively
- T10 unblocks after T2 + T4
- T5 requires both T1 and T4
- T12 is the final gate
