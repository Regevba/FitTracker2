---
title: "T9 — Backend chaos tests: what the CI simulator will not let you test"
date_written: 2026-07-23
date: 2026-07-23
work_type: chore
framework_version: v7.10
linear_id: FIT-157
dispatch_pattern: serial
primary_metric: "10 adversarial chaos tests across the 2 highest-risk backend services (EncryptionService, AccountDeletionService), 0 flake across 3 CI runs"
success_metrics:
  - "10 chaos tests shipped across EncryptionService (3) + AccountDeletionService (7) [T1 — counted in-tree]"
  - "AccountDeletionService gains an injectable sync seam so the destructive executeDeletion() cascade is testable at all [T1 — protocols in source]"
  - "0 new flake introduced: full FitTrackerTests suite green on each of the 3 merges [T1 — CI]"
kill_criteria:
  - "K1 — any chaos test proves flaky (non-deterministic pass/fail) across 3 consecutive CI runs ⇒ revert that test rather than accept a red-on-main source"
  - "K2 — the injectable seam changes production deletion behaviour in any observable way ⇒ revert the seam and leave executeDeletion() untested"
kill_criteria_resolution: "Both not_fired. K1: the 10 tests passed on all 3 merge runs (#846 2026-07-04, #873 2026-07-11, #908 2026-07-16) with no retries or quarantines [T1 — CI]. K2: the seam is additive — two narrow protocols (AccountDeletionSupabaseSyncing, AccountDeletionCloudSyncing) that the existing concrete services conform to unchanged; production call sites and deletion ordering are byte-identical [T1 — diff]. T2 (key-rotation chaos) is formally DEFERRED, not failed — see §3."
tier_tags_present: true
platforms_tested:
  ios: true
  backend: true
related_prs: [846, 873, 908]
case_study_type: framework_meta
---

# T9 — Backend chaos tests

**FIT-157 · chore · v7.10 · shipped across PR #846, PR #873, PR #908**

## 1. Why

The test-coverage master plan (§4 T9) called the backend the thinnest-tested
layer relative to its blast radius. Two services carry irreversible
consequences on failure:

- **`EncryptionService`** — a corrupted round-trip silently destroys user data.
- **`AccountDeletionService`** — a partial cascade leaves a user "deleted"
  locally while their rows survive in Supabase or CloudKit, which is a GDPR
  exposure, not just a bug.

Both were covered by happy-path unit tests only. Chaos tests — concurrency,
oversized payloads, partial remote failure, rapid state alternation — are the
class that finds the bugs happy-path tests architecturally cannot see.

## 2. What shipped

**10 adversarial tests.** [T1 — counted in-tree]

`EncryptionServiceTests.swift` (PR #846):

| Test | Adversarial condition |
|---|---|
| `testEncrypt_concurrentRoundTrips_allSucceed` | 32 concurrent round-trips; proves actor serialization holds |
| `testEncrypt_largePayload_roundTripsLosslessly` | ~2 MB payload |
| `testEncrypt_manyDistinctPayloads_noCrossContamination` | 50 payloads, asserts no bleed between them |

`AccountDeletionServiceTests.swift` (PR #873 T3, PR #908 T4):

| Test | Adversarial condition |
|---|---|
| `testRequestDeletion_remoteFailureDoesNotLoseLocalIntent` | remote down at request time |
| `testCancelDeletion_remoteFailureStillClearsLocalIntent` | remote down at cancel time |
| `testRapidRequestCancelAlternation_leavesConsistentState` | request/cancel churn |
| `testCheckGracePeriod_repeatedRelaunchIsIdempotent` | repeated cold launches |
| `testDaysRemaining_boundarySweep_clampedAndMonotonic` | grace-period boundary sweep |
| `testExecuteDeletion_allRemoteStoresSucceed_noRemotePending` | full-success cascade |
| `testExecuteDeletion_supabaseFailure_cascadeContinues_andRecordsPending` | **partial** cascade failure |

**The seam that made T4 possible.** `executeDeletion()` reached
`SupabaseSyncService` and `CloudKitSyncService` concretely, so its
partial-failure path was untestable without touching real backends. PR #908
introduced two narrow protocols — `AccountDeletionSupabaseSyncing` and
`AccountDeletionCloudSyncing` — capturing *only* the surface
`AccountDeletionService` actually calls. The concrete services conform
unchanged. This is the load-bearing result: the most destructive path in the
app is now reachable by a test.

## 3. The honest part — T2 is deferred, not done

**T2 (key-rotation chaos tests) will not ship on the current CI.**

`EncryptionService.rotateKeys` calls `authenticatedContext()`, which requires an
enrolled biometric authenticator. The CI simulator has none and returns
`LAError -7`. There are exactly three ways forward, all out of proportion to
the task:

1. a biometry-enrolled CI runner (infrastructure the project does not have),
2. a production test seam over `LAContext` (widening the auth surface — the
   wrong trade for a test), or
3. asserting nothing and calling it covered (the silent-pass this framework
   exists to prevent).

So T2 is recorded as **deferred with a named blocker**, and the feature closes
without it. The framework's own rule — a system that knows what it cannot check
is more trustworthy than one that pretends every check is a check — applies to
its own test plan. This mirrors the documented Tier 2.1 unclosable gap
(real-provider auth needs a human at a simulator).

## 4. Why this took three PRs and 12 days

T9 shipped as a foundation slice (#846) and then two follow-on slices (#873,
#908) rather than one branch, because each slice needed a different enabling
change: #846 needed nothing, #873 needed the GDPR cascade understood, #908
needed the seam designed. The cost showed up in state drift — `state.json`
sat at `implement` while all three PRs were on `main`, and the Tier 2.2 log
was not appended for the #873 and #908 sessions. The weekly stale-state sweep
caught it ([GH #922](https://github.com/Regevba/FitTracker2/issues/922),
2026-07-20, 16 days stale).

That is the W40 pattern (tracker lag vs. repo truth) inside a single feature.
The mechanical defenses worked exactly as designed: the sweep found it, and
the sweep's own issue body correctly diagnosed it as intentional-hold rather
than abandonment.

## 99. Synthesis

| Dimension | Result |
|---|---|
| Chaos tests shipped | **10** (3 encryption + 7 deletion) [T1] |
| Production seams added | 2 protocols, behaviour-neutral [T1] |
| Tasks complete | T1, T3, T4 [T1] |
| Tasks deferred | T2 — biometry-gated CI, blocker named [T1] |
| Kill criteria | K1 `not_fired`, K2 `not_fired` [T1] |
| Flake introduced | 0 across 3 merge runs [T1] |
| Lessons | Testability is a design property: T4 was impossible until a seam existed. Deferring with a named blocker beats a green test that asserts nothing. |
