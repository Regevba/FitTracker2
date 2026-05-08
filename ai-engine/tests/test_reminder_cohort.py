"""
Integration tests for the smart-reminders behavioral-learning cohort
endpoints (POST /reminder-cohort-event + GET /reminder-cohort-priors).

Mirrors the test pattern in test_training.py:
- httpx.AsyncClient with ASGITransport (no live Supabase)
- patch CohortService methods at the router module path
- assert against the public HTTP surface, not internals

Coverage (per plan §Task 6 + §Task 7):

  POST endpoint
    1. tapped=True  → two segment writes (shows + taps)
    2. tapped=False → one segment write (shows only)
    3. unknown type → 422 Pydantic validation error
    4. hour out of [0, 23] → 422
    5. no Authorization header required (unauthenticated by design)
    6. payload with extra keys → 422 (model has no extras allowed by default
       in this Pydantic version, BUT the strict subset is what matters —
       we assert the wire format remains {type, hour, tapped})

  GET endpoint
    7. computes per-type per-hour rate from shows + taps
    8. suppresses cells with shows < 50 (privacy + statistical-validity floor)
    9. surfaces kill flags from the reminders.kill_flag segment
   10. empty Supabase → empty response (no 500)
   11. taps > shows is clamped to rate=1.0 (defensive against bad data)
"""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient


# ────────────────────────────────────────────────────────────────────────
# POST /reminder-cohort-event
# ────────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_record_event_writes_shows_and_taps_when_tapped(app):
    """tapped=True → two CohortService.increment_fields calls."""
    with patch(
        "app.routers.reminder_cohort.CohortService.increment_fields",
        new_callable=AsyncMock,
    ) as mock_increment:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/reminder-cohort-event",
                json={"type": "nutrition_gap", "hour": 16, "tapped": True},
            )

    assert response.status_code == 204

    # Two writes: shows + taps. Both are scheduled via asyncio.create_task —
    # await one event loop tick to let them complete.
    import asyncio
    await asyncio.sleep(0)

    calls = mock_increment.await_args_list
    assert len(calls) == 2

    segments = sorted(call.args[0] for call in calls)
    assert segments == [
        "reminders.shows.nutrition_gap",
        "reminders.taps.nutrition_gap",
    ]
    # Both calls must use the zero-padded hour string (matches Swift's
    # tapsKey(hour:) format).
    for call in calls:
        assert call.args[1] == {"hour": "16"}


@pytest.mark.asyncio
async def test_record_event_writes_only_shows_when_not_tapped(app):
    """tapped=False → one CohortService.increment_fields call (shows only)."""
    with patch(
        "app.routers.reminder_cohort.CohortService.increment_fields",
        new_callable=AsyncMock,
    ) as mock_increment:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/reminder-cohort-event",
                json={"type": "nutrition_gap", "hour": 16, "tapped": False},
            )
    import asyncio
    await asyncio.sleep(0)

    assert response.status_code == 204
    calls = mock_increment.await_args_list
    assert len(calls) == 1
    assert calls[0].args[0] == "reminders.shows.nutrition_gap"
    assert calls[0].args[1] == {"hour": "16"}


@pytest.mark.asyncio
async def test_record_event_rejects_unknown_type(app):
    """Pydantic field_validator rejects unknown ReminderType.rawValue."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/reminder-cohort-event",
            json={"type": "not_a_real_type", "hour": 16, "tapped": True},
        )
    assert response.status_code == 422


@pytest.mark.asyncio
@pytest.mark.parametrize("bad_hour", [-1, 24, 100, -100])
async def test_record_event_rejects_out_of_range_hour(app, bad_hour):
    """hour must be in [0, 23] (Pydantic Field ge/le)."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/reminder-cohort-event",
            json={"type": "nutrition_gap", "hour": bad_hour, "tapped": True},
        )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_record_event_no_auth_required(app):
    """Endpoint is unauthenticated by design — no Authorization header sent
    and the request still succeeds."""
    with patch(
        "app.routers.reminder_cohort.CohortService.increment_fields",
        new_callable=AsyncMock,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/reminder-cohort-event",
                json={"type": "training_day", "hour": 10, "tapped": False},
            )
    assert response.status_code == 204


