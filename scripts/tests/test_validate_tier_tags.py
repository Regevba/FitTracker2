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
    text = """---
date_written: 2026-04-29
---
# Case
**T1**: cache_hits is at 999% — totally instrumented.
"""
    result = run_on_text(text, tmp_path)
    assert "TIER_TAG_LIKELY_INCORRECT" in result.stdout


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
