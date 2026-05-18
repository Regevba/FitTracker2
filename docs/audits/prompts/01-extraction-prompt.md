# Extraction Prompt — Impartial Audit Bundle Generator

> **Audience:** the operator running Claude Code (or equivalent) on `<repo>` immediately before an external audit.
> **Output:** a deterministic, redacted `bundle.md` + `manifest.json` + `redaction-log.json` in `docs/audits/runs/YYYY-MM-DD-<auditor-model>/`.
> **Reproducibility contract:** same inputs + same `build_bundle.py` SHA256 → identical `bundle.md` SHA256.

---

## How to run

1. Verify you are on a clean `main` (no uncommitted changes that should be in the bundle):

   ```bash
   git status --short
   git pull --ff-only
   ```

2. Pick the profile that matches the audit date (see table below).

3. Run the builder:

   ```bash
   make audit-bundle PROFILE=<profile-name>
   ```

   or equivalently:

   ```bash
   python3 scripts/audit/build_bundle.py --profile=<profile-name> --run-label=YYYY-MM-DD-<auditor-model>
   ```

4. Verify the output:

   ```bash
   ls -lh docs/audits/runs/<run-label>/
   # Expected: bundle.md, manifest.json, redaction-log.json
   head -10 docs/audits/runs/<run-label>/bundle.md
   # Expected: hash-stamped header with profile name + bundle SHA256
   ```

5. Spot-check redaction by grepping for known sensitive patterns:

   ```bash
   grep -c "regvash21\|fitme-490515\|531124395\|/Volumes/DevSSD\|/Users/regevbarak" docs/audits/runs/<run-label>/bundle.md
   # Expected: 0
   ```

6. Open `docs/audits/runs/<run-label>/bundle.md`, copy its full content, and paste it into a fresh chat **after** pasting `docs/audits/prompts/02-auditor-prompt.md`.

7. When the auditor returns its 3-phase report, save it to `trust/audits/<run-label>/report.md` and commit alongside `manifest.json` + `redaction-log.json`.

---

## Profile selection table

| Audit date | Audit label | Profile |
|---|---|---|
| 2026-05-22 | External Audit #1 | `v7-9-promotion` |
| 2026-06-12 | External Audit #2 | `v7-9-1-f16-plus-hadf` |
| 2026-08-05 | External Audit #3 | `v8-0-gates-plus-hadf-closure` |
| 2026-08-12 | Data Freshness Audit #1 | `freshness` |
| 2026-10-08 | External Audit #4 | TBD — defaults to `base` until scope decided |
| 2026-11-12 | Data Freshness Audit #2 | `freshness` |
| 2027-02-12 | Data Freshness Audit #3 | `freshness` |
| 2027-05-12 | Data Freshness Audit #4 | `freshness` |

---

## What the bundle contains

Each profile inherits from `base`:

- `docs/case-studies/**/*.md` (every case study + meta-analyses)
- `.claude/shared/measurement-adoption.json`
- `.claude/shared/measurement-adoption-history.json`
- `.claude/shared/documentation-debt.json`
- `.claude/shared/case-study-monitoring.json`
- `.claude/shared/case-study-t1-references.json`
- `trust/audits/**/*.md` (prior audits — gives the auditor precedent)
- Generated `_state-snapshot.json` (subset of every feature's state.json)

Profile-specific globs add HADF prereg, F16 fixtures, ORCHID synthesis, gate-coverage ledgers, or the integrity-check sources (for freshness profile).

---

## What gets redacted

Single source of truth: `scripts/audit/redaction.py`. Standard depth:

- Email addresses → `[REDACTED_EMAIL]`
- Service account emails → `[REDACTED_SERVICE_ACCOUNT]`
- GCP project IDs → `[REDACTED_GCP_PROJECT]`
- GA4 property IDs → `[REDACTED_GA4_PROPERTY]`
- OAuth tokens, Sentry DSNs, Vercel bypass tokens → `[REDACTED_*]`
- Absolute paths `/Volumes/DevSSD/FitTracker2` → `<repo>`, `/Users/regevbarak` → `<home>`

Kept intact (deliberately):

- GitHub usernames `Regevba` and repo names `Regevba/FitTracker2`, `Regevba/fitme-story` (public on GitHub anyway)
- PR numbers `#NNN`, commit SHAs, branch names
- The pseudonym "the operator"

---

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `python3 -m unittest scripts.audit.tests.test_redaction` fails | Local redaction regex drift | Run `make audit-prompts-self-check` |
| Bundle SHA differs across consecutive runs | Generation timestamp leaked into hashed body | Pass `--run-label` explicitly; the body excludes the timestamp |
| Bundle > 500KB warning | Profile too broad for chat context | Re-run with narrower profile, or split manually by section |
| `grep` finds a redacted-pattern leak | New PII shape introduced in the corpus | Add a rule to `scripts/audit/redaction.py` + test in `tests/test_redaction.py` |
| Profile JSON missing parent | New profile inherits from a deleted base | Restore parent profile or change `inherits_from` |

---

## Companion: the auditor prompt

Once the bundle is built, the operator pastes [`02-auditor-prompt.md`](./02-auditor-prompt.md) **first** into the fresh chat, then the bundle content. The auditor returns a 3-phase report (Inventory → Discrepancies → Corrections) per the schema defined there.
