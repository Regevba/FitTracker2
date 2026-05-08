# Cross-Repo Gate Asymmetry — Documented Disposition

**Created:** 2026-05-08
**Closes:** v7.9 candidates F7 + F8 (per [`2026-05-08-framework-v7-9-candidates.md`](./2026-05-08-framework-v7-9-candidates.md))
**Tracks:** [fitme-story-public-enhancements](../../../.claude/features/fitme-story-public-enhancements/state.json) tasks T22 + T23
**Disposition:** Document the asymmetry (no full parity build)

---

## §1 The asymmetry

The PM framework's mechanical enforcement layer (state.json gates, Tier 2.2 logging, Mechanism A coverage telemetry, Mechanism C session attribution) lives **entirely in the FitTracker2 repo**. The companion `fitme-story` repo (Next.js showcase site at https://fitme-story.vercel.app) has none of these gates.

This is by design: fitme-story has **no `state.json` files**, no PM-workflow-managed features, and no per-feature lifecycle to enforce. It is a Next.js application repo that consumes mirrored data from FT2 via the pre-build sync (`fitme-story/scripts/sync-from-fittracker2.ts`).

**Empirical evidence (collected during the 2026-05-08 audit session):**

- Every Read tool call against any file in `/Volumes/DevSSD/fitme-story/` triggered the FT2 PostToolUse:Read hook trying to run `python3 scripts/observe-cache-hit.py` — but `scripts/observe-cache-hit.py` only exists in FT2's `scripts/` directory. The fitme-story repo's `scripts/` directory contains different tooling (`sync-from-fittracker2.ts`, `verify-blind-switch.sh`, etc.).
- Result: 30+ blocking-error notifications across the session that were pure noise — the hook had nothing to do but couldn't gracefully no-op because the command lacked an existence guard.
- `gate-coverage.jsonl` (Mechanism A telemetry) only exists in `FT2/.claude/logs/`. Cross-repo features (UCC, ucc-passkey-auth, fitme-story-public-enhancements) get gate-coverage telemetry only for their FT2 commits.
- `_session-*.events.jsonl` (Mechanism C session attribution) only exists in `FT2/.claude/logs/`.

## §2 Why we don't build full parity

Three reasons, in order of importance:

