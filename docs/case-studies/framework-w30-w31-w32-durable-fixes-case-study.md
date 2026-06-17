---
slug: framework-w30-w31-w32-durable-fixes
title: "W30 + W31 + W32 durable fixes — parser bare-int fallback, workflow-coverage detector, close-feature single-phase auto-skip"
date_written: 2026-06-05
framework_version: v7.9.1
work_type: Chore
work_subtype: framework_feature
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/framework-w30-w31-w32-durable-fixes-case-study.md
case_study_showcase: ""
related_prs: [637]
pr_citation_exempt:
  - {pr_number: 623, reason: "Cross-reference to F-LAUNCHD-DRIFT-EXTENSION (a) feature PR — surfacing-session context for W31 incident, not this Chore's own PR"}
  - {pr_number: 624, reason: "Cross-reference to F-LAUNCHD-DRIFT-EXTENSION (b)+(c) closure PR — surfacing-session context for W30+W32, not this Chore's own PR"}
  - {pr_number: 633, reason: "Cross-reference to v7.9.1 4-stuck-features closure PR — same-session retrospective example for W32, not this Chore's own PR"}
  - {pr_number: 636, reason: "Cross-reference to framework-v7-9-1-promotion closure PR — same-session retrospective example for W32, not this Chore's own PR"}
dispatch_pattern: serial
success_metrics:
  - name: w_patterns_resolved
    baseline: 0
    target: 3
    significance: descriptive
    review_at: 2026-06-05
    tier: T1
    note: "(T1) W30 + W31 + W32 each get a 'Durable fix SHIPPED 2026-06-05' annotation in observed-patterns.md."
  - name: unit_tests
    baseline: 0
    target: 16
    significance: descriptive
    review_at: 2026-06-05
    tier: T1
    note: "(T1) scripts/tests/test_w30_w31_w32_durable_fixes.py — 16 tests covering W30 (6), W31 (3), W32 (7). All pass under python3 -m unittest."
  - name: same_session_dogfood
    baseline: 0
    target: 1
    significance: blocking
    review_at: 2026-06-05
    tier: T1
    note: "(T1) This feature itself uses the new W32 auto-skip path at closure time — work_subtype=framework_feature triggers the new logic. close-feature.py emits 'ℹ W32 auto-skip: ...' instead of the old 'must use --force-incomplete' error."
predecessor_case_study: docs/case-studies/framework-v7-9-1-promotion-case-study.md
spec: ".claude/integrity/observed-patterns.md W30 + W31 + W32 + saved-memory project_session_2026_06_04_observed_patterns_overlay_and_3d_phase_2.md 'Tomorrow's queue'"
key_numbers:
  w_patterns_resolved: 3
  scripts_patched: 2
  scripts_added: 1
  unit_tests: 16
  lines_of_test: 220
  same_session_v7_9_1_closures_unblocked_retroactively: 5
kill_criteria:
  - "W30 fallback accidentally matches a non-PR-number string and inflates the parity count — would create false positive findings"
  - "W31 detector false-positive rate too high to be useful operationally"
  - "W32 auto-skip masks a real partial-phase landing that should have been blocked"
kill_criteria_resolution: "All 3 mitigated by design + tests. (1) W30 fallback only fires after the `#N` regex has already failed AND the string is `str.isdigit()` — non-digit strings short-circuit; test `test_non_digit_strings_silently_skipped` enforces. (2) W31 detector uses a curated `ALWAYS_EXPECTED_PATTERNS` list (path-filtered and schedule-only workflows are intentionally excluded), validated by smoke test against PR #636 reporting 14/14 with 0 false positives. (3) W32 auto-skip is restricted to 3 work-shape signals (work_subtype=framework_feature OR work_type in {Chore,Fix} OR explicit single_phase: true) — regular Feature work_type still requires --force-incomplete; test `test_regular_feature_still_requires_force_incomplete` enforces. Operator still sees an audit-trail log message when auto-skip fires."
---

## TL;DR (T1 unless tagged)

Three surgical patches close three workflow-blocking patterns surfaced during yesterday's v7.9.1 build window:

