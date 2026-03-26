from typing import Literal
from pydantic import BaseModel


class NutritionSegmentRequest(BaseModel):
    caloric_balance_band: Literal[
        "deficit_large", "deficit_small", "maintenance", "surplus_small", "surplus_large"
    ]
    protein_adequacy_band: Literal["below_target", "at_target", "above_target"]
    meal_frequency_band: Literal["1-2", "3-4", "5+"]
    diet_pattern: Literal["standard", "vegetarian", "vegan", "keto", "other"]

    def to_cohort_fields(self) -> dict[str, str]:
        return self.model_dump()
