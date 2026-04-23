# Contemporaneous Logging

> Groundwork for Gemini audit Tier 2.2.
> Status: **pilot active; logger hardened, full process migration not yet complete**.

## Why this exists

Retroactive case studies are useful, but they compress weeks of work into a
single narrative written after the fact. That creates two recurring problems:

1. It becomes hard to distinguish what was observed in the moment from what was
   inferred later.
2. Audit trust drops when a large percentage of the corpus was written in a
   short burst after the work already happened.

Contemporaneous logs solve that by recording meaningful events as they occur.

## Scope

This is not intended to replace case studies immediately. It creates a second
artifact:

- **Structured log:** append-only, feature-level, event-by-event
- **Narrative case study:** human-readable synthesis written later

The long-term target is: the case study is generated from, or at least grounded
by, the structured log rather than from memory alone.

As of **2026-04-23**, the logger is no longer purely permissive:

- timestamps must stay monotonic by default
- older events require explicit `--retroactive`
- retroactive entries must include `--retroactive-reason`
- each event records whether it was logged `contemporaneous` or `retroactive`

## Storage

Feature logs live at:

- `.claude/logs/<feature>.log.json`

The schema is simple on purpose:

- feature metadata copied from `state.json` when available
- append-only `events[]`
- no retroactive backfilling unless clearly marked

## Event model

Every event should try to answer four questions:

1. What happened?
2. In which phase?
3. What evidence path proves it?
4. What changed because of it?

Recommended fields:

- `timestamp`
- `event_type`
- `phase`
- `summary`
- `artifacts`
- `metrics`
- `actor`
- `status`

## CLI

Append or initialize a feature log:

```bash
python3 scripts/append-feature-log.py \
  --feature onboarding-v2-auth-flow \
  --event-type test_run \
  --phase test \
  --summary "Local XCTest suite passed after auth animation timing fix." \
  --artifact FitTrackerTests/AuthFlowTests.swift \
  --metric tests_passing=12 \
  --metric build_verified=true
```

The tool auto-creates the log if it does not already exist and copies basic
metadata from `.claude/features/<feature>/state.json` when present.

If you need to backfill an older event deliberately:

```bash
python3 scripts/append-feature-log.py \
  --feature meta-analysis-audit \
  --event-type docs_published \
  --phase documentation \
  --summary "Retroactive note for a document published before the logger hardened." \
  --timestamp 2026-04-21T16:00:00Z \
  --retroactive \
  --retroactive-reason "Capturing a pre-hardening milestone from the Gemini follow-up batch."
```

## Rollout plan

### Phase 1 — scaffolding

- log directory exists
- append tool exists
- format is documented

### Phase 2 — active-feature adoption

- every multi-session feature starts a log at Phase 0/1
- major checkpoints append events during work, not after merge
- at least one real log exists in `.claude/logs/` for the active audit/remediation stream

### Phase 3 — case-study grounding

- case studies cite log checkpoints explicitly
- case-study-monitoring can ingest the log as first-party evidence

## What this does NOT do yet

- It does not auto-write events from every PM workflow transition.
- It does not generate case studies automatically.
- It does not retroactively repair the old corpus.

Those are follow-on steps after the logging convention proves useful in active
work.
