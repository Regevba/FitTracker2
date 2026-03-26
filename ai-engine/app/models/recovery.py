from typing import Literal
from pydantic import BaseModel


class RecoverySegmentRequest(BaseModel):
    sleep_duration_band: Literal["under_6", "6-7", "7-8", "8+"]
    sleep_quality_band: Literal["poor", "fair", "good"]
    resting_hr_band: Literal["under_60", "60-70", "71-80", "81+"]
    stress_level_band: Literal["low", "moderate", "high"]

    def to_cohort_fields(self) -> dict[str, str]:
        return self.model_dump()
