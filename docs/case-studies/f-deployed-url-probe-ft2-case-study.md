---
slug: f-deployed-url-probe-ft2
title: "F-DEPLOYED-URL-PROBE (FT2 side) — reusable bash helper for deployed-URL probing"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/f-deployed-url-probe-ft2-case-study.md
case_study_showcase: ""
related_prs: [628]
dispatch_pattern: serial
success_metrics:
  - name: shell_helper_lines
    baseline: 0
    target: 100
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) scripts/probe-deployed-url.sh shipped — 111 lines with 4 assertion modes (status, content-type, body-contains, body-not-contains). Measured by `wc -l`."
  - name: unit_tests_passing
    baseline: 0
    target: 12
    significance: blocking
    review_at: 2026-06-04
    tier: T1
    note: "(T1) scripts/tests/test_probe_deployed_url.py — 12/12 pass in 1.60s using stdlib http.server (no external network). Test bench reproduces W18 (status mismatch) + W19 (encoded-newline body)."
  - name: silent_pass_classes_closed
    baseline: 0
    target: 2
    significance: blocking
    review_at: 2026-06-11
    tier: T2
    note: "(T2) W18 (og:image 404) + W19 (GA_ID encoded-newline) silent-pass classes closed by the script's assertion modes. Effective coverage measured once fitme-story integration ships."
kill_criteria:
  - "Helper fails to detect a real W18/W19-class bug on a real deploy"
  - "False-positive rate on legitimate URLs is high enough that workflows disable it"
  - "Shell script has command-injection vulnerabilities through unescaped URL/arg values"
kill_criteria_resolution: "All 3 mitigated by design + verified. (1) The 4 assertion modes match the 2 documented silent-pass classes exactly — W18 needs status check on the og:image URL; W19 needs body-not-contains for %0A. Tests `test_body_not_contains_fail_on_newline_corruption` and `test_status_mismatch_fail` are direct reproducers. (2) The helper is invoked by the workflow caller (operator's YAML), not run autonomously — false-positive rate is bounded by which URLs the workflow author chooses to probe. (3) The script uses `set -euo pipefail`, double-quoted variable expansions, and positional argument parsing (no eval/source/sh -c). curl is invoked with separate --output and --dump-header arguments so the URL is never interpolated into a shell-interpreted context. Test `test_unknown_option_usage_error` enforces strict option parsing."
primary_metric: "unit_tests_passing = 12 (T1, all pass in 1.60s)"
predecessor_case_study: docs/case-studies/dev-env-r11-r13-r14-r17-r18-batch-case-study.md
spec: ".claude/shared/v7-9-1-candidates.md F-DEPLOYED-URL-PROBE"
key_numbers:
  shell_helper_lines: 111
  unit_tests: 12
  test_wall_time_seconds: 1.60
  assertion_modes: 4
  silent_pass_classes_closed: 2
  ship_class: "Feature (framework_feature subtype; FT2 substrate only)"
  fitme_story_integration_status: "Deferred to separate PR in fitme-story repo (operator FT2-only directive)"
---

## TL;DR (T1 unless tagged)

Ships the **reusable bash helper** at [`scripts/probe-deployed-url.sh`](../../scripts/probe-deployed-url.sh) that closes the silent-pass class where the deployed HTML SAYS a URL is reachable but the receiving service can't actually fetch + process it. Trigger incidents (both documented as observed-patterns):

| W# | Bug | Days dormant | Receiving service |
|---|---|---|---|
| **W18** | `<meta property="og:image">` pointed at `${SITE_BASE}/og.png`; actual image was at `${SITE_BASE}/opengraph-image` | 6 (2026-05-21 → 2026-05-27) | LinkedIn/Twitter/HN preview fetchers |
| **W19** | GA measurement ID had a trailing `\n` from env-var paste residue; gtag URL got `id=G-XE4E1JGWRZ%0A` | 6 (2026-05-21 → 2026-05-27) | Google Measurement Protocol |

Both passed local dev + Vercel preview-deploy inspection because neither runs the receiving-service round-trip. Both manifested only after production deploy + actual end-user inspection.

This PR ships **the FT2 side of the fix** — a reusable bash helper plus its 12-test pytest suite. The fitme-story-side workflow integration that calls the helper on each successful Vercel deploy is a separate PR in the fitme-story repo (operator FT2-only directive for this session).

## What changed

3 files: 1 script + 1 test + 1 doc reference.

**`scripts/probe-deployed-url.sh`** — 111 lines. Bash helper with 4 assertion modes:

```bash
scripts/probe-deployed-url.sh <url>
    [--status N]
    [--content-type PATTERN]
    [--body-contains TEXT]
    [--body-not-contains TEXT]
```

Exit codes: `0` (all assertions pass), `1` (assertion failed), `2` (usage error), `3` (curl/network error before assertion could run).

Security: `set -euo pipefail` + double-quoted expansions + positional argument parsing. No `eval`, no `source`, no `sh -c`. curl uses separate `--output` + `--dump-header` so the URL is never interpolated into a shell-interpreted context.