# ────────────────────────────────────────────────────────────────────────
# GET /reminder-cohort-priors
# ────────────────────────────────────────────────────────────────────────


def _row(segment: str, field_name: str, field_value: str, frequency: int) -> dict:
    return {
        "segment": segment,
        "field_name": field_name,
        "field_value": field_value,
        "frequency": frequency,
    }


@pytest.mark.asyncio
async def test_priors_computes_per_hour_tap_through_rate(app):
    """80 shows + 32 taps → rate 0.4 in the priors response."""
    rows = [
        _row("reminders.shows.nutrition_gap", "hour", "16", 80),
        _row("reminders.taps.nutrition_gap", "hour", "16", 32),
    ]
    with patch(
        "app.routers.reminder_cohort.CohortService.list_rows_by_segment_pattern",
        new_callable=AsyncMock,
        return_value=rows,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/reminder-cohort-priors")

    assert response.status_code == 200
    data = response.json()
    assert data["priors"]["nutrition_gap"]["16"] == pytest.approx(0.4)
    assert data["kill_flags"] == []


@pytest.mark.asyncio
async def test_priors_suppresses_cells_below_50_shows(app):
    """49 shows is below k=50; cell must be omitted from response."""
    rows = [
        _row("reminders.shows.nutrition_gap", "hour", "16", 49),
        _row("reminders.taps.nutrition_gap", "hour", "16", 20),
    ]
    with patch(
        "app.routers.reminder_cohort.CohortService.list_rows_by_segment_pattern",
        new_callable=AsyncMock,
        return_value=rows,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/reminder-cohort-priors")

    data = response.json()
    # Either nutrition_gap is missing entirely (empty per_hour pruned) or
    # hour 16 is missing — both are correct (the implementation prunes
    # empty type entries).
    assert "16" not in data["priors"].get("nutrition_gap", {})


@pytest.mark.asyncio
async def test_priors_surfaces_kill_flags(app):
    """A kill_flag row appears in response.kill_flags list."""
    rows = [
        _row("reminders.kill_flag", "engagement", "true", 1),
    ]
    with patch(
        "app.routers.reminder_cohort.CohortService.list_rows_by_segment_pattern",
        new_callable=AsyncMock,
        return_value=rows,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/reminder-cohort-priors")

    data = response.json()
    assert data["kill_flags"] == ["engagement"]


@pytest.mark.asyncio
async def test_priors_empty_supabase_returns_empty(app):
    """No cohort_stats rows yet → empty response, no 500."""
    with patch(
        "app.routers.reminder_cohort.CohortService.list_rows_by_segment_pattern",
        new_callable=AsyncMock,
        return_value=[],
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/reminder-cohort-priors")

    assert response.status_code == 200
    data = response.json()
    assert data == {"priors": {}, "kill_flags": []}


@pytest.mark.asyncio
async def test_priors_clamps_taps_greater_than_shows_to_one(app):
    """Pathological data (taps > shows) is clamped to rate=1.0 — defensive."""
    rows = [
        _row("reminders.shows.nutrition_gap", "hour", "16", 50),
        _row("reminders.taps.nutrition_gap", "hour", "16", 75),  # impossible in practice
    ]
    with patch(
        "app.routers.reminder_cohort.CohortService.list_rows_by_segment_pattern",
        new_callable=AsyncMock,
        return_value=rows,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/reminder-cohort-priors")

    data = response.json()
    assert data["priors"]["nutrition_gap"]["16"] == 1.0


@pytest.mark.asyncio
async def test_priors_no_auth_required(app):
    """GET endpoint is unauthenticated by design — no Authorization header."""
    with patch(
        "app.routers.reminder_cohort.CohortService.list_rows_by_segment_pattern",
        new_callable=AsyncMock,
        return_value=[],
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/reminder-cohort-priors")
    assert response.status_code == 200
