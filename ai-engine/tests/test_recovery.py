"""
Integration tests for the /v1/recovery/insight endpoint.
Mirrors test_training.py: auth rejection, payload validation, JWT shape
enforcement, and fire-and-forget cohort write path.
Uses httpx.AsyncClient with ASGI transport — no live Supabase required.
"""

import pytest
from unittest.mock import AsyncMock, patch
from httpx import ASGITransport, AsyncClient

from app.auth.jwt_validator import get_verified_claims


VALID_RECOVERY_PAYLOAD = {
    "sleep_duration_band": "7-8",
    "sleep_quality_band": "good",
    "resting_hr_band": "60-70",
    "stress_level_band": "low",
}


@pytest.mark.asyncio
async def test_recovery_insight_requires_auth(app):
    """Unauthenticated request must be rejected by the auth dependency."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/recovery/insight", json=VALID_RECOVERY_PAYLOAD
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_recovery_insight_invalid_payload_rejected(app):
    """Invalid band value must return 422 (Pydantic validation)."""
    app.dependency_overrides[get_verified_claims] = lambda: {
        "sub": "test-user",
        "role": "authenticated",
    }
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/recovery/insight",
            json={**VALID_RECOVERY_PAYLOAD, "sleep_duration_band": "invalid_value"},
            headers={"Authorization": "Bearer header.payload.signature"},
        )
    app.dependency_overrides.pop(get_verified_claims, None)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_recovery_insight_rejects_non_jwt_token_shape(app):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/recovery/insight",
            json=VALID_RECOVERY_PAYLOAD,
            headers={"Authorization": "Bearer local-session-token"},
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_recovery_insight_fire_and_forget_path(app):
    """Cohort write is dispatched as asyncio.create_task and does not block response."""
    mock_claims = {"sub": "user-789", "role": "authenticated"}
    mock_totals = {
        "sleep_duration_band:7-8": 450,
        "sleep_quality_band:good": 700,
        "resting_hr_band:60-70": 600,
        "stress_level_band:low": 550,
    }

    app.dependency_overrides[get_verified_claims] = lambda: mock_claims

    with (
        patch(
            "app.routers.recovery.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value=mock_totals,
        ),
        patch(
            "app.routers.recovery.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/v1/recovery/insight",
                json=VALID_RECOVERY_PAYLOAD,
                headers={"Authorization": "Bearer mock-token"},
            )

    app.dependency_overrides.pop(get_verified_claims, None)

    assert response.status_code == 200
    body = response.json()
    assert body["segment"] == "recovery"
    assert "signals" in body
    assert isinstance(body["confidence"], float)
    assert 0.0 <= body["confidence"] <= 1.0
    assert "escalate_to_llm" in body
    assert isinstance(body["escalate_to_llm"], bool)
    assert "supporting_data" in body


@pytest.mark.asyncio
async def test_recovery_insight_accepts_all_valid_stress_levels(app):
    """Each of the 3 stress_level_band literals must round-trip."""
    mock_claims = {"sub": "user-789", "role": "authenticated"}
    app.dependency_overrides[get_verified_claims] = lambda: mock_claims

    stress_levels = ["low", "moderate", "high"]
    with (
        patch(
            "app.routers.recovery.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value={},
        ),
        patch(
            "app.routers.recovery.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            for level in stress_levels:
                response = await client.post(
                    "/v1/recovery/insight",
                    json={**VALID_RECOVERY_PAYLOAD, "stress_level_band": level},
                    headers={"Authorization": "Bearer mock-token"},
                )
                assert response.status_code == 200, (
                    f"stress_level={level} failed: {response.status_code}"
                )
                assert response.json()["segment"] == "recovery"

    app.dependency_overrides.pop(get_verified_claims, None)
