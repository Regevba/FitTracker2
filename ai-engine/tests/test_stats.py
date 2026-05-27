"""
Integration tests for the /v1/stats/insight endpoint.
Mirrors test_training.py: auth rejection, payload validation, JWT shape
enforcement, and fire-and-forget cohort write path.
Uses httpx.AsyncClient with ASGI transport — no live Supabase required.
"""

import pytest
from unittest.mock import AsyncMock, patch
from httpx import ASGITransport, AsyncClient

from app.auth.jwt_validator import get_verified_claims


VALID_STATS_PAYLOAD = {
    "weekly_sessions_band": "4-5",
    "total_active_minutes_band": "150-300",
    "steps_daily_band": "7500-10000",
    "workout_consistency_band": "high",
}


@pytest.mark.asyncio
async def test_stats_insight_requires_auth(app):
    """Unauthenticated request must be rejected by the auth dependency."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post("/v1/stats/insight", json=VALID_STATS_PAYLOAD)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_stats_insight_invalid_payload_rejected(app):
    """Invalid band value must return 422 (Pydantic validation)."""
    app.dependency_overrides[get_verified_claims] = lambda: {
        "sub": "test-user",
        "role": "authenticated",
    }
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/stats/insight",
            json={**VALID_STATS_PAYLOAD, "weekly_sessions_band": "invalid_value"},
            headers={"Authorization": "Bearer header.payload.signature"},
        )
    app.dependency_overrides.pop(get_verified_claims, None)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_stats_insight_rejects_non_jwt_token_shape(app):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/stats/insight",
            json=VALID_STATS_PAYLOAD,
            headers={"Authorization": "Bearer local-session-token"},
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_stats_insight_fire_and_forget_path(app):
    """Cohort write is dispatched as asyncio.create_task and does not block response."""
    mock_claims = {"sub": "user-101", "role": "authenticated"}
    mock_totals = {
        "weekly_sessions_band:4-5": 400,
        "total_active_minutes_band:150-300": 600,
        "steps_daily_band:7500-10000": 700,
        "workout_consistency_band:high": 500,
    }

    app.dependency_overrides[get_verified_claims] = lambda: mock_claims

    with (
        patch(
            "app.routers.stats.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value=mock_totals,
        ),
        patch(
            "app.routers.stats.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/v1/stats/insight",
                json=VALID_STATS_PAYLOAD,
                headers={"Authorization": "Bearer mock-token"},
            )

    app.dependency_overrides.pop(get_verified_claims, None)

    assert response.status_code == 200
    body = response.json()
    assert body["segment"] == "stats"
    assert "signals" in body
    assert isinstance(body["confidence"], float)
    assert 0.0 <= body["confidence"] <= 1.0
    assert "escalate_to_llm" in body
    assert isinstance(body["escalate_to_llm"], bool)
    assert "supporting_data" in body


@pytest.mark.asyncio
async def test_stats_insight_accepts_all_valid_consistency_bands(app):
    """Each of the 3 workout_consistency_band literals must round-trip."""
    mock_claims = {"sub": "user-101", "role": "authenticated"}
    app.dependency_overrides[get_verified_claims] = lambda: mock_claims

    consistency_bands = ["low", "moderate", "high"]
    with (
        patch(
            "app.routers.stats.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value={},
        ),
        patch(
            "app.routers.stats.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            for band in consistency_bands:
                response = await client.post(
                    "/v1/stats/insight",
                    json={**VALID_STATS_PAYLOAD, "workout_consistency_band": band},
                    headers={"Authorization": "Bearer mock-token"},
                )
                assert response.status_code == 200, (
                    f"workout_consistency_band={band} failed: {response.status_code}"
                )
                assert response.json()["segment"] == "stats"

    app.dependency_overrides.pop(get_verified_claims, None)
