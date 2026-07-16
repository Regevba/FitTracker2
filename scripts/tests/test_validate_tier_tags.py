"""Tests for scripts/validate-tier-tags.py.

Extracts T1/T2/T3-tagged quantitative claims from case studies. T1 claims
are cross-referenced against ledger numbers (measurement-adoption.json,
documentation-debt.json) within 5% relative tolerance. T2/T3 claims pass
through (T2 = declared, T3 = narrative — neither requires ledger evidence).

Pre-2026-04-21 case studies are exempt (tier-tag convention introduced
on that date).
"""
import json
import subprocess
from pathlib import Path
from typing import Optional

VALIDATOR = Path(__file__).parent.parent / "validate-tier-tags.py"


def run_on_text(text: str, tmp_path: Path, ledger: Optional[dict] = None):
    cs = tmp_path / "case.md"
    cs.write_text(text)
    if ledger:
        (tmp_path / "ledger.json").write_text(json.dumps(ledger))
        ledger_arg = ["--ledger", str(tmp_path / "ledger.json")]
    else:
        ledger_arg = []
    return subprocess.run(
        ["python3", str(VALIDATOR), "--file", str(cs)] + ledger_arg,
        capture_output=True, text=True
    )


def test_valid_t1_claim_with_ledger_match_passes(tmp_path):
    text = """---
date_written: 2026-04-29
---
# Case
**T1**: post-v6 fully-adopted ratio is 22.2% per measurement-adoption ledger.
"""
    ledger = {"summary": {"fully_adopted_post_v6_percent": 22.2}}
    result = run_on_text(text, tmp_path, ledger)
    # Advisory: exit 0 either way. Check stdout for findings instead:
    assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout


def test_t1_claim_without_ledger_evidence_warns(tmp_path):
    # Use `x` (multiplier) — a word-char-ending unit the claim regex matches,
    # NOT one of the 2026-06-08 observed-measurement suppression classes
    # (durations / test ratios), so the warn-path still fires. The original
    # `999ms` example was retired because `ms` is a duration → now suppressed.
    text = """---
date_written: 2026-04-29
---
# Case
**T1**: peak throughput was 999x baseline — no ledger match.
"""
    result = run_on_text(text, tmp_path)
    assert "TIER_TAG_LIKELY_INCORRECT" in result.stdout


def test_observed_durations_and_test_ratios_suppressed(tmp_path):
    # 2026-06-08 filter: instrumented OBSERVATIONS (wall-time/latency durations
    # + X/Y test-pass ratios) are legitimately T1 but never ledger-match — must
    # NOT warn. These are the exact recurring FP shapes (3.5h, 1.60s, 49/49).
    for claim in (
        "**T1**: the suite ran in 1.60s — fast.",
        "**T1**: ~3.5h wall time for the whole session.",
        "**T1**: latency 0.857s per call.",
        "**T1**: 49/49 tests pass in the import suite.",
        "**T1**: 19/19 unit tests pass.",
    ):
        text = f"---\ndate_written: 2026-04-29\n---\n# Case\n{claim}\n"
        result = run_on_text(text, tmp_path)
        assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout, f"should suppress: {claim}"


def test_non_test_ratio_still_warns(tmp_path):
    # A bare X/Y ratio WITHOUT a test-context word (e.g. a sync/records ratio)
    # is NOT suppressed — keeps the filter from over-reaching. Controlled ledger
    # so the warn-path isn't masked by a coincidental real-ledger match.
    text = """---
date_written: 2026-04-29
---
# Case
**T1**: reconciled 73/91 records cleanly — no ledger match.
"""
    result = run_on_text(text, tmp_path, ledger={"unrelated": 1.0})
    assert "TIER_TAG_LIKELY_INCORRECT" in result.stdout


def test_commit_hash_digit_run_not_read_as_measurement(tmp_path):
    # Regression: the claim regex used to read "79d" out of the git short-hash
    # `05ef79d` in an "Ordered chain" citation as a spurious "79 days" T1 claim
    # (google-analytics-case-study.md). A digit-run embedded inside an
    # alphanumeric token (preceded by a word char) is not a measurement.
    text = """---
date_written: 2026-04-29
---
# Case
| PR / commits | Merge `ac85c73` [T1]. Ordered chain: `7b320bc`, `05ef79d`, `35d770a` |
"""
    result = run_on_text(text, tmp_path)
    assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout


def test_pre_cutoff_case_study_exempt(tmp_path):
    text = """---
date_written: 2026-04-15
---
# Case
**T1**: fake number 99% — instrumented.
"""
    result = run_on_text(text, tmp_path)
    # Pre-2026-04-21 → exempt
    assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout


def test_t3_narrative_claim_passes(tmp_path):
    """T3-tagged claims aren't ledger-verified — pass through."""
    text = """---
date_written: 2026-04-29
---
# Case
**T3**: roughly 6.5x speedup based on team observation.
"""
    result = run_on_text(text, tmp_path)
    assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout


def test_t2_declared_claim_passes(tmp_path):
    """T2-tagged claims aren't ledger-verified — pass through."""
    text = """---
date_written: 2026-04-29
---
# Case
**T2**: target post-v7.7 adoption 72.7%.
"""
    result = run_on_text(text, tmp_path)
    assert "TIER_TAG_LIKELY_INCORRECT" not in result.stdout
