from typing import Literal
from pydantic import BaseModel


class TrainingSegmentRequest(BaseModel):
    age_band: Literal["18-24", "25-34", "35-44", "45-54", "55+"]
    gender_band: Literal["male", "female", "prefer_not_to_say"]
    bmi_band: Literal["under_18.5", "18.5-24.9", "25-29.9", "30+"]
    active_weeks_band: Literal["0", "1-3", "4+"]
    program_phase: Literal["foundation", "build", "peak", "recovery"]
    training_days_week_band: Literal["1-2", "3-4", "5+"]
    avg_session_duration_band: Literal["under_30", "30-45", "46-60", "60+"]
    primary_goal: Literal["weight_loss", "muscle_gain", "endurance", "maintenance"]

    def to_cohort_fields(self) -> dict[str, str]:
        return self.model_dump()


class InsightResponse(BaseModel):
    segment: str
    signals: list[str]
    confidence: float
    escalate_to_llm: bool
    supporting_data: dict
