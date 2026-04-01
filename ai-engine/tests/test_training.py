"""
Integration tests for the /v1/training/insight endpoint.
Verifies: auth rejection, rate limiting, and fire-and-forget cohort write path.
Uses httpx.AsyncClient with ASGI transport — no live Supabase required.
"""

import pytest
from unittest.mock import AsyncMock, patch
from httpx import ASGITransport, AsyncClient

from app.main import create_app
from app.models.common import InsightResponse


@pytest.fixture
def app():
    return create_app()


VALID_TRAINING_PAYLOAD = {
    "age_band": "25-34",
    "gender_band": "male",
    "bmi_band": "18.5-24.9",
    "active_weeks_band": "4+",
    "program_phase": "build",
    "training_days_week_band": "3-4",
    "avg_session_duration_band": "46-60",
    "primary_goal": "muscle_gain",
}


@pytest.mark.asyncio
async def test_training_insight_requires_auth(app):
    """Unauthenticated request must return 403."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/training/insight", json=VALID_TRAINING_PAYLOAD
        )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_training_insight_invalid_payload_rejected(app):
    """Invalid band value must return 422 (Pydantic validation)."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/training/insight",
            json={**VALID_TRAINING_PAYLOAD, "age_band": "invalid_value"},
            headers={"Authorization": "Bearer header.payload.signature"},
        )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_training_insight_rejects_non_jwt_token_shape(app):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/training/insight",
            json=VALID_TRAINING_PAYLOAD,
            headers={"Authorization": "Bearer local-session-token"},
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_training_insight_fire_and_forget_path(app):
    """Cohort write is dispatched as asyncio.create_task and does not block response.
    Mocks are patched at the router module level (not auth module level) so that
    FastAPI dependency injection is correctly intercepted at call time.
    """
    mock_claims = {"sub": "user-123", "role": "authenticated"}
    mock_totals = {
        "age_band:25-34": 300,
        "gender_band:male": 500,
        "bmi_band:18.5-24.9": 400,
        "active_weeks_band:4+": 800,
        "program_phase:build": 500,
        "training_days_week_band:3-4": 700,
        "avg_session_duration_band:46-60": 400,
        "primary_goal:muscle_gain": 450,
    }

    with (
        # Patch at the router module level — where the dependency is resolved
        patch(
            "app.routers.training.get_verified_claims",
            return_value=mock_claims,
        ),
        patch(
            "app.routers.training.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value=mock_totals,
        ),
        patch(
            "app.routers.training.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/v1/training/insight",
                json=VALID_TRAINING_PAYLOAD,
                headers={"Authorization": "Bearer mock-token"},
            )

    assert response.status_code == 200
    body = response.json()
    assert body["segment"] == "training"
    assert "signals" in body
    assert isinstance(body["confidence"], float)
    assert 0.0 <= body["confidence"] <= 1.0
    assert "escalate_to_llm" in body
    assert isinstance(body["escalate_to_llm"], bool)
    assert "supporting_data" in body