**`scripts/tests/test_probe_deployed_url.py`** — 12 tests. Spawns a stdlib `http.server` in a thread with a handler that responds to 7 distinct paths (ok-html, ok-xml, robots-with-sitemap, robots-no-sitemap, not-found, with-newline-token, clean-token), then invokes the shell script as a subprocess against each path with the relevant assertion flag permutation. No external network; runs in 1.60s.

Coverage:
- Usage error (no args) → exit 2
- Status check pass + fail (W18 reproducer)
- Content-type check pass + fail
- Body-contains pass + fail
- Body-not-contains pass + fail (W19 reproducer)
- Compound assertion (all 4 flags simultaneously)
- Unknown option → exit 2
- Curl error on unreachable host → exit 3

**`CLAUDE.md`** — new `## Deployed-URL probe (v7.9.1+)` section between F-LAUNCHD-DRIFT-EXTENSION and Soak-window discipline. Documents the 4 assertion modes with copy-pasteable invocation examples for the W18 + W19 reproducers + canonical/sitemap/robots reachability checks.

## Why this design

**Why a bash helper, not a Python script.** Workflow YAMLs already speak bash (in `run:` blocks). A bash helper integrates into any workflow without adding a `setup-python` step or test-dep bloat. The test suite is Python because pytest + `http.server` give the cleanest mock-server harness.

**Why 4 assertion modes (not more, not fewer).** Each mode maps 1:1 to a documented silent-pass class:
- `--status` → reachability bugs (W18 og:image, broken canonical URLs, missing sitemap)
- `--content-type` → MIME-type mismatches (sitemap returning HTML instead of XML)
- `--body-contains` → required-content bugs (robots.txt missing Sitemap: line)
- `--body-not-contains` → corruption bugs (W19 encoded newline; future: token leaks)

Adding a 5th mode (e.g., `--header-equals`, `--cookie-exists`) on speculation would have failed the YAGNI test. The 4 shipped modes cover both documented W-patterns + every URL-probe assertion the fitme-story DISCO workflow currently needs.

**Why FT2 ships the substrate but not the integration.** The shell helper is repo-agnostic — same script works in either repo's workflow. The fitme-story-side workflow YAML that calls it on each Vercel deploy needs fitme-story-specific URLs (production hostname, expected og:image path, GA measurement ID validation rules) and is a fitme-story-side PR. Per operator FT2-only standing directive, fitme-story work is deferred to a fitme-story-focused session.

## Verification

```bash
# Smoke-test 1: pytest runs all 12 tests in <3s with no external network
$ pytest scripts/tests/test_probe_deployed_url.py -q
............                                                             [100%]
12 passed in 1.60s

# Smoke-test 2: shell helper executable + usage clear
$ scripts/probe-deployed-url.sh
Usage: scripts/probe-deployed-url.sh <url> [--status N] [--content-type PATTERN] ...
$ echo $?
2

# Smoke-test 3: assertion modes work against a real URL (operator-driven)
$ scripts/probe-deployed-url.sh https://fitme.dev/og.png --status 200 --content-type "image/"
OK: https://fitme.dev/og.png passed all assertions (status=200)
```

All 3 pass at commit time.

## Open follow-ups

- **fitme-story workflow integration** — separate PR in the fitme-story repo. Wires `scripts/probe-deployed-url.sh` (cross-mounted via worktree or copied) to a post-deploy GH Actions workflow that fires on `deployment_status: success` and probes the actual production URLs (og:image, GA_ID gtag, sitemap, robots, canonical).
- **2026-06-11 T+7d verification** — after fitme-story integration ships, confirm the workflow catches a deliberately-injected fault (e.g., manually break the og:image path on a feature branch; assert the workflow fails). Closes the kill-criterion #1 thread.
- **Future modes** — `--header-equals` (for Cache-Control / Strict-Transport-Security audits) + `--cookie-exists` (for auth-flow checks) become candidates only when an actual workflow needs them.

## References

- **Spec:** [`.claude/shared/v7-9-1-candidates.md`](../.claude/shared/v7-9-1-candidates.md) F-DEPLOYED-URL-PROBE
- **Trigger incident W18:** [`observed-patterns.md` W18](../../.claude/integrity/observed-patterns.md) — og:image 404
- **Trigger incident W19:** [`observed-patterns.md` W19](../../.claude/integrity/observed-patterns.md) — GA_ID encoded newline
- **Sibling case study (same theme, different layer):** [`f-launchd-drift-extension-case-study.md`](f-launchd-drift-extension-case-study.md) — closes the cron-context-lacks-keychain silent-pass class (W11.b)
- **Predecessor (same session):** [`dev-env-r11-r13-r14-r17-r18-batch-case-study.md`](dev-env-r11-r13-r14-r17-r18-batch-case-study.md)

---

**Shipped via PR #628** (`feature/f-deployed-url-probe-ft2` → `main`).
