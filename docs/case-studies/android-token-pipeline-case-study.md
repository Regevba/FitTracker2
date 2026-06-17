---
title: "Android Token Pipeline — making the design system real (AND-1)"
date_written: 2026-06-17
work_type: Enhancement
dispatch_pattern: single-session implement (config + scripts + artifacts + docs)
framework_version: v7.10
primary_metric: "tokens.json generates committed, drift-gated Android artifacts; tokens:android:check passes and fails on drift"
success_metrics:
  - "Pipeline runs with 0 errors; 3 artifacts generated (T1)"
  - "Byte-identical across consecutive builds (T1)"
  - "Drift gate green in-sync, red on any token edit (T1)"
  - "49 colors + 34 dimens + 8 Compose objects; 0 duplicate resource names (T1)"
kill_criteria:
  - "Generated Kotlin won't compile in a real Android module"
  - "Drift gate false-positives on a clean tree"
  - "Style Dictionary v6 removes the v5 format API"
kill_criteria_resolution: "K2 resolved (determinism byte-identical, gate green on clean tree). K1 not yet evaluable — no in-repo Android toolchain (AND-3 deferred); validated structurally, not compiled. K3 future-watch — config depends on no built-in transform group; reviewed at quarterly audit + on any style-dictionary major bump."
tier_tags_present: true
parent_feature: android-design-system
predecessor: docs/case-studies/android-design-system-case-study.md
---

# Android Token Pipeline — making the design system real (AND-1)

## The problem: a design system that was "Android" in name only

The `android-design-system` feature shipped 2026-04-04 as a **research-only**
deliverable — an iOS→Material-Design-3 mapping doc, an adaptation strategy, and a
Style Dictionary config. But it generated **nothing**. Two and a half months later
the reality (T1, audited 2026-06-17):

- `design-tokens/config-android.json` was **broken** — it referenced Style
  Dictionary transforms `size/compose/dp` and `size/compose/sp` that don't exist
  (the real compose group ships rem-input transforms), and it was written against
  Style Dictionary **v3** while the repo had since migrated to **v5** (2026-06-08).
  `npm run tokens` had no Android target. No `.kt` or `.xml` existed anywhere.
- `docs/design-system/android-token-mapping.md` was **stale** — documented 92
  tokens against a source that had restructured to 108 (66 actionable).

This is precisely the silent-gap class the FitMe framework exists to kill: a config
that *looks* like a pipeline but produces no artifact, with a doc that *looks*
current but tracks a two-month-old schema. No gate caught it because nothing
consumed it — the classic "no consumer, no signal" blind spot.

## What shipped

Mirror the working iOS pipeline (`sd.config.mjs` → `DesignTokens.swift`, gated by
`make tokens-check`) for Android, reusing its hand-rolled-format philosophy so the
output depends on **no** built-in Style Dictionary transform group (the thing that
broke the original config across the v3→v5 migration).

- **`sd.config.android.mjs`** (SD v5, ESM) — custom Compose + XML formats.
  Colors: hex *and* `rgba(r,g,b,a)` → `Color(0xAARRGGBB)` / `#AARRGGBB`
  (e.g. `rgba(0,0,0,0.84)` → alpha `0xD6`). Spacing/radius/size/layout/shadow px →
  `Dp` / `<dimen>Ndp`. Opacity → `Float`. Motion `{easing,duration}` → duration-ms
  + easing comment. The 16 `typography.*` tokens are **semantic style strings**
  (`largeTitle/bold/rounded`), *not* numeric sizes — so there's nothing to emit as
  `sp`; they're a reference comment block pointing at the MD3 type-scale mapping.
- **Generated + committed artifacts:** `android/FitMeDesignTokens.kt`
  (`FitMeColors`/`FitMeSpacing`/`FitMeRadius`/`FitMeSize`/`FitMeLayout`/`FitMeElevation`/`FitMeOpacity`/`FitMeMotion`),
  `android/res/values/colors.xml` (49), `android/res/values/dimens.xml` (34).
- **Drift gate:** `npm run tokens:android` + `tokens:android:check`
  (`scripts/check-tokens-android.js` — regenerate, strip date lines, diff, restore;
  `execFileSync` with fixed argv, no shell).
- **Removed** the broken `design-tokens/config-android.json` (superseded).
- **Refreshed** `android-token-mapping.md` (§0a "AND-1 SHIPPED") +
  `android-adaptation.md` (generated token layer; fixed a stale `Focus.ring` row
  removed in audit DS-015).

## Decisions

- **Compose + XML, not XML-only** (operator choice) — the complete,
  modern-Android-consumable output. Marginal cost over XML-only was ~1h.
- **Raw-pixel `Dp`, not rem-scaled** — cross-platform parity with iOS `CGFloat`
  direct values; the original rem-input assumption was the root of the broken
  transforms.
- **Hand-rolled formats** — like the iOS config; immune to Style-Dictionary
  built-in-format drift, which is exactly what broke v1.

## Verification (T1)

- `npm run tokens:android` → 3 artifacts, 0 errors.
- Two consecutive builds → byte-identical (`diff` clean).
- `tokens:android:check` → exits 0 in-sync; non-zero after a token edit (verified
  mutate-then-revert).
- 49 colors + 34 dimens, **0 duplicate** resource names; Kotlin val-name "collisions"
  (`small`, `medium`) are across *different objects* — valid Kotlin.
- **Limit (honest):** the generated Kotlin is **not compiled** — there is no Android
  toolchain in-repo (which is also why AND-3, the native app, stays deferred
  indefinitely; re-eval 2027-05-26). Verification is determinism + structural
  validity + drift-gate, not `gradlew assemble`.

## What this is NOT

This builds the **token layer**, not an app. No Gradle, no Compose screens, no
`AndroidManifest.xml`. `android-app-implementation` (AND-3) remains deferred. The
value here: the Android design system is now a *real, generated, drift-gated
artifact* instead of a broken config and a stale doc — ready to consume the day an
app is warranted.

## Follow-ups

- `make tokens-android-check` + `verify-local` wiring (infra-glob → isolated
  worktree, separate PR).
- fitme-story showcase MDX + `related_prs` backfill (post-merge close-feature).
