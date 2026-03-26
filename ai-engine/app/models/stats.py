from typing import Literal
from pydantic import BaseModel


class StatsSegmentRequest(BaseModel):
    weekly_sessions_band: Literal["0-1", "2-3", "4-5", "6+"]
    total_active_minutes_band: Literal["under_150", "150-300", "300-450", "450+"]
    steps_daily_band: Literal["under_5000", "5000-7500", "7500-10000", "10000+"]
    workout_consistency_band: Literal["low", "moderate", "high"]

    def to_cohort_fields(self) -> dict[str, str]:
        return self.model_dump()
