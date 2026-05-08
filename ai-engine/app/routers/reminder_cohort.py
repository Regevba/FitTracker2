"""
Smart-reminders behavioral-learning cohort endpoints.

Two endpoints, both unauthenticated by design (per spec §6 GDPR posture):
- POST /reminder-cohort-event   — fire-and-forget anonymised observation
- GET  /reminder-cohort-priors  — per-type per-hour tap-through priors

Payload contains ONLY {type, hour, tapped}. No userId / deviceId / locale
ever leaves the device or persists to Supabase.

PR-1 backend half — companion to FT2 PR #190 (iOS data layer). Reuses the
existing cohort_stats table + increment_cohort_frequency RPC; adds three
new segment names: reminders.shows.<type>, reminders.taps.<type>,
reminders.kill_flag.

Read path applies a privacy threshold (k=50) — cells with shows < 50 are
suppressed. This is *both* a privacy floor AND a statistical-validity
floor (40% rate observed on 5 shows is noise; on 50 shows it's signal).
"""

import asyncio
import logging
from typing import Annotated

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field, field_validator

from app.config import Settings, get_settings
from app.services.cohort_service import CohortService

logger = logging.getLogger(__name__)
router = APIRouter()

# Privacy + statistical-validity floor for the read endpoint. Cells with
# fewer than this many shows are suppressed in the response. Matches the
# k=50 anonymity floor used by migration 000004.
PRIVACY_THRESHOLD = 50


# ────────────────────────────────────────────────────────────────────────
# Allowlist — keep in sync with FitTracker/Services/Reminders/ReminderType.swift
# ────────────────────────────────────────────────────────────────────────

ALLOWED_REMINDER_TYPES = frozenset({
    "nutrition_gap",
    "training_day",
    "rest_day",
    "healthkit_connect",
    "account_registration",
    "engagement",
})


# ────────────────────────────────────────────────────────────────────────
# Request / response models
# ────────────────────────────────────────────────────────────────────────

class CohortEvent(BaseModel):
    """Wire-format for POST /reminder-cohort-event. Only these three keys
    are accepted — the iOS client (FitTracker/Services/Reminders/
    CohortPriorClient.swift) asserts the payload key set on every send.
    """
    type: str = Field(..., description="ReminderType.rawValue, e.g. 'nutrition_gap'")
    hour: int = Field(..., ge=0, le=23, description="Hour of day, 0-23, local time")
    tapped: bool = Field(..., description="Whether the user tapped the notification")

    @field_validator("type")
    @classmethod
    def type_must_be_known(cls, v: str) -> str:
        if v not in ALLOWED_REMINDER_TYPES:
            raise ValueError(
                f"type must be one of {sorted(ALLOWED_REMINDER_TYPES)}; got {v!r}"
            )
        return v


class CohortPriorsResponse(BaseModel):
    """Wire-format for GET /reminder-cohort-priors. Mirrors the Swift
    `CohortPriorResponse` struct exactly so JSON encode/decode round-trips.
    """
    priors: dict[str, dict[str, float]] = Field(
        default_factory=dict,
        description="Per-type per-hour tap-through rate. Keys: ReminderType.rawValue → '00'..'23' → rate in [0, 1]. Cells with shows < 50 are suppressed.",
    )
    kill_flags: list[str] = Field(
        default_factory=list,
        description="ReminderType.rawValue strings whose per-type metric crossed the kill threshold; client should revert these types to static fire times.",
    )


# ────────────────────────────────────────────────────────────────────────
# Endpoints
# ────────────────────────────────────────────────────────────────────────

@router.post("/reminder-cohort-event", status_code=status.HTTP_204_NO_CONTENT)
async def record_cohort_event(
    event: CohortEvent,
    settings: Annotated[Settings, Depends(get_settings)],
) -> None:
    """Fire-and-forget anonymised cohort write.

    Always increments ``reminders.shows.<type>`` for the (hour) bucket.
    If ``tapped=True``, additionally increments ``reminders.taps.<type>``
    for the same bucket. Two writes per event lets the read path compute
    tap-through rate as ``taps[h] / shows[h]`` directly.

    Returns 204 immediately — Supabase writes happen on a background task
    so a slow Supabase round-trip never blocks the iOS client.
    """
    cohort = CohortService(settings)
    hour_str = f"{event.hour:02d}"

    # Always write shows
    asyncio.create_task(
        cohort.increment_fields(
            f"reminders.shows.{event.type}",
            {"hour": hour_str},
        )
    )

    # Conditionally write taps
    if event.tapped:
        asyncio.create_task(
            cohort.increment_fields(
                f"reminders.taps.{event.type}",
                {"hour": hour_str},
            )
        )


@router.get("/reminder-cohort-priors", response_model=CohortPriorsResponse)
async def get_cohort_priors(
    settings: Annotated[Settings, Depends(get_settings)],
) -> CohortPriorsResponse:
    """Per-type per-hour tap-through priors, computed from the reminders.*
    cohort_stats segments.

    Suppresses cells with fewer than ``PRIVACY_THRESHOLD`` (50) shows.
    Surfaces kill flags from the ``reminders.kill_flag`` segment as a
    separate list — the iOS client uses that to force the corresponding
    reminder types back to their static fire times until the flag clears.

    Empty Supabase response → empty {priors: {}, kill_flags: []}; the iOS
    cache stays cold and the resolver (PR 2) falls back to static defaults.
    """
    cohort = CohortService(settings)
    rows = await cohort.list_rows_by_segment_pattern("reminders.%")

    shows: dict[str, dict[str, int]] = {}
    taps: dict[str, dict[str, int]] = {}
    kill_flags: list[str] = []

    for row in rows:
        segment = row.get("segment", "")
        field_value = str(row.get("field_value", ""))
        frequency = int(row.get("frequency", 0))

        # kill_flag rows: segment = "reminders.kill_flag", field_name = type, field_value = "true"
        if segment == "reminders.kill_flag" and field_value == "true":
            type_name = row.get("field_name", "")
            if type_name and type_name not in kill_flags:
                kill_flags.append(type_name)
            continue

        if segment.startswith("reminders.shows."):
            type_ = segment.removeprefix("reminders.shows.")
            shows.setdefault(type_, {})[field_value] = frequency
        elif segment.startswith("reminders.taps."):
            type_ = segment.removeprefix("reminders.taps.")
            taps.setdefault(type_, {})[field_value] = frequency

    priors: dict[str, dict[str, float]] = {}
    for type_, hour_shows in shows.items():
        per_hour: dict[str, float] = {}
        for hour, n_shows in hour_shows.items():
            if n_shows < PRIVACY_THRESHOLD:
                continue  # suppress sub-threshold cells
            n_taps = taps.get(type_, {}).get(hour, 0)
            # Guard against pathological data where taps > shows
            rate = min(1.0, n_taps / n_shows) if n_shows > 0 else 0.0
            per_hour[hour] = rate
        if per_hour:
            priors[type_] = per_hour

    return CohortPriorsResponse(priors=priors, kill_flags=kill_flags)
