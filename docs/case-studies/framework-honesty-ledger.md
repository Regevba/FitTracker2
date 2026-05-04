---
title: Framework Honesty Ledger
date_created: 2026-05-03
case_study_type: roundup
work_type: chore
description: Append-only ledger of "we got this wrong + here's how" entries about the framework itself. Pattern from curl monthly reports + Postgres release notes ("broken in N.M, fixed in N.M+1") + Tailscale release notes' explicit "we got this wrong" sections. Each entry is FT2-FH-NNN, immutable once published, augmented only by appending new entries.
tier_tags_required: false
status: live
---

# Framework Honesty Ledger

> An append-only public record of framework claims that were later
> falsified by data, plus the closure path. **Original entries are
> never silently edited.** Corrections accrete as new entries with
> back-references. The ledger exists because trust is a track record,
> not a slogan: continuing to publish corrections IS the trust signal.
> (Closure rule: publish verbatim, then remediate.)
>
> Format inspiration: curl monthly reports, Postgres release notes
> "broken in N.M, fixed in N.M+1" pattern, Tailscale release notes'
> explicit "we got this wrong" sections, the CVE coordinated-disclosure
> protocol.

---

## FT2-FH-001 — v7.7 silent-pass on `CACHE_HITS_EMPTY_POST_V6`

**Status:** **CLOSED** in v7.8 (2026-05-02 → 2026-05-03 across PRs #173, #185, #186, #187, #188, #189, #192, #193).

**Original claim** (v7.7 case study, Section 99 / "Outcome at synthesis time" table, published 2026-04-27):

> | `cache_hits[]` post-v6 | 33.3% | **gated to 100% on next write (issue #140 closed)** |

**What the data showed** (T1, instrumented via Python sweep against `.claude/features/*/state.json`, captured 2026-04-30):

- The v7.7 `CACHE_HITS_EMPTY_POST_V6` gate read `state.get("created_at", "")` for its post-v6 cutoff comparison.
- **43 of 46 features (93%)** stored the timestamp under the legacy key `created` instead.
- The gate's first conditional (`created_at < V6_SHIP_DATE`) evaluated `"" < "2026-04-16"` → `True` → early return without finding for those 43.
- The remaining 3 features either had `created_at` set but were not yet at `current_phase=complete`, or had no `cache_hits` key at all (gated by `if cache_hits is None`).
- **Effective gate coverage at the time the v7.7 case study claimed "100% gated" was 0 / 46 features.**

Issue #140 was closed in spec, open in practice.

**Why this matters:** the v7.7 case study was written, peer-reviewed, and shipped while the headline gate had **0% effective coverage**. The framework asserted gate *implementation*; it never asserted gate *execution*. This is the exact failure mode v7.5 was created to prevent.

**Closure path** (v7.8):

1. **PR #169** (2026-05-01) — bulk migration: 43 state.json files renamed `created` → `created_at`. Gate's read path now sees the canonical field.
2. **PR #173** (2026-05-02, by Regev) — Mechanism C scaffolding (`PostToolUse:Read` hook + `scripts/observe-cache-hit.py`) + defensive dual-read `created` ∪ `created_at` + Mechanism-C exemption (`MECHANISM_C_SHIP_DATE`). v7.7 case study Section 99B correction note appended.
3. **PRs #185 + #186** (2026-05-03) — `framework_version` backfill: 39 missing + 6 unprefixed-numeric + 1 misspecified → 46/46 canonical `vX.Y` form. Validation criterion 3 from spec §9 hit.
4. **PR #187** (2026-05-03) — **Mechanism A** (the meta-fix): every write-time gate now emits `{candidates, checked, skipped, skip_reasons}` per run to `.claude/logs/gate-coverage.jsonl`. The first event captured on real corpus shows `CACHE_HITS_EMPTY_POST_V6: candidates=47, checked=0, skipped=47` — **the silent-pass evidence captured at the source.** v7.9 promotes `GATE_COVERAGE_ZERO` to enforced.
5. **PR #188** (2026-05-03) — Mechanism C wiring (T9 + T10 + T11): `/pm-workflow` writes `.claude/active-feature`, SessionStart surfaces it, `observe-cache-hit.py` reads it for attribution, new `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory fires when session ledger captures Reads but state.json drifts.
6. **PR #189** (2026-05-03) — Mechanism E git merge driver (`union-dedup-by-key`) auto-resolves append-only ledger conflicts.
7. **PR #192** (2026-05-03) — Schema bridge fields populated on all 47 features; new `path-reducers.json` + `agent-leases.json` registries.
8. **PR #193** (2026-05-03) — Mechanism D (`pre-commit-self-test`) asserts no header drift; Mechanism F (`membrane-status.py`) advisory smartlog.

**Tier tags:** all numerical claims in this entry are T1 (live Python sweep against the corpus, gate-coverage.jsonl captured at v7.8 ship). The 2026-04-30 audit memo + this ledger entry are the source.

**Lessons recorded:**

1. **Don't claim "100% gated" without verifying the gate can fire.** v7.8 Mechanism A makes this structurally observable; v7.9 promotes the meta-check to enforced.
2. **Don't add a gate that depends on a field most features don't use.** v7.8 Mechanism B (dual-read + canonical schema) gives field-rename drift a detection surface.
3. **Memory drift is itself a silent-pass surface.** The 2026-04-30 audit memo was 2 days stale at the start of the v7.8 work session. Several "open" items had already been closed by predecessor PRs. Verifying memory against current code BEFORE starting work is now a documented anti-pattern check.
4. **Continuing to publish IS the trust signal.** Per the publish-then-remediate rule: original v7.7 case study is unchanged on `main`; corrections accrete via Section 99B + this ledger entry. Pattern: curl monthly reports, Postgres release notes, Tailscale.

**Predecessor: none** (this is the first ledger entry).

**Successor: TBD** (next entry will be appended when the next "we got this wrong" surfaces and is closed).

**Cross-references:**

- v7.7 case study Section 99B correction note: [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md)
- v7.8 case study (live journal): [`docs/case-studies/framework-v7-8-bridge-case-study.md`](framework-v7-8-bridge-case-study.md)
- Bridge design spec: [`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](../superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- Audit memo (memory): `project_framework_gaps_audit_2026_04_30.md`
- Cold-start entrypoint: [`.claude/entrypoints/framework-v7-8.md`](../../.claude/entrypoints/framework-v7-8.md)

---

> _Next entry will be appended below this line when needed. Format
> is FT2-FH-NNN with immutable monotonic numbering. Entries are never
> silently edited; revisions are themselves new entries that
> back-reference the prior entry._