| Pattern | Fix | LOC |
|---|---|---|
| **W30** Q6 parity gate's YAML parser silently strips bare-int list items | `_collect_case_study_pr_numbers` adds `str.isdigit()` fallback after `#N` regex fails | +12 in `check-state-schema.py` |
| **W31** Workflow delivery anomaly — initial PR open sometimes fires only a subset of expected workflows | New operator-side detector `scripts/check-pr-workflow-coverage.py` compares always-expected vs actual check-runs+statuses | +150 new file |
| **W32** `close-feature.py` requires `--force-incomplete` for any feature closing from `implementation` phase | Auto-skip when `work_subtype=framework_feature` OR `work_type in {Chore,Fix}` OR explicit `single_phase: true` | +20 in `close-feature.py` |

Test coverage: **16 unit tests** in `scripts/tests/test_w30_w31_w32_durable_fixes.py` — 6 (W30) + 3 (W31) + 7 (W32). All pass via `python3 -m unittest`. No pytest dep required.

**Same-session dogfood**: this Chore is itself a `framework_feature` work_subtype, so its closure uses the new W32 auto-skip path. The new log line `ℹ W32 auto-skip: ...` confirms the path fired.

**Phase-E-safe** by construction — Chore + observability-only + warn-only behavior, no new enforcement gates, no schema additions.

## What changed

### W30 — parser bare-int fallback