1. **fitme-story has no `state.json` files to gate against.** The pre-commit gates in FT2 (`STATE_SCHEMA`, `CU_V2_INVALID`, `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `STATE_NO_CASE_STUDY_LINK`, `CASE_STUDY_MISSING_FIELDS`, `BRANCH_ISOLATION_VIOLATION`, `FEATURE_CLOSURE_COMPLETENESS`, `ISOLATION_OPT_OUT_REASON_MISSING`) all fire on state.json mutations. fitme-story has zero state.json files. Gates would have nothing to check.

2. **The gates protect data integrity for the PM workflow's own bookkeeping.** That bookkeeping lives in FT2 (every `.claude/features/*/state.json`, every `.claude/logs/*.log.json`, every case study at `docs/case-studies/`). When a feature's work spans both repos (UCC, ucc-passkey-auth, this rollup), the FT2 side is where the framework state lives — fitme-story is the deployment surface, not the bookkeeping surface.

3. **Porting infrastructure to fitme-story would be high-effort, low-value.** The FT2 gate stack assumes Python tooling (`scripts/check-state-schema.py`, `scripts/integrity-check.py`, `scripts/append-feature-log.py`), Make targets (`make verify-isolation`, `make documentation-debt`), and `.githooks/pre-commit` infrastructure. fitme-story is a Node.js-only deployment repo with no Python tooling and no Make targets. Porting would create two parallel infrastructures that drift over time.

## §3 What we DO ship (this PR)

### Hook fix — silent no-op when script absent

**File:** [`.claude/settings.json`](../../../.claude/settings.json)

The `PostToolUse:Read` hook command was changed from:
```bash
python3 scripts/observe-cache-hit.py
```
to:
```bash
[ -f scripts/observe-cache-hit.py ] && python3 scripts/observe-cache-hit.py || true
```

The Bash short-circuit means: if the script exists (FT2 cwd), run it normally. If the script is missing (fitme-story cwd, FitTracker2-* worktrees with stale or missing `scripts/` dir, or any other repo), no-op silently.

**Closes:** the `python3 scripts/observe-cache-hit.py: No such file or directory` blocking-error notification noise.

### This documentation

The current document. Records the asymmetry, the rationale for not closing it, and the conditions that would warrant revisiting.

## §4 What does NOT change

- **Mechanism C still attributes correctly when cwd is FT2.** The `.claude/active-feature` lockfile still pins the active feature for session events.
- **Mechanism A telemetry still emits for every gate fire on FT2 state.json mutations.** `gate-coverage.jsonl` continues to grow.
- **Tier 2.2 contemporaneous logging via `scripts/append-feature-log.py` still works for any feature whose state.json is in FT2** (which is all of them).
- **The pre-commit gate stack still fires on FT2 commits.** No reduction in coverage.
- **Cross-repo features (e.g., this `fitme-story-public-enhancements` rollup) still attribute to a single FT2 state.json.** Their per-task PRs in fitme-story continue to be tracked in FT2's `tasks[]` ledger via PR number + merge commit.

## §5 Conditions that would warrant revisiting (re-eval triggers)

This disposition holds unless one of these signals fires:

| Signal | Re-eval trigger | What would change |
|---|---|---|
| **fitme-story acquires its own `state.json`-tracked features** | At least 3 features defined entirely within fitme-story (not cross-repo) over a 90-day window | Port pre-commit gate stack to fitme-story (or sub-set of relevant gates) |
| **External auditor wants to verify gate coverage independently across both repos** | Audit ask landed in `trust/audits/` | Build a cross-repo gate-coverage aggregator that reads both `FT2/.claude/logs/gate-coverage.jsonl` and a future `fitme-story/.claude/logs/gate-coverage.jsonl` |
| **fitme-story commits start mutating FT2 state without going through FT2** | Currently impossible by repo isolation; would require restructuring; flag if it ever happens | Cross-repo state-mutation protocol |

None of these signals are firing today. Re-evaluate annually OR when one of the above conditions changes.

## §6 Cross-references

- v7.9 candidates spec (where F7 + F8 originate): [`2026-05-08-framework-v7-9-candidates.md`](./2026-05-08-framework-v7-9-candidates.md) §2 (canonical 8 candidates) — F7 + F8
- Audit synthesis (where the empirical evidence was collected): [`docs/research/2026-05-08-fitme-story-audit-synthesis.md`](../../research/2026-05-08-fitme-story-audit-synthesis.md)
- Website-enhancement-queue spec (where F7 + F8 are tracked as T22 + T23): [`2026-05-08-fitme-story-website-enhancement-queue.md`](./2026-05-08-fitme-story-website-enhancement-queue.md) §4 (shared infrastructure track)
- Roadmap stress-test case study (where F7 + F8 were originally surfaced): [`docs/case-studies/roadmap-stress-test-2026-05-07-case-study.md`](../../case-studies/roadmap-stress-test-2026-05-07-case-study.md) §99 (F7, F8 entries)

## §7 Disposition record

| Aspect | Decision |
|---|---|
| **F7 (Tier 2.2 per-phase emission gate parity)** | NOT PORTED to fitme-story. Documented exemption. |
| **F8 (Mechanism A `gate-coverage.jsonl` parity)** | NOT PORTED to fitme-story. Documented exemption. |
| **Hook noise** | FIXED via cwd-guard in `.claude/settings.json` PostToolUse:Read command. |
| **Re-evaluation cadence** | Annual OR on signal trigger (see §5). Next review: 2027-05-08 OR earlier if signal fires. |
