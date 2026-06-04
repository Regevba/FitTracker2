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

## F-DEPLOYED-URL-PROBE

**Discovered:** 2026-05-27 (DISCO Phase 1 P1.5 operator-verification follow-up — two distinct silent-pass bugs surfaced within minutes: W18 og-image URL hardcoded at a 404 path + W19 env-var trailing newline corrupting the GA measurement ID).
**Status:** queued.
**Owner:** TBD (FT2 CI workflow + shared shell helper).
**Effort:** ~2-3h (workflow YAML + 4-6 probe assertions + 2-3 regression tests).
**Source incidents:** fitme-story PR #156 (og:image fix) + fitme-story PR #157 (GA_ID `.trim()` fix). Catalog entries: W18 + W19 in [`observed-patterns.md`](../integrity/observed-patterns.md).

### Problem

Local dev + Vercel preview-deploy inspection passed cleanly for both 2026-05-21 ships (DISCO Phase 1 P1.3 OG meta + P1.4 OG image). But both shipped with silent runtime bugs that only manifested AFTER production deploy + actual end-user inspection:

| Bug | Root cause | Silent path |
|---|---|---|
| og:image 404 (W18) | `src/lib/seo.ts::buildMetadata()` hardcoded `${SITE_BASE}/og.png`; actual auto-generated image was at `${SITE_BASE}/opengraph-image` | LinkedIn/Twitter/HN fetch og:image URL → 404 → no rich preview. Operator-side never noticed because nobody shared a link in those 6 days. |
| GA_ID trailing newline (W19) | `process.env.NEXT_PUBLIC_GA_ID` returned `G-XE4E1JGWRZ\n` (env-var paste residue); Script component injected literal `\n` into gtag URL as `%0A` | Google Measurement Protocol rejected every event silently; GA4 Realtime + Reports showed 0 web sessions despite gtag.js loading correctly on every page. |

Both classes share the same property: **what the deployed HTML SAYS is the URL ≠ what the receiving service can actually fetch + process**. Local dev + preview-deploy environments never expose this because neither runs the receiving-service round-trip.

Both bugs were dormant for 6 days (2026-05-21 → 2026-05-27) before discovery via P1.5 operator-verification. Without F-DEPLOYED-URL-PROBE, the next ship of a similar URL-emitting feature can recur the same silent class.

### Smallest viable shape

