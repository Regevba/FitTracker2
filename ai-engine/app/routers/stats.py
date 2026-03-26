import asyncio
import logging

from fastapi import APIRouter, Depends

from app.auth.jwt_validator import get_verified_claims
from app.config import Settings, get_settings
from app.middleware.rate_limiter import make_rate_limit_dependency
from app.models.common import InsightResponse
from app.models.stats import StatsSegmentRequest
from app.services.cohort_service import CohortService
from app.services.insight_service import InsightService

logger = logging.getLogger(__name__)
router = APIRouter()

_rate_limit = make_rate_limit_dependency("stats")


@router.post("/insight", response_model=InsightResponse)
async def stats_insight(
    body: StatsSegmentRequest,
    _claims: dict = Depends(get_verified_claims),
    _rate: None = Depends(_rate_limit),
    settings: Settings = Depends(get_settings),
) -> InsightResponse:
    fields = body.to_cohort_fields()
    cohort = CohortService(settings)

    asyncio.create_task(cohort.increment_fields("stats", fields))

    totals = await cohort.get_cohort_totals("stats", fields)
    insight = InsightService().generate("stats", fields, totals)

    return InsightResponse(segment="stats", **insight)
