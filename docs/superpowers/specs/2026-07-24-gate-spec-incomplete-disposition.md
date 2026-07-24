# GATE_SPEC_INCOMPLETE — Documented Disposition

**Status:** RESOLVED — **checklist + existing surfaces, NOT a new pre-commit gate.**
**Resolves:** infra-master-plan §8 Open Question #7 (opened 2026-05-12; decision date 2026-06-04, made 2026-07-24).
**Pattern:** documented-disposition (same shape as `2026-05-08-cross-repo-gate-asymmetry.md`) — the project records "no-build" decisions rather than leaving an open question dangling.

## §1 The question

infra-master-plan §3.5 requires every new framework infrastructure layer to ship a **Phase A** artifact set *before* production code lands:

- a spec (`function_name`, `emission_key`, dispatch site, expected skip reasons),
- 1 positive + 1 negative fixture,
- a regression test asserting `coverage.candidate(GATE)` fires under the expected input partition.

Q7: should Phase A be enforced by a **new pre-commit gate `GATE_SPEC_INCOMPLETE`** (mechanical, v7.8.1 spirit) or by a **PR-review checklist** (human, v7.8.4 humility)?

## §2 Why we do NOT build the gate

A mechanical `GATE_SPEC_INCOMPLETE` would have to (a) detect that "a new gate was added" and (b) verify its spec + fixtures + regression test exist. Both are problematic:

1. **Detection is fuzzy.** There is no crisp signal for "a new gate constant was added" — gates are Python functions/constants added to `check-state-schema.py` or `integrity-check.py` in myriad shapes (write-time, cycle-time, advisory, staged-file). A regex/heuristic detector would be exactly the kind of imprecise check v7.8.4 warns against ("a system that knows what it cannot check is more trustworthy than one that pretends every check is a check").
2. **It would duplicate mechanisms that already exist.** The Phase A artifact requirement is *already* observable through three shipped/scheduled surfaces:
   - **`gate-catalog.py`** — derives every gate's test tier and lists `write_time_without_try_repo`; `--check` fails CI if the committed catalog drifts. A gate with no test surfaces as `tier: none` / an untested-count regression.
   - **T16 gate-tier annotation** (`test_gate_catalog.py`) — asserts fixture-authority tiering and enforcement-flag parity per gate.
   - **Quarterly Data Freshness Audit** (first run **2026-08-12**, infra §3.5.3) — asserts each gate's `coverage.candidate` emission key matches its canonical function name and that `scripts/tests/` reference current names. This is precisely the "does the spec/test exist and stay in sync" assertion, run on a cadence, without a fuzzy per-commit detector.
3. **The failure mode it targets is low-frequency.** New framework gates are added a handful of times per version, always by an operator following the PM workflow — not the high-frequency, easy-to-forget surface (like `cache_hits[]`) that mechanical gates are best at.

## §3 What we DO ship (this disposition)

- **This document** — records the decision + rationale + re-eval triggers.
- **Phase A stays a PR-review checklist item**, backed by the three existing surfaces in §2. No new gate code, no new calibration window.
- The `/ux + /design pre-merge-review` skills and the PM-workflow Phase 6 gate remain the human enforcement point; the gate-catalog `--check` + Data Freshness Audit are the mechanical backstops.

## §4 What does NOT change

- All existing gates fire identically.
- The gate-catalog `--check` CI contract is unchanged.
- The 2026-08-12 Data Freshness Audit scope is unchanged (it already covers the spec↔code sync assertion).
- Phase B→E calibration cadence for *actual* new gates is unchanged.

## §5 Conditions that would warrant revisiting (re-eval triggers)

Re-open and reconsider a mechanical gate if **any** fires:

1. **≥2 new gates ship in a 90-day window with a missing Phase A artifact** caught only *after* merge (i.e. the checklist + existing surfaces demonstrably failed to catch it).
2. A Data Freshness Audit finds a gate that shipped with **no spec and no test** (proves the human checklist is insufficient).
3. Gate-addition frequency rises materially (e.g. an automated gate-generation flow), making the low-frequency argument in §2.3 obsolete.

## §6 Cross-references

- infra-master-plan §3.5 (Calibration Protocol), §3.5.3 (Data Freshness Audit), §8 Q7.
- `scripts/gate-catalog.py` + `scripts/tests/test_gate_catalog.py` (T16).
- `docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md` (disposition precedent).
- v7.8.4 humility principle (CLAUDE.md "Known Mechanical Limits").

## §7 Disposition record

| Field | Value |
|---|---|
| Question | infra §8 Q7 — GATE_SPEC_INCOMPLETE gate vs checklist |
| Decision | Checklist + existing surfaces (gate-catalog `--check` + T16 + Data Freshness Audit); no new gate |
| Decided | 2026-07-24 |
| Basis | Fuzzy detection; duplicates existing mechanisms; low-frequency failure mode |
| Reversal | Any §5 trigger re-opens Q7 |
