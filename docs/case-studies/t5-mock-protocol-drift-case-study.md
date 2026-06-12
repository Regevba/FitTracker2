---
title: "T5 — Mock-protocol drift detection (a central conformance registry, reframed for the real codebase)"
slug: t5-mock-protocol-drift
date_written: 2026-06-10
date: 2026-06-10
work_type: Feature
work_subtype: b_medium
dispatch_pattern: "operator-driven (T5 from the test-coverage master plan)"
framework_version: v7.10
state_owner: ft2
case_study_type: feature
primary_metric: "Central protocol-conformance registry: every test-mocked protocol has a compile-time anchor so a protocol-surface drift fails the build at a single labelled point."
success_metrics:
  primary: "MockProtocolConformanceTests.swift anchors all 6 test-mocked protocols; test target compiles (build-for-testing green)."
  secondary:
    - "The 2 shareable app-target mocks (MockAnalyticsAdapter, MockGoogleAuthProvider) are additionally bound + smoke-tested."
    - "Documented the scoping reframe: the spec's named mocks don't exist; the real mocks are private-by-design."
kill_criteria:
  - "Anchors duplicate private mocks in a way that adds maintenance burden without catching new drift."
  - "A protocol gains an optional/defaulted requirement the anchor masks (false negative)."
kill_criteria_resolution: "Neither fired. The anchors are minimal (one per protocol) and centralized — they add a single labelled failure point Swift's per-mock conformance can't provide (the real mocks are private to their test files). No protocol in scope uses optional/defaulted requirements, so an added requirement always breaks the anchor."
tier_tags_present: true
related_prs: []
---

# T5 — Mock-Protocol Drift Detection

> **Status:** shipped 2026-06-10. RICE 40.0.

## 1. The scoping reframe (the third this week)

T5 was spec'd (2026-05-13) as "wrap `MockKeychainStorage`, `MockSupabaseClient`, `StubAIEngineClient`, `CountingAIEngineClient` in a shared `MockValidation.swift` that fails build if protocol surface drifts." Two facts from the actual codebase changed the shape:

1. **None of those four named mocks exist.** The real test doubles are `MockAnalyticsAdapter`, `MockGoogleAuthProvider`, `MockURLSession`, `StubAppleAuthProvider`, `StubEmailAuthProvider`, `TestAdapter`.
2. **Four of the six are `private`** to their own test files (good encapsulation) — a central file can't reference them — and Swift already compile-enforces each `Mock: Protocol` declaration, so re-asserting them is redundant.

So a literal "central drift detector over the named mocks" is impossible *and* low-value. (This joins T10 — the AI is deterministic, not generative — and T3 — the test bundle ships a real passkey relying-party ID — as cases where running/reading the code corrected the 2026-05-13 plan.)

## 2. The durable form for this codebase

A **central conformance registry**: `FitTrackerTests/MockProtocolConformanceTests.swift` defines one minimal *anchor* per test-mocked protocol — the smallest type that satisfies it. The anchor exists only to pin the protocol's surface at compile time; it's never called. If a protocol's surface drifts (a requirement added / renamed / re-signed), the matching anchor fails to compile and **this one labelled file is the failure point** — instead of a confusing error deep inside whichever private mock happened to break, on whatever unrelated PR touched the protocol.

Six anchors: `AnalyticsProvider`, `GoogleAuthProviding`, `AppleAuthProviding`, `EmailAuthProviding`, `URLSessionProtocol`, `AIInputAdapter`. Plus the two app-target mocks that ARE shareable (`MockAnalyticsAdapter`, `MockGoogleAuthProvider`) are bound to their protocol type and smoke-tested, so the registry tracks the live types, not just the anchors.

## 3. Why a registry beats per-mock conformance

Swift catches drift at each `Mock: Protocol` site — but those sites are scattered across private test files, and a protocol change surfaces as an error wherever the mock lives, with no single "these are the protocols we mock" inventory. The registry adds: (a) one documented place listing every mocked protocol ↔ its double, (b) a single, clearly-labelled compile failure on drift, and (c) protection against a protocol's *only* mock being deleted/orphaned without notice (the anchor still pins the surface).

## 4. Verification

`build-for-testing` green — the whole point of T5 is compile-time, so a successful test-target build *is* the assertion that all six protocol surfaces still match their anchors. The runtime tests additionally prove the two shareable mocks bind + respond.

**The mechanism demonstrated itself during development:** the first build failed with `_EmailAuthAnchor does not conform to protocol 'EmailAuthProviding'` — because `EmailAuthProviding` actually has *seven* methods (it also requires `requestPasswordReset` / `updatePassword` / `processRecoveryURL`), not the four I'd anchored. The registry caught the incomplete anchor at exactly the labelled point it's designed to. That's the drift detector working — on its own author.

## 5. Cross-references

- **Spec:** [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md) §4 T5.
- **Sibling reframes:** [`ai-golden-set-evals-case-study.md`](ai-golden-set-evals-case-study.md) (T10), [`t3-signinservice-passkey-tests-case-study.md`](t3-signinservice-passkey-tests-case-study.md) (T3).