Single GitHub Actions workflow file: `.github/workflows/post-deploy-url-probe.yml` (or extend an existing workflow). Runs **after** Vercel auto-deploys a successful preview OR production deploy. Triggers on `deployment_status: success` event (or a periodic cron if `deployment_status` isn't reliable).

Probe assertions (each a `curl` + assert on response):

1. **OG image URL exists.** Parse the deployed root HTML, extract `<meta property="og:image" content="...">`, curl HEAD that URL, assert HTTP 200. Catches W18.
2. **GA measurement ID is clean.** Parse the deployed root HTML, extract the `gaId` field from the GoogleAnalytics component config, assert no `\n` / `\t` / leading-trailing whitespace, then curl `https://www.googletagmanager.com/gtag/js?id=$EXTRACTED_ID` with HEAD, assert 200 + no `%0A` in the response URL. Catches W19.
3. **Canonical URL self-references valid.** Extract `<link rel="canonical" href="...">`, curl HEAD that URL, assert 200 (catches broken canonical URLs that hurt SEO).
4. **Sitemap is reachable.** Curl `https://${DEPLOY_HOST}/sitemap.xml` HEAD, assert 200 + `content-type: application/xml`.
5. **Robots.txt is reachable.** Curl `https://${DEPLOY_HOST}/robots.txt` HEAD, assert 200 + body contains `Sitemap:` line.

For each assertion, on failure: post a sticky comment on the triggering PR (or open an issue if production deploy) with the failing URL + the deployed HTML excerpt that referenced it. Optional: file a `framework-status` issue if it's a production deploy.

### Why now (v7.9.1 cycle)

- 2 silent-pass bugs in 6 days from the same feature ship (DISCO Phase 1) demonstrates the class is real + recurrent, not a one-off.
- Stacks under v7.9.1's "observability hardening" theme alongside F-CONTRACT-FIXTURE-SAMPLING (cross-repo data contracts) and F-LAUNCHD-DRIFT-EXTENSION (cron context drift). All three close silent-pass classes where the test data ≠ the production data.
- Phase-E-CONTAMINATING (infra-glob `.github/workflows/*` touch) → defer actual implementation to v7.9.1 cycle ~2026-06-04+.

### Linked PR closing this thread

To be filled when shipped.

### Related v7.9.1 candidates (recurring "test ≠ production" theme)

- F-CONTRACT-FIXTURE-SAMPLING — closes consumer-fixture-disagrees-with-producer-shape (cross-repo data contracts; W16)
- F-LAUNCHD-DRIFT-EXTENSION — closes cron-context-lacks-keychain (launchd auth drift; W11.b)
- F-DEPLOYED-URL-PROBE — closes URL-in-source-doesnt-resolve-on-deploy (W18 + W19)
- ~~W11~~ closed via PR #454 — predecessor of the same "deployment surface ≠ source surface" family

---

## ~~F-LAUNCHD-DRIFT-EXTENSION~~ — **FULLY CLOSED 2026-06-04**

**Discovered:** 2026-05-24 (W11.b sub-pattern documented in [`observed-patterns.md`](../integrity/observed-patterns.md) after 2026-05-24 daily cron captured 319 phantom `BROKEN_PR_CITATION` findings due to launchd context lacking keychain access for `gh` CLI; second trigger was the 2026-05-19 SSD migration which silently broke cron for 5 days due to plist hardcoding `/Volumes/DevSSD 1/...` instead of canonical `/Volumes/DevSSD/...`).
**Status:** ALL 3 sub-fixes **SHIPPED 2026-06-04**. Sub-fix (b)+(c) via PR #621 (`ed20cbf`); sub-fix (a) via follow-on feature `f-launchd-drift-extension-sub-a`. Master plan entry: E-14 in [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../../docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md).
**Owner:** N/A (closed).
**Effort:** ~3h actual total — sub-fix (b)+(c) ~2h, sub-fix (a) ~1h.

### Problem

Two distinct silent-pass failure modes both originate from the launchd-cron execution context:

1. **Plist path drift** — when the SSD's mount point changes (SSD-migration, USB-port-swap, system reboot anomaly), the launchd plist's hardcoded `WorkingDirectory` + script path no longer resolves. Cron continues firing but every invocation silently fails with exit 78 (no such file). The 2026-05-19 SSD migration broke cron for 5 days before anyone noticed because no surface alerted to the drift.

2. **Subprocess swallow** — `ensure-pr-cache-fresh.py` calls `gh` CLI via subprocess; when run from launchd context (no keychain access), `gh` returns auth failure but the wrapper's `--quiet || true` swallowed the error code. The downstream `make integrity-check` then ran against an empty `.cache/gh-pr-cache.json`, producing 319 phantom `BROKEN_PR_CITATION` findings — all false-positive but indistinguishable from real findings without manual investigation.

### Smallest viable shape — 3 sub-fixes (any subset can ship independently)

**(a) Promote `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory checks** — currently advisory checks plist existence; extend to also check (i) plist `WorkingDirectory` path resolves on the current filesystem, (ii) `ProgramArguments[0]` script path resolves, (iii) at least one `StandardOutPath` is writable. Would have caught the 2026-05-19 drift on day 1.

**(b) Subprocess-failure propagation fix in `ensure-pr-cache-fresh.py`** — remove the `--quiet || true` swallow. Refresh subprocess failures propagate to caller. Caller decides whether to abort (cron) or warn (interactive). Sample fix:

```python
# Before:
subprocess.run(["gh", "pr", "list", "..."], capture_output=True, quiet=True) or True

# After:
result = subprocess.run(["gh", "pr", "list", "..."], capture_output=True)
if result.returncode != 0:
    if os.environ.get("LAUNCHD_CONTEXT") == "1":
        sys.exit(78)  # signal launchd to mark the run failed + retry
    print(f"WARN: pr-cache refresh failed: {result.stderr.decode()[:200]}", file=sys.stderr)
```

**(c) Daily-checkpoint cron context validation** — `daily-integrity-checkpoint.py` re-validates `gh auth status` before trusting cron-captured integrity-check output. If auth fails, the script either re-warms via `gh auth login` (won't work in cron context — fail-closed) OR exits with a "cron auth not configured" sentinel finding that's distinguishable from a real finding.

### Why now (gates v7.9.1)

- The 2026-05-24 phantom-finding incident was a 5-hour false-positive panic before manual investigation revealed the launchd context. Without the fix, the same class recurs on every SSD-migration or keychain-rotation event.
- Stacks under v7.9.1's "observability hardening" theme (alongside F-CONTRACT-FIXTURE-SAMPLING which closes the cross-repo silent-pass class).
- Touches `scripts/` + plist (infra-glob) → 🔴 Phase-E-contaminating → defer actual implementation to v7.9.1 cycle ~2026-06-04+.

### Linked PR closing this thread

Sub-fixes (b)+(c) closed via PR #621 (merge commit `ed20cbf`, 2026-06-04). Sub-fix (a) closed via follow-on feature `f-launchd-drift-extension-sub-a` (this PR).

**What shipped 2026-06-04 (sub-fix (a)):**

- `scripts/integrity-check.py::check_branch_isolation_launchd_drift()` — extended with 3 path-resolution sub-checks for any FT2-related plist: (i) WorkingDirectory resolves to an extant directory, (ii) ProgramArguments[0] script resolves to an extant file, (iii) StandardOutPath / StandardErrorPath parent is writable.
- `scripts/integrity-check.py::_plist_references_ft2()` — new heuristic gate (filename / ProgramArguments / WorkingDirectory pattern match) so unrelated system plists are explicitly NOT scanned.
- `scripts/tests/test_launchd_drift_extension_sub_a.py` — 14 unit tests; runs in 0.28s.
- `CLAUDE.md` — new v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (a) section closing the 3-part plan.
- `docs/case-studies/f-launchd-drift-extension-sub-a-case-study.md` — source case study.

**Outcome:** the 2026-05-19 SSD-migration drift class (5 silently-broken cron days) now surfaces as a `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory on day 1 of the next 72h cycle-time cron run.

**What shipped 2026-06-04 (sub-fixes (b)+(c)):**

- `scripts/ensure-pr-cache-fresh.py` — `_is_cron_context()` detects `LAUNCHD_LABEL` / `CRON_CONTEXT=1` / `XPC_SERVICE_NAME` patterns; writes `.claude/shared/pr-cache-refresh-failed.flag` (`{ts, reason, context}`) on subprocess failure under cron context.
- `scripts/integrity-check.py` — `pr_cache_refresh_failed_recently()` reads the flag (TTL 1h); when fresh, skips `BROKEN_PR_CITATION` + `PR_NUMBER_UNRESOLVED` and emits a single `PR_CACHE_REFRESH_FAILED` advisory in their place.
- `scripts/daily-integrity-checkpoint.py::precheck_cron_context()` — under cron context, pre-validates `gh auth status`; exits 78 (`EX_CONFIG`) when gh missing or auth-failed.
- `scripts/tests/test_launchd_drift_extension.py` — 16 unit tests covering all 3 surfaces; runs in 0.05s.
- `CLAUDE.md` — new v7.9.1 F-LAUNCHD-DRIFT-EXTENSION section.

**Outcome:** the 2026-05-24 phantom-finding class (319 spurious findings) reduces to ONE clearly-labeled `PR_CACHE_REFRESH_FAILED` advisory with explicit failure reason + timestamp + context. Stale flags (>1h old) are ignored — kill criterion #3 enforcement.

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

---

## F-SNAPSHOT-MANIFEST-CHECKSUM-ORDERING

**Discovered:** 2026-05-28 (B2 post-v7.9 baseline snapshot run; framework-v7-9-promotion case study §99.4 lesson 1).
**Status:** queued.
**Owner:** TBD (FT2; single script + 1-2 line fix).
**Effort:** ~15 min (1 script reorder + 1 manual test pass).

### Problem

`scripts/snapshot-phase-completion.sh` generates `CHECKSUMS.sha256` BEFORE writing `MANIFEST.md`. The manifest is then included in the checksum list with a stale hash (computed against an empty/placeholder file). Every snapshot since `make snapshot-phase` shipped (v7.8.3, 2026-05-11) has this defect.

**Symptom:** `shasum -a 256 -c CHECKSUMS.sha256` returns `MANIFEST.md: FAILED` on every snapshot, including the 2026-05-28 B2 baseline:

```text
MANIFEST.md: FAILED
framework-v7-8-branch-isolation.log.json: OK
integration-spec.md: OK
prd.md: OK
research.md: OK
state.json: OK
tasks.md: OK
shasum: WARNING: 1 computed checksum did NOT match
```

**Impact:** Cosmetic — the 6 actual feature source files verify clean (sha256 OK). Data integrity is intact. But the `FAILED` line is misleading noise that breaks scripted verification workflows (e.g., a CI job checking `shasum -c` exit code would see 1 FAILED and red-flag the snapshot).

### Smallest viable shape

Two equally-valid fixes:

**Option A — exclude MANIFEST.md from CHECKSUMS:**

```bash
# In scripts/snapshot-phase-completion.sh, change the find expression to skip MANIFEST.md
find "$DEST" -type f ! -name 'MANIFEST.md' ! -name 'CHECKSUMS.sha256' -exec shasum -a 256 {} + > "$DEST/CHECKSUMS.sha256"
write_manifest > "$DEST/MANIFEST.md"
```

**Option B — write MANIFEST.md first, then regenerate CHECKSUMS to include it:**

```bash
write_manifest > "$DEST/MANIFEST.md"
find "$DEST" -type f ! -name 'CHECKSUMS.sha256' -exec shasum -a 256 {} + > "$DEST/CHECKSUMS.sha256"
```

Option B is more rigorous (manifest content is itself integrity-protected) but requires the manifest writer to not depend on the checksum file. Option A is the smaller change and reflects the realpolitik: MANIFEST.md is auto-generated descriptive metadata, not load-bearing audit data.

**Recommended: Option A** (exclude pattern; ~3-line diff to the find expression).

### Why now

- The `MANIFEST.md: FAILED` line surfaces in every snapshot verification and will keep training operators to ignore `shasum -c` output. Bad signal hygiene.
- Phase E exit (~2026-06-04) will produce the meta-analysis baseline comparison snapshot; fixing this before then keeps the comparison's audit trail clean.
- Trivial scope: ~3 lines, no behavior change beyond signal cleanup.

### Linked PR closing this thread

To be filled when shipped.

---

## F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE

**Discovered:** 2026-05-28 (Phase E Day 7 B2 baseline analysis; framework-v7-9-promotion case study §99.4 lesson 2).
**Status:** queued.
**Owner:** TBD (documentation-only; ~30 min spec + ~15 min reference cite in CLAUDE.md).
**Effort:** ~45 min total.

### Problem

During v7.9 Phase E soak (2026-05-21 → 2026-05-28, Days 1-7), 9 new features were added to `.claude/features/*/` without backfilling their adoption metrics (`cache_hits`, `cu_v2`, `timing_wall_time`, `per_phase_timing`). `make integrity-diff` against the 2026-05-14 anchor consequently surfaced 3 measured regressions:

| Metric | 2026-05-14 | 2026-05-28 | Δ |
|---|---|---|---|
| `adoption_pct_post_v6` | 8.3% | 6.7% | −1.6 pp |
| `timing_wall_time_pct_post_v6` | 47.2% | 37.8% | −9.4 pp |
| `cache_hits_pct_post_v6` | 52.8% | 51.1% | −1.7 pp |

These are **PROCESS regressions** caused by denominator dilution (+9 features in numerator-static fields), not framework-caused regressions. They are NOT v7.9 kill criteria; the kill criteria targeted false positives + rollbacks, both `not_fired`.

However, they ARE measurement noise that the v7.9.1 cycle should clean up — and the underlying *discipline gap* (no codified rule about adoption-metric backfill during soak windows) should be addressed before v7.10's soak window opens.

### Smallest viable shape

Two-part fix, documentation-only:

**Part 1 — add a soak-window discipline section to `CLAUDE.md` Data Integrity Framework section:**

```markdown
### Soak-window discipline (v7.9.1+)

During any framework-version soak window (Phase E for v7.X, Phase Y for
future versions), new features that ship during the soak MUST either
(a) freeze adoption metric collection until soak exit, OR (b) backfill
adoption metrics in the same PR that introduces the feature's state.json.

**Rationale:** denominator dilution from soak-window feature growth causes
process regressions in `make integrity-diff` percentage metrics that are
NOT framework-caused but trigger weekly trend-scan alerts. The v7.9 Phase
E soak (2026-05-21 → 2026-05-28) observed −9.4 pp regression in
`timing_wall_time_pct_post_v6` from this pattern; the v7.9 verdict was
PROMOTE regardless (kill criteria were unaffected), but soak-window
disciplines should prevent the noise prospectively.

**Enforcement:** advisory at v7.9.1 ship (operator-attention check on the
weekly trend-scan output); promote to enforced if 2 consecutive soak
windows show >5 pp regression on any post-v6 percentage metric.
```

**Part 2 — add a backlog item under `docs/product/backlog.md` "Framework hygiene" section** cross-referencing the new CLAUDE.md section + the v7.9 case study §99.4 lesson 2.

### Why now

- Phase E exit is ~2026-06-04, ~7 days from filing. v7.9.1 cycle opens then.
- Documenting the discipline before v7.10's planning (~Q3 2026) prevents repeat. The pattern is fresh enough to capture concretely.
- Documentation-only; no telemetry impact, no gate flip, no risk to v7.9 enforcement state.

### Linked PR closing this thread

To be filled when shipped.

---

## ~~F-SNAPSHOT-MANIFEST-CHECKSUM-ORDERING~~

**Closed 2026-05-30 via PR (this PR — chore/phase-e-sweep-2026-05-30).** Moved MANIFEST.md write BEFORE CHECKSUMS.sha256 generation in [`scripts/snapshot-phase-completion.sh`](../../scripts/snapshot-phase-completion.sh). MANIFEST.md is now included in CHECKSUMS with a real hash; `shasum -a 256 -c CHECKSUMS.sha256` verifies cleanly (smoke-tested 2026-05-30 — 7/7 files OK including MANIFEST.md, prior bug reported MANIFEST.md:FAILED). Non-gate hygiene fix; Phase-E-safe (script edit, no gate behavior change).

---

## F-LOCK-INTRODUCING-COMMIT-PERMIT

**Discovered:** 2026-05-30 (Sub-exp 2 lock ceremony + Sub-exp 1B lock ceremony during HADF Phase 2-bis replication launch).
**Status:** queued.
**Owner:** TBD.
**Effort:** ~1h (pre-commit hook conditional check + 1 test).

### Problem

The pre-commit hook at [`.githooks/pre-commit:117-123`](../../.githooks/pre-commit) rejects any commit when a `.lock` sidecar exists alongside the prereg JSON. This is correct for forward edits (locked preregs must not change). But the lock-introducing commit itself — the commit produced by `scripts/hadf-phase2bis-lock-prereg.sh` that writes both the modified prereg + the new `.lock` file — is blocked by its own hook output, requiring `--no-verify` to land.

Empirically observed twice on 2026-05-30: once for Sub-exp 2 lock (`bd0db7e`) and once for Sub-exp 1B lock (`6cad3c7`). Both required operator-side `--no-verify`. The `--no-verify` rule (don't skip hooks) is being violated by the very script designed to honor the lock contract.

### Smallest viable shape

Pre-commit hook gains a "lock-introducing commit" exemption: if the SAME commit creates both `<file>.lock` AND modifies `<file>` (the prereg), AND the lock sha256 in the new `.lock` file matches the post-modification file content sha256 → ALLOW the commit. Otherwise reject as before.

```python
# scripts/check-state-schema.py (or wherever the lock-rejection fires)
if lock_exists_in_working_tree(prereg_path):
    if is_lock_introducing_commit(prereg_path):
        # Lock-introducing commit: .lock + prereg modified together,
        # sha256 in .lock matches post-modification prereg content
        # → allow
        pass
    else:
        # Forward edit attempt: reject
        raise SchemaCheckFailure(...)
```

### Why now

- Sub-exp 3 lock ceremony will hit the same issue post-2026-06-02 when Sub-exp 2 closes. Without this fix, operator forced to `--no-verify` a third time.
- Pattern generalizes to any future cryptographic lock-and-amend ceremony (e.g., audit-substrate bundle hashes per `docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`).

### Linked PR closing this thread

To be filled when shipped.

---

## F-SNAPSHOT-MANIFEST-LEDGER-ORDERING

**Discovered:** 2026-05-30 (full system check during Phase E Day 10).
**Status:** queued (user-local script — separate from in-repo F-SNAPSHOT-MANIFEST-CHECKSUM-ORDERING above).
**Owner:** TBD (operator-personal script edit).
**Effort:** ~10min (single edit in `~/.fittracker/hadf-snapshot.sh`).

### Problem

User-local snapshot cron script at `~/.fittracker/hadf-snapshot.sh` writes `MANIFEST.sha256` BEFORE appending to per-sub-exp `snapshot-ledger.jsonl`. The MANIFEST hash for `snapshot-ledger.jsonl` is therefore stale-by-one-line at verification time; `shasum -a 256 -c MANIFEST.sha256` reports `snapshot-ledger.jsonl: FAILED` even though the ledger is correct append-only.

Empirically observed 2026-05-30 system check: 2 dedicated HADF backup dirs (subexp1a + subexp2) report `snapshot-ledger.jsonl: FAILED`. Not a real corruption — heuristic false-positive.

### Smallest viable shape

Option (a): move ledger append BEFORE MANIFEST regen.
Option (b): exclude `snapshot-ledger.jsonl` from MANIFEST.sha256 generation.

Option (b) is simpler — ledger is append-only by design, externally re-verifiable from its own line count.

### Why now

- Separate from in-repo F-SNAPSHOT-MANIFEST-CHECKSUM-ORDERING (this docket's predecessor) which addressed `scripts/snapshot-phase-completion.sh::MANIFEST.md`. Same class of bug in a different script.
- Operator-local edit; not blocking any v7.9.1 build window concern.

### Linked PR closing this thread

N/A — operator-side personal-script edit (lives outside repo at `~/.fittracker/hadf-snapshot.sh`).

---

## ~~F-TIER-TAG-FORWARD-DEADLINE-FILTER~~

**Closed 2026-05-31 via PR #540.** Extended `is_target_or_kill_claim()` in [`scripts/validate-tier-tags.py`](../../scripts/validate-tier-tags.py) with `FORWARD_DEADLINE_RE` regex recognizing `T+Nd` / `events / Nd` / `within Nd` patterns. 8/8 unit smoke tests pass; closes the 4-false-positive class observed 2026-05-30. Phase-E-safe (advisory heuristic tightening, no gate behavior change).

**Discovered:** 2026-05-30 (integrity regression flag investigation during full system check).
**Status:** ~~queued~~ → **CLOSED 2026-05-31.**
**Owner:** ~~TBD~~ → shipped.
**Effort:** ~30min (1 regex pattern + 2 test cases in `scripts/validate-tier-tags.py`).

### Problem

The `TIER_TAG_LIKELY_INCORRECT` cycle-time advisory matches numeric mentions like `"7.0d"` to ledger entries via heuristic. Forward-looking deadline notations (`T+7d`, `0 events / 7d`, `within Nd window`) are NOT measurements — they're targets/thresholds/kill-criterion windows. The v7.8.4 fix added `is_target_or_kill_claim()` to filter target/kill claims, but the new `T+Nd` and `events / Nd` patterns aren't yet recognized.

Empirically observed 2026-05-30: 4 false-positive advisories fire on these patterns in framework-v7-8-branch-isolation, framework-v7-9-promotion, ucc-passkey-auth, and ucc-passkey-auth-security-hardening case studies. Pushed today's `Adv` count to 4 (vs 1 baseline), triggering the daily-checkpoint regression flag.

### Smallest viable shape

Extend `is_target_or_kill_claim()` in [`scripts/validate-tier-tags.py`](../../scripts/validate-tier-tags.py) to recognize:

```python
FORWARD_DEADLINE_PATTERNS = [
    r'T\+\d+d',                  # "T+7d", "T+14d"
    r'\d+\s*events?\s*/\s*\d+d', # "0 events / 7d", "10 events/30d"
    r'within\s+T?\+?\d+d',       # "within 7d", "within T+14d"
]
```

A claim's context matching any of these → skip. Existing `is_target_or_kill_claim()` already runs context inspection; just extend its pattern list.

### Why now

- 4 advisories every cycle means the regression-flag is permanently lit until cleared. Operator fatigue erodes the signal value of the flag.
- Phase-E-safe: tightens an advisory heuristic, doesn't add or enforce a new gate.

### Linked PR closing this thread

To be filled when shipped.

---

## W-MISTRAL-VERCEL-FREE-TIER-BURST

**Discovered:** 2026-05-30 (Sub-exp 1B Fire 0 — HADF Phase 2-bis replication attempt).
**Status:** workaround documented; deferred until operator decides Mistral + Vercel AI Gateway plan upgrades OR explicit 2-endpoint scope reduction.
**Owner:** operator (API tier decision); no code action queued.
**Effort:** ~30min if scope-reduction path is taken (modify ENDPOINTS dict + REQUIRED_KEYS + unlock-relock prereg ceremony).

### Problem

Sub-exp 1B's 4-endpoint design hit HTTP 429 rate-limits on mistral (free-tier RPS) and vercel-ai-gateway gpt-4o-mini (explicit "Upgrade to paid credits" message) during burst-fire pattern (50 calls back-to-back per endpoint). Fire 0 yielded 114/200 records (anthropic + google clean; mistral 9/50; vercel-ai-gateway 5/50).

Probe at 2 RPS later in the day showed both endpoints clean — burst pattern is the trigger. Either per-second RPS limits OR per-day quota windows.

### Workaround currently in effect

- Sub-exp 1B launchd job BOOTED-OUT 2026-05-30
- Plist moved to `~/.fittracker/deferred-plists/com.fitme.hadf-phase2bis-subexp1b.plist.deferred-2026-05-30`
- Fire 0 raw .jsonl preserved at `phase2bis-raw-subexp1b-subexp1b-2026-05-30T07-47-03Z.jsonl` + duplicate suffixed `.v1-rate-limited-partial`
- Prereg LOCKED at sha256=cfc7e968feeb (unchanged)
- Reversibility runbook: see `~/.fittracker/deferred-plists/README.md`

### Future fix options (when operator revisits)

- **A.** Upgrade Mistral + Vercel AI Gateway plans → re-bootstrap as-is (4 endpoints, burst pattern works)
- **B.** Drop mistral + vercel-ai-gateway → 2-endpoint scope reduction (anthropic + google only; silhouette analysis limited to k≤2)
- **C.** Add per-call throttle (sleep ~200ms between burst calls) to `scripts/hadf-phase2bis-collect.py` → 4-endpoint design works on free tiers but each fire takes ~3x longer

### Linked PR closing this thread

To be filled when shipped (or marked CLOSED if operator chooses to retire Sub-exp 1B entirely).

---

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
