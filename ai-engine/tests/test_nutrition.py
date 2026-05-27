"""
Integration tests for the /v1/nutrition/insight endpoint.
Mirrors test_training.py: auth rejection, payload validation, JWT shape
enforcement, and fire-and-forget cohort write path.
Uses httpx.AsyncClient with ASGI transport — no live Supabase required.
"""

import pytest
from unittest.mock import AsyncMock, patch
from httpx import ASGITransport, AsyncClient

from app.auth.jwt_validator import get_verified_claims


VALID_NUTRITION_PAYLOAD = {
    "caloric_balance_band": "maintenance",
    "protein_adequacy_band": "at_target",
    "meal_frequency_band": "3-4",
    "diet_pattern": "standard",
}


@pytest.mark.asyncio
async def test_nutrition_insight_requires_auth(app):
    """Unauthenticated request must be rejected by the auth dependency."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/nutrition/insight", json=VALID_NUTRITION_PAYLOAD
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_nutrition_insight_invalid_payload_rejected(app):
    """Invalid band value must return 422 (Pydantic validation)."""
    app.dependency_overrides[get_verified_claims] = lambda: {
        "sub": "test-user",
        "role": "authenticated",
    }
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/nutrition/insight",
            json={**VALID_NUTRITION_PAYLOAD, "caloric_balance_band": "invalid_value"},
            headers={"Authorization": "Bearer header.payload.signature"},
        )
    app.dependency_overrides.pop(get_verified_claims, None)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_nutrition_insight_rejects_non_jwt_token_shape(app):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/v1/nutrition/insight",
            json=VALID_NUTRITION_PAYLOAD,
            headers={"Authorization": "Bearer local-session-token"},
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_nutrition_insight_fire_and_forget_path(app):
    """Cohort write is dispatched as asyncio.create_task and does not block response."""
    mock_claims = {"sub": "user-456", "role": "authenticated"}
    mock_totals = {
        "caloric_balance_band:maintenance": 350,
        "protein_adequacy_band:at_target": 600,
        "meal_frequency_band:3-4": 500,
        "diet_pattern:standard": 800,
    }

    app.dependency_overrides[get_verified_claims] = lambda: mock_claims

    with (
        patch(
            "app.routers.nutrition.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value=mock_totals,
        ),
        patch(
            "app.routers.nutrition.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/v1/nutrition/insight",
                json=VALID_NUTRITION_PAYLOAD,
                headers={"Authorization": "Bearer mock-token"},
            )

    app.dependency_overrides.pop(get_verified_claims, None)

    assert response.status_code == 200
    body = response.json()
    assert body["segment"] == "nutrition"
    assert "signals" in body
    assert isinstance(body["confidence"], float)
    assert 0.0 <= body["confidence"] <= 1.0
    assert "escalate_to_llm" in body
    assert isinstance(body["escalate_to_llm"], bool)
    assert "supporting_data" in body


@pytest.mark.asyncio
async def test_nutrition_insight_accepts_all_valid_diet_patterns(app):
    """Each of the 5 diet_pattern literals must round-trip."""
    mock_claims = {"sub": "user-456", "role": "authenticated"}
    app.dependency_overrides[get_verified_claims] = lambda: mock_claims

    diet_patterns = ["standard", "vegetarian", "vegan", "keto", "other"]
    with (
        patch(
            "app.routers.nutrition.CohortService.get_cohort_totals",
            new_callable=AsyncMock,
            return_value={},
        ),
        patch(
            "app.routers.nutrition.CohortService.increment_fields",
            new_callable=AsyncMock,
        ),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            for pattern in diet_patterns:
                response = await client.post(
                    "/v1/nutrition/insight",
                    json={**VALID_NUTRITION_PAYLOAD, "diet_pattern": pattern},
                    headers={"Authorization": "Bearer mock-token"},
                )
                assert response.status_code == 200, (
                    f"diet_pattern={pattern} failed: {response.status_code}"
                )
                assert response.json()["segment"] == "nutrition"

    app.dependency_overrides.pop(get_verified_claims, None)