`_collect_case_study_pr_numbers` at [`scripts/check-state-schema.py:1218`](../../scripts/check-state-schema.py#L1218) gains a fallback branch after the `re.search(r'#(\d+)', r)` regex fails:

```python
if isinstance(r, str):
    m = re.search(r'#(\d+)', r)
    if m:
        prs.add(int(m.group(1)))
    else:
        # W30 (v7.9.1+ durable fix): bare-int from inline YAML list
        # (`related_prs:\n  - 623`) is stringified to "623" by
        # _parse_case_study_frontmatter at :1149. Accept bare digit
        # strings so the operator's natural first attempt works.
        s = r.strip()
        if s.isdigit():
            prs.add(int(s))
```

This closes the 4-commit-retry loop documented in W30 — the operator's natural first attempt (`related_prs:\n  - 623`) now works without falling back to the `"PR #623"` string form or the inline `[623, 621]` bracket form.

### W31 — operator-side workflow-coverage detector

New file [`scripts/check-pr-workflow-coverage.py`](../../scripts/check-pr-workflow-coverage.py). Invocation:

```bash
python3 scripts/check-pr-workflow-coverage.py <PR_NUMBER>
```

**Design** — instead of trying to derive expected workflows by parsing `.github/workflows/*.yml` (which over-counts path-filtered + schedule-only workflows), the script maintains a curated `ALWAYS_EXPECTED_PATTERNS` list of check-run name substrings. When CI changes, update the list.

Combines both `/check-runs` (Actions) + `/status` (commit-status) endpoints to mirror what `gh pr checks` shows. The `pm-framework/pr-integrity` sticky-comment bot publishes via the status endpoint, not check-runs, so check-runs-alone under-counts.

**Smoke-test outcomes:**
- PR #636 (known-good closure): **14/14 present** ✓ — no false positives
- PR #623 (the W31 incident PR): **12/14 present** — correctly flags 2 historical missing workflows that didn't exist when #623 opened (gitleaks + lint commits both shipped post-#623 via PRs #627 + #619)

Choice of operator-side detection vs CI enforcement is intentional. The rebase + force-push remediation documented in W31 is bounded and reliable; the value is detection + nudge, not a blocking gate.

### W32 — close-feature single-phase auto-skip

`close_feature()` at [`scripts/close-feature.py:138`](../../scripts/close-feature.py#L138) gains a check for single-phase work shapes:

```python
EARLY_PHASES = {"research", "prd", "tasks_phase", "ux_or_integration", "implementation"}
SINGLE_PHASE_SUBTYPES = {"framework_feature"}
SINGLE_PHASE_WORK_TYPES = {"Chore", "Fix"}
if state.get("current_phase") in EARLY_PHASES:
    is_single_phase = (
        state.get("single_phase") is True
        or state.get("work_subtype") in SINGLE_PHASE_SUBTYPES
        or state.get("work_type") in SINGLE_PHASE_WORK_TYPES
    )
    if is_single_phase:
        print(f"ℹ W32 auto-skip: ...", file=sys.stderr)
    else:
        # original warning + --force-incomplete requirement preserved
```

Regular `Feature` work_type with no `single_phase: true` still requires `--force-incomplete` for safety — protects against the original failure mode (operator merging a partial-phase Feature PR and forgetting downstream phases exist).

**Same-session retrospective:** the 5 v7.9.1 features closed earlier today (`f-deployed-url-probe-ft2`, `f-phase-e-adoption-freeze-discipline`, `dev-env-r11-r13-r14-r17-r18-batch`, `r9-track-b-coverage-aggregator` via PR #633 + `framework-v7-9-1-promotion` via PR #636) would have closed without `--force-incomplete` under the new logic. The auto-skip would have emitted 5 informational log lines instead of 5 manual flag-passes.

## Why this design

**Why bundle all three.** All three patterns surfaced in the same 2026-06-04 session, were filed as candidate durable fixes in the same backlog entry (per `F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE` Framework hygiene subsection), and are small enough that the test-fixture setup overhead per PR exceeds the actual change. Single PR with 16 unit tests + 3 surgical patches is the right granularity.

**Why no schema changes.** Each fix preserves existing data shapes. W30 adds a new acceptable input form (was rejected, now accepted); existing `"PR #N"` form still works. W31 reads gh-API surfaces, no state changes. W32 reads existing `work_subtype` + `work_type` + `single_phase` fields that operators already populate.

**Why warn-only / operator-side for W31.** The W31 incident showed the GitHub Actions webhook delivery anomaly is transient. Building a CI gate against it would require the gate to itself navigate the anomaly. An operator-side detector pointed at a specific PR is bounded, debuggable, and doesn't add to the PR-blocking surface.

**Why this is W32-itself's first dogfood.** This Chore is `work_subtype: framework_feature`. When it closes, the new W32 auto-skip fires. If the patch is wrong, this very feature won't close cleanly. Built-in regression test.

## Verification

```bash
# W30 + W31 + W32 unit tests
python3 -m unittest scripts/tests/test_w30_w31_w32_durable_fixes.py
# Expected: Ran 16 tests in <1s; OK

# W31 detector smoke-test against known-good PR
python3 scripts/check-pr-workflow-coverage.py 636
# Expected: 14/14 present, exit 0

# W30 fix in action — case study with bare-int related_prs now parses
python3 -c "
import importlib.util, json
spec = importlib.util.spec_from_file_location('m', 'scripts/check-state-schema.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fm = m._parse_case_study_frontmatter('---\nrelated_prs:\n  - 623\n  - 624\n---\n')
print(m._collect_case_study_pr_numbers('', fm))
"
# Expected: {623, 624}  (was: set() before the fix)
```

All 3 verifications pass at commit time.

## Open follow-ups

- **W30 broader rollout** — same parser quirk likely affects other `  - N` list types beyond `related_prs`. If a future operator surfaces the same pattern for `tasks[].related_prs` or a new list field, the same `isdigit()` fallback applies. Worth a sweep but not blocking.
- **W31 list maintenance** — `ALWAYS_EXPECTED_PATTERNS` is hand-curated. If a new always-run workflow ships (e.g., a future required-coverage gate), the operator must add it to the list. Acceptable maintenance burden.
- **W32 explicit `single_phase: true` adoption** — currently no v7.9.1+ features set this field explicitly; they rely on `work_subtype: framework_feature`. Worth documenting in the pm-workflow skill that single-phase Chores/Fixes can set the explicit flag for unambiguous closure semantics.

## References

- W30: [`observed-patterns.md` W30](../../.claude/integrity/observed-patterns.md) (durable-fix annotation appended this PR)
- W31: [`observed-patterns.md` W31](../../.claude/integrity/observed-patterns.md) (same)
- W32: [`observed-patterns.md` W32](../../.claude/integrity/observed-patterns.md) (same)
- Source surfacing session: `docs/case-studies/framework-v7-9-1-promotion-case-study.md` §3 cascading-rebase rhythm + `docs/case-studies/f-phase-e-adoption-freeze-discipline-case-study.md` §What changed (backlog hygiene subsection)
- Same-session v7.9.1 feature closures unblocked retroactively: PR #633 + PR #636 (the manual `--force-incomplete` invocations of yesterday's closure work would now auto-skip)

---

**Shipped via PR #637** (`chore(framework): W30+W31+W32 durable fixes — parser bare-int + workflow-coverage detector + single-phase auto-skip`, merged 2026-06-05 as `a065798`). Closure via the new W32 auto-skip path (eating its own dogfood).
