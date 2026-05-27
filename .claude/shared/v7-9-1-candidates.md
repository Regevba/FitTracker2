# v7.9.1 candidate docket

> Created 2026-05-27. Successor to the v7.9 promotion (shipped 2026-05-21 via PR #417). Items here are the queued enhancements + bug-fixes for the next framework patch cycle, expected to open after v7.9 Phase E exit (~2026-06-04).
>
> **Purpose:** make the v7.9.1 cycle's scope explicit so any item can be promoted into a feature directory (`.claude/features/<name>/`) when the cycle opens. Until then, each candidate is a small spec stub with discovery context + smallest-viable-shape sketch.
>
> **Conventions:** F-* = enhancement / new gate / new instrumentation. W-* = workaround documented in [`observed-patterns.md`](../integrity/observed-patterns.md), promoted to docket when a durable fix is queued. Both share this docket — the prefix distinguishes "net-new mechanism" vs "lift workaround into structural fix".
>
> **Closure protocol:** when an item ships, strike its heading + add `**Closed YYYY-MM-DD via <PR>**`. Do not delete — historical visibility matters.

---

## F-AUTH-LATENCY-SERVER-METRIC

**Discovered:** 2026-05-27 (B12 UCC hardening T+7d kill-criteria evaluation, PR #503).
**Status:** queued.
**Owner:** TBD (likely 1 PR on fitme-story, no FT2 changes).
**Effort:** ~0.5 day (1 field + 1 emission site + 1 test).

### Problem

The K3 instrumentation chosen at UCC-hardening spec time (`auth_passkey_authenticate_succeeded.duration_ms`) measures **end-to-end WebAuthn ceremony time** (server round-trip + user touch + FIDO2 hardware response), not the **server-side function-execution time** the +5ms threshold was sized for (one extra Redis GET in `checkLockout`).

At the B12 T+7d evaluation, pre-hardening mean was 545.5 ms (n=2), post-hardening mean was 682.7 ms (n=3) — a +137 ms swing that is almost certainly cold-start function variance + user-touch timing variance + IP-class network variance, NOT attributable to the +1 Redis GET. The kill-criterion as written was un-evaluatable; verdict was promoted on operational signals (4 successful sign-ins in window, no friction observed) but the K3 metric itself stayed unresolved.

### Smallest viable shape

Add a `duration_ms_server` field to the `auth_passkey_authenticate_succeeded` event, measured at the API route handler:

```ts
// fitme-story/src/app/api/auth/authenticate/verify/route.ts
export async function POST(req: NextRequest) {
  const serverStart = performance.now();
  try {
    // ... existing auth flow including checkLockout Redis GET ...
  } finally {
    const serverDuration = performance.now() - serverStart;
    await logAuthEvent({
      event_type: 'auth_passkey_authenticate_succeeded',
      duration_ms: clientReportedDuration,  // existing field (ceremony time)
      duration_ms_server: Math.round(serverDuration),  // NEW
      // ...
    });
  }
}
```

Keep the existing `duration_ms` field for backward compatibility (the audit panel UI uses it for "how long did the operator wait?"). The new `duration_ms_server` becomes the canonical input for future kill-criterion thresholds sized in server overhead terms.

### Why now

- Without it, every future hardening / refactor in the auth path will face the same unmeasurable K3 trap.
- 1 field is cheap; the audit-log schema_version stays at 1 (adding a field is non-breaking).
- Closes the K3 thread from B12 cleanly so v8.x kill-criteria can use real measurements.

### Linked PR closing this thread

To be filled when shipped.

---

## F-CONTRACT-FIXTURE-SAMPLING

**Discovered:** 2026-05-24 (production incident — `/control-room/framework` TypeError, 13-day silent regression).
**Status:** queued. Filed as **E-15** in master plan v8.x docket.
**Owner:** TBD (FT2 producer-side aggregator + fitme-story consumer-side adoption).
**Effort:** ~1-1.5 days (aggregator script + fixture sampling integration + 1-2 contract tests).
**Source PRs containing the lesson:** fitme-story PR #146 (hotfix), FT2 PR #476 (W16 catalog).

### Problem

Cross-repo data contracts can silently drift. The 2026-05-24 incident: FT2 producer `scripts/gate_coverage.py` emits `{"timestamp": …}` but fitme-story `gate-coverage-aggregator.ts` expected `event.ts`. Both repos' tests used the consumer's wrong field too, so 6/6 tests stayed green for 13 days while the page rendered a Next.js error boundary on every visit.

The structural failure: **contract-boundary tests used a fixture sample drawn from the consumer's expected shape, not the canonical producer.** Whenever this divergence is possible (different repos, different teams, different schemas in test vs prod), the silent-pass class becomes inevitable.

### Smallest viable shape

`make sample-contract-fixtures` aggregator script that:

1. Iterates over a manifest of cross-repo data contracts (config file listing `{producer_path, consumer_repos[]}` pairs).
2. For each contract, **reads a small sample (10 events) from the canonical producer's actual output** (live file in producer repo or live HTTP endpoint).
3. Writes that sample to `__fixtures__/contracts/<contract-name>.jsonl` in each consumer repo.
4. CI gate (new): fail if a consumer's `__fixtures__/contracts/*` is older than 7 days OR if any test imports a non-canonical fixture.

Contracts in scope (initial 3):

| Contract | Producer | Consumer |
|---|---|---|
| `gate-coverage` | FT2 `scripts/gate_coverage.py` | fitme-story `src/lib/control-room/gate-coverage-aggregator.ts` |
| `audit-log` events | fitme-story `src/lib/auth/audit-log.ts` | FT2 `.claude/logs/ucc-auth-events.jsonl` mirror + FT2 `make integrity-check` |
| `state.json` schema | FT2 `scripts/check-state-schema.py` (producer of the canonical schema) | fitme-story `src/data/features/*.json` (consumer of state.json subset) |

### Why now

- The 2026-05-24 incident was a 13-day silent regression that could have been a 30-second test-fail. The fix is structural — without it, the same class of bug recurs at every cross-repo schema change.
- Aligns with v7.7 + v7.8 silent-pass-prevention theme (Mechanisms A-F).
- Fits the v7.9.1 "patch cycle" scope: closes one specific gap class, doesn't rebuild infra.

### Linked PR closing this thread

To be filled when shipped.

---

## ~~W11-PREFLIGHT-ENHANCEMENT-PARENT-FIX~~ — **VERIFIED CLOSED 2026-05-27 via FT2 PR #454** (commit `e906601`)

**Discovered:** 2026-05-19 (UCC hardening Phase 0 prep; documented in [`observed-patterns.md`](../integrity/observed-patterns.md) as W11).
**Status:** **CLOSED**. Verified during 2026-05-27 docket-grooming session: PR #454 commit `e906601` ("chore(batch): C-batch — C7 + C8 + C11 + C12 infra-ops chores") shipped the durable fix. Current `scripts/preflight.py:292` carries the C12 docstring + correct implementation reading the enhancement's `state.json::parent_feature` and checking THAT parent's state.json + prd.md. Effective coverage: confirmed via `grep -nA15 "def enhancement_parent_state" scripts/preflight.py`.
**Owner:** N/A — shipped.
**Effort:** ~0.25 day actual.
**Source PR containing the workaround:** FT2 PR #410 (UCC hardening Phase 0/1/2 prep).
**Closing PR:** FT2 PR #454 commit `e906601` (2026-05-23).
**Closure verification log:**

```
$ git log --oneline --all -- scripts/preflight.py | head -3
e906601 chore(batch): C-batch — C7 + C8 + C11 + C12 infra-ops chores (#454)
$ grep -nA1 "def enhancement_parent_state" scripts/preflight.py
292:def enhancement_parent_state(feature: str | None) -> dict | None:
293:    """Enhancement requires a PARENT feature with a PRD.
```

Docket entry kept in-place (not deleted) per closure protocol so the discovery → workaround → durable-fix chain stays readable. Sections below describe the original problem + fix shape that landed.

### Problem

The v7.8.6 `make preflight` script's `enhancement_parent_state()` function (at `scripts/preflight.py:264` per cadence ledger C12 note) was checking the **enhancement's own** `prd.md` instead of resolving `state.json::parent_feature` and checking THAT parent's `prd.md`. This false-positively flagged enhancement features (which legitimately have no own PRD — they inherit parent PRD via `state.json::parent_feature` linkage) as missing required artifacts.

Workaround used during UCC hardening: a thin "delta-PRD" file written at `.claude/features/ucc-passkey-auth-security-hardening/prd.md` that simply pointed to parent PRD + listed delta scope.

### Smallest viable shape

Verification step (do first):

```bash
# Re-trace the C12-claimed closure in PR #454
git log --all --oneline -- scripts/preflight.py | head -5
grep -n "enhancement_parent_state\|parent_feature" scripts/preflight.py
```

If the fix is present and correct: this docket entry → "VERIFIED CLOSED" + strike.

If not: durable fix:

```python
# scripts/preflight.py
def enhancement_parent_state(feature_name: str) -> dict:
    state = json.loads(Path(f".claude/features/{feature_name}/state.json").read_text())
    parent = state.get("parent_feature")
    if not parent:
        return {"ok": True, "reason": "not_an_enhancement"}
    parent_state_path = Path(f".claude/features/{parent}/state.json")
    parent_prd_path = Path(f".claude/features/{parent}/prd.md")
    return {
        "ok": parent_state_path.exists() and parent_prd_path.exists(),
        "parent": parent,
        "parent_state_present": parent_state_path.exists(),
        "parent_prd_present": parent_prd_path.exists(),
    }
```

Plus 2-3 unit tests: enhancement with missing parent (fail), enhancement with present parent (pass), non-enhancement (pass with reason).

### Why now

- Removes the "ship a thin delta-PRD just to satisfy preflight" workaround burden from every future enhancement.
- Single-file fix; low blast radius; trivial to verify.
- Likely already shipped via PR #454 — needs a 5-minute audit to confirm.

### Linked PR closing this thread

To be filled when shipped (or PR #454 reference confirmed sufficient).

---

## Triage rules for new candidates

When a new candidate surfaces (during session work, audit, or incident review):

1. **Does it fit v7.9.1 patch scope?** v7.9.1 is a PATCH cycle — bug fixes, missing-instrumentation closures, durable-fix-replacing-workaround. Not new major features. Not gates that require their own 14-day calibration. If the candidate is bigger, file in `docs/master-plan/infra-master-plan-2026-05-12.md` §v8.x docket instead.

2. **Is it blocking another active candidate?** If yes, mark it as a prerequisite in the dependent's entry.

3. **Add an entry with all 5 fields:** Discovered date + status + owner + effort + smallest viable shape. Without these, the candidate stays "queued" indefinitely.

4. **Don't queue more than 5 candidates simultaneously.** v7.9.1 should ship within 1-2 weeks of opening. If the docket grows past 5, the cycle isn't a patch cycle anymore — escalate to v8.x.

## How v7.9.1 cycle opens

- **Trigger:** v7.9 Phase E exits cleanly (~2026-06-04, 14 days post-promotion). See [infra master plan §4.1](../../docs/master-plan/infra-master-plan-2026-05-12.md).
- **First commit:** new feature directory `.claude/features/framework-v7-9-1-cycle/` with state.json scaffolded, this docket linked from `predecessor_case_studies`.
- **Per-candidate promotion:** each item here gets promoted to its own `.claude/features/<feature-name>/` directory when it enters the active dispatch queue.
- **Closure:** when v7.9.1 ships, the cycle's case study at `docs/case-studies/framework-v7-9-1-cycle-case-study.md` references which candidates from this docket landed + which deferred to v8.x.

---

## References

- v7.9 promotion case study: [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../../docs/case-studies/framework-v7-9-promotion-case-study.md)
- v7.9 promotion cold-start entrypoint: [`.claude/entrypoints/framework-v7-9.md`](../entrypoints/framework-v7-9.md)
- Infra master plan: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../docs/master-plan/infra-master-plan-2026-05-12.md)
- Observed patterns catalog (W-series): [`.claude/integrity/observed-patterns.md`](../integrity/observed-patterns.md)
- Cadence follow-ups ledger: [`.claude/shared/must-have-cadence-followups.md`](must-have-cadence-followups.md)
