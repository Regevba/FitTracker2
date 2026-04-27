"""Tests for scripts/validate-cu-v2.py.

The validator checks state.json's cu_v2 field for:
- factors dict with all 4 expected keys (complexity, blast_radius, novelty, verification_difficulty)
- each factor numeric and in [0, 1]
- total field numeric and within tolerance of sum(factors.values())
- tier_class field is one of A_high, B_medium, C_low

Pre-v6 features without cu_v2 are exempt.
"""
import json
import subprocess
from pathlib import Path

VALIDATOR = Path(__file__).parent.parent / "validate-cu-v2.py"


def run_validator(state_dict, tmp_path):
    state_path = tmp_path / "state.json"
    state_path.write_text(json.dumps(state_dict))
    return subprocess.run(
        ["python3", str(VALIDATOR), "--state", str(state_path)],
        capture_output=True, text=True
    )


def test_valid_cu_v2_passes(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5,
                "blast_radius": 0.5,
                "novelty": 0.5,
                "verification_difficulty": 0.5
            },
            "total": 2.0,
            "tier_class": "B_medium"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode == 0, f"stdout={result.stdout} stderr={result.stderr}"


def test_missing_factor_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5,
                "blast_radius": 0.5,
                "novelty": 0.5
                # verification_difficulty missing
            },
            "total": 1.5,
            "tier_class": "C_low"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "CU_V2_INVALID" in result.stdout
    assert "verification_difficulty" in result.stdout


def test_factor_out_of_range_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 1.5,  # > 1
                "blast_radius": 0.5,
                "novelty": 0.5,
                "verification_difficulty": 0.5
            },
            "total": 3.0,
            "tier_class": "A_high"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "CU_V2_INVALID" in result.stdout


def test_total_mismatch_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5, "blast_radius": 0.5,
                "novelty": 0.5, "verification_difficulty": 0.5
            },
            "total": 99.0,  # should be 2.0
            "tier_class": "B_medium"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "CU_V2_INVALID" in result.stdout


def test_state_without_cu_v2_passes(tmp_path):
    """Pre-v6 features without cu_v2 are exempt."""
    state = {"feature_name": "pre-v6"}
    result = run_validator(state, tmp_path)
    assert result.returncode == 0


def test_invalid_tier_class_fails(tmp_path):
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5, "blast_radius": 0.5,
                "novelty": 0.5, "verification_difficulty": 0.5
            },
            "total": 2.0,
            "tier_class": "X_unknown"
        }
    }
    result = run_validator(state, tmp_path)
    assert result.returncode != 0
    assert "tier_class" in result.stdout
