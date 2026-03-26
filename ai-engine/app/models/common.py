from pydantic import BaseModel


class InsightResponse(BaseModel):
    segment: str
    signals: list[str]
    confidence: float
    escalate_to_llm: bool
    supporting_data: dict
