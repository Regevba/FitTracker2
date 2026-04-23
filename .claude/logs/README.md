# Contemporaneous Feature Logs

This directory holds append-only feature execution logs that capture what
happened while the work was happening, not weeks later when a case study is
written from memory.

## Purpose

- Reduce retrospective distortion in case studies and audits.
- Preserve a first-party event trail for multi-session features.
- Make "what actually happened?" answerable from a structured log instead of
  only prose.

## File format

One file per feature:

- `.claude/logs/<feature>.log.json`

Each file contains top-level feature metadata plus an append-only `events`
array. Events are added in time order and are never rewritten in place except
to create the file initially.

The helper now enforces that ordering by default. If an older event must be
recorded after the fact, it has to be marked explicitly as retroactive and
carry a reason.

## Recommended event types

- `phase_started`
- `phase_approved`
- `implementation_checkpoint`
- `test_run`
- `review_note`
- `merge_recorded`
- `runtime_verification`
- `docs_published`
- `blocked`
- `decision`

## CLI

Use the helper:

```bash
python3 scripts/append-feature-log.py \
  --feature user-profile-settings \
  --event-type implementation_checkpoint \
  --phase implement \
  --summary "Layer 2 view extraction landed and local build stayed green." \
  --artifact FitTracker/Views/Profile/v2/ProfileHubView.swift \
  --artifact FitTrackerTests/ProfileViewTests.swift
```

Retroactive append example:

```bash
python3 scripts/append-feature-log.py \
  --feature meta-analysis-audit \
  --event-type docs_published \
  --phase documentation \
  --summary "Backfilled note for a pre-existing milestone." \
  --timestamp 2026-04-21T16:00:00Z \
  --retroactive \
  --retroactive-reason "Recorded after the logger hardening landed."
```

See `docs/process/contemporaneous-logging.md` for the convention and rollout
plan.
