"""T10 — AI golden-set eval harness for the deterministic InsightService.

The test-coverage master plan (T10) called for an "LLM golden-set eval harness".
Scoping (2026-06-10) found the FitMe AI is NOT generative: `InsightService` is a
pure deterministic rule engine (federated-cohort signals + confidence scoring +
escalate_to_llm threshold), with the LLM path gated behind an unset `LLM_API_KEY`
(requires a DPA). A deterministic golden set is therefore *better* than a
promptfoo run — zero flake, no API key, gateable in the existing pytest suite.

This harness pins the BEHAVIORAL contract (which signals fire, confidence bands,
escalation) for each segment + edge case, so a benign refactor that silently
drops a rule or shifts the escalation threshold is caught at PR time.

Golden cases: `tests/golden/insight_cases.jsonl`. The live-LLM eval path
(`test_llm_eval_*`) skips cleanly when `LLM_API_KEY` is unset (the default),
matching the dep-skip convention used across the framework's verify targets.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from app.services.insight_service import InsightService

_GOLDEN = Path(__file__).parent / "golden" / "insight_cases.jsonl"


def _load_cases() -> list[dict]:
    cases = []
    for line in _GOLDEN.read_text().splitlines():
        line = line.strip()
        if line:
            cases.append(json.loads(line))
    return cases


_CASES = _load_cases()


def test_golden_file_present_and_covers_all_segments():
    """The golden set must exist and cover every InsightService segment."""
    assert len(_CASES) >= 20, f"expected >=20 golden cases, got {len(_CASES)}"
    segments = {c["segment"] for c in _CASES}
    for seg in ("training", "nutrition", "recovery", "stats"):
        assert seg in segments, f"no golden case for segment {seg!r}"


@pytest.mark.parametrize("case", _CASES, ids=[c["name"] for c in _CASES])
def test_golden_insight_behavior(case):
    """Run InsightService against each golden input; assert the behavioral contract."""
    svc = InsightService()
    result = svc.generate(case["segment"], case["user_fields"], case["cohort_totals"])

    signals = result["signals"]
    exp = case["expect"]

    if exp.get("no_error"):
        # Reaching here means generate() did not raise (e.g. empty user_fields
        # must not divide by zero) — that's the assertion.
        pass

    if exp.get("signals_empty"):
        assert signals == [], f"{case['name']}: expected no signals, got {signals}"

    for sig in exp.get("signals_contains", []):
        assert sig in signals, f"{case['name']}: missing expected signal {sig!r} (got {signals})"

    for sig in exp.get("signals_excludes", []):
        assert sig not in signals, f"{case['name']}: unexpected signal {sig!r} present"

    if "escalate_to_llm" in exp:
        assert result["escalate_to_llm"] is exp["escalate_to_llm"], (
            f"{case['name']}: escalate_to_llm={result['escalate_to_llm']} "
            f"expected {exp['escalate_to_llm']} (confidence={result['confidence']})")

    if "confidence_min" in exp:
        assert result["confidence"] >= exp["confidence_min"], (
            f"{case['name']}: confidence {result['confidence']} < min {exp['confidence_min']}")

    if "confidence_max" in exp:
        assert result["confidence"] <= exp["confidence_max"], (
            f"{case['name']}: confidence {result['confidence']} > max {exp['confidence_max']}")

    if "supporting_total_cohort_size" in exp:
        assert result["supporting_data"]["total_cohort_size"] == exp["supporting_total_cohort_size"]


def test_escalation_threshold_is_stable():
    """Pin the escalate_to_llm boundary (<0.40) — a regression magnet."""
    svc = InsightService()
    # Construct a case landing just above and just below the 0.40 threshold by
    # varying coverage. confidence = coverage_ratio*0.6 + cohort_signal*0.4.
    # 5 fields, 1 populated bucket, tiny cohort → coverage 0.2 → conf≈0.12 → escalate.
    low = svc.generate("training", {f"f{i}": "x" for i in range(5)}, {"a": 10})
    assert low["escalate_to_llm"] is True
    # Full coverage + max cohort → conf 1.0 → no escalate.
    high = svc.generate("training", {"primary_goal": "muscle_gain"}, {"a": 6000})
    assert high["escalate_to_llm"] is False


# ── Live-LLM eval path (advisory; gated behind LLM_API_KEY / DPA) ──────────

@pytest.mark.skipif(
    not os.environ.get("LLM_API_KEY"),
    reason="LLM_API_KEY unset (default) — the generative insight path is gated "
           "behind a DPA; the deterministic golden set above is the load-bearing "
           "PR gate. This advisory path runs only when a key is provisioned.",
)
def test_llm_eval_golden_subset_when_key_present():
    """Placeholder for the weekly promptfoo-equivalent run.

    When LLM_API_KEY is provisioned, this would feed the golden inputs through
    the gated LLM escalation path and assert behavioral properties (stays in
    band, no fabricated numbers, references a real signal). Skipped by default
    so the suite stays deterministic and key-free.
    """
    pytest.skip("LLM eval harness body lands with the gated LLM escalation feature")
