"""
InsightService: rule-based signal generation from cohort frequency data.
Produces population-level signals the iOS device uses to contextualise
its on-device Foundation Models personalisation layer.
LLM-based insight is gated behind LLM_API_KEY (unset by default; requires DPA).
"""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)

# Confidence thresholds for signal escalation decision
_HIGH_CONFIDENCE = 0.75
_LOW_CONFIDENCE  = 0.40


class InsightService:

    def generate(
        self,
        segment: str,
        user_fields: dict[str, str],
        cohort_totals: dict[str, int],
    ) -> dict[str, Any]:
        """Generate a rule-based insight dict for the given segment.
        Returns: {signals, confidence, escalate_to_llm, supporting_data}
        """
        signals: list[str] = []
        supporting_data: dict[str, Any] = {}

        total_cohort_size = sum(cohort_totals.values())
        populated_buckets = sum(1 for v in cohort_totals.values() if v > 0)
        coverage_ratio = populated_buckets / max(len(user_fields), 1)

        # ── Segment-specific rules ─────────────────────────────

        if segment == "training":
            signals.extend(self._training_signals(user_fields, cohort_totals))

        elif segment == "nutrition":
            signals.extend(self._nutrition_signals(user_fields, cohort_totals))

        elif segment == "recovery":
            signals.extend(self._recovery_signals(user_fields, cohort_totals))

        elif segment == "stats":
            signals.extend(self._stats_signals(user_fields, cohort_totals))

        # ── Confidence scoring ─────────────────────────────────
        # Coverage ratio × normalised cohort size signal
        cohort_signal = min(total_cohort_size / 5000.0, 1.0)  # saturates at 5 000
        confidence = round(coverage_ratio * 0.6 + cohort_signal * 0.4, 3)

        escalate_to_llm = confidence < _LOW_CONFIDENCE

        supporting_data = {
            "cohort_buckets": cohort_totals,
            "coverage_ratio": coverage_ratio,
            "total_cohort_size": total_cohort_size,
        }

        return {
            "signals":         signals,
            "confidence":      confidence,
            "escalate_to_llm": escalate_to_llm,
            "supporting_data": supporting_data,
        }

    # ── Private rule helpers ───────────────────────────────────

    def _training_signals(
        self, fields: dict[str, str], totals: dict[str, int]
    ) -> list[str]:
        signals: list[str] = []

        goal = fields.get("primary_goal", "")
        phase = fields.get("program_phase", "")
        days_band = fields.get("training_days_week_band", "")

        if goal == "muscle_gain" and phase == "foundation":
            signals.append("cohort_muscle_gain_foundation_common")
        if goal == "weight_loss" and days_band == "1-2":
            signals.append("cohort_weight_loss_low_frequency_suboptimal")
        if goal == "muscle_gain" and phase == "build":
            signals.append("cohort_build_phase_volume_emphasis")

        return signals

    def _nutrition_signals(
        self, fields: dict[str, str], totals: dict[str, int]
    ) -> list[str]:
        signals: list[str] = []

        balance = fields.get("caloric_balance_band", "")
        protein = fields.get("protein_adequacy_band", "")

        if protein == "below_target":
            signals.append("cohort_protein_below_target_common")
        if balance == "deficit_large":
            signals.append("cohort_large_deficit_muscle_risk")
        if balance in ("surplus_small", "surplus_large") and protein == "at_target":
            signals.append("cohort_surplus_adequate_protein_optimal")

        return signals

    def _recovery_signals(
        self, fields: dict[str, str], totals: dict[str, int]
    ) -> list[str]:
        signals: list[str] = []

        sleep = fields.get("sleep_duration_band", "")
        quality = fields.get("sleep_quality_band", "")
        stress = fields.get("stress_level_band", "")

        if sleep == "under_6":
            signals.append("cohort_sleep_deprivation_recovery_impaired")
        if quality == "poor" and stress == "high":
            signals.append("cohort_high_stress_poor_sleep_deload_advised")
        if sleep in ("7-8", "8+") and quality == "good":
            signals.append("cohort_optimal_sleep_recovery_profile")

        return signals

    def _stats_signals(
        self, fields: dict[str, str], totals: dict[str, int]
    ) -> list[str]:
        signals: list[str] = []

        consistency = fields.get("workout_consistency_band", "")
        sessions = fields.get("weekly_sessions_band", "")
        steps = fields.get("steps_daily_band", "")

        if consistency == "low":
            signals.append("cohort_low_consistency_adherence_risk")
        if steps == "under_5000" and sessions in ("0-1", "2-3"):
            signals.append("cohort_low_activity_overall")
        if consistency == "high" and sessions == "6+":
            signals.append("cohort_high_volume_overtraining_risk")

        return signals
