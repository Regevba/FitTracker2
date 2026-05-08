"""
CohortService: writes anonymised band data to Supabase cohort_stats via
the increment_cohort_frequency RPC, and reads population-level aggregates
for k-anonymity-gated cohort insight queries.
"""

import logging
from typing import Any

import httpx

from app.config import Settings

logger = logging.getLogger(__name__)


class CohortService:
    def __init__(self, settings: Settings) -> None:
        self._url = settings.supabase_url.rstrip("/")
        self._service_key = settings.supabase_service_key
        self._k_floor = settings.k_anonymity_floor

    def _headers(self) -> dict[str, str]:
        return {
            "apikey": self._service_key,
            "Authorization": f"Bearer {self._service_key}",
            "Content-Type": "application/json",
        }

    async def increment_fields(
        self,
        segment: str,
        fields: dict[str, str],
    ) -> None:
        """Fire-and-forget: increment frequency for each (segment, field, value) tuple.
        Called via asyncio.create_task() from routers — failures are logged but
        do not affect the HTTP response returned to the client.
        """
        async with httpx.AsyncClient(timeout=10.0) as client:
            for field_name, field_value in fields.items():
                try:
                    resp = await client.post(
                        f"{self._url}/rest/v1/rpc/increment_cohort_frequency",
                        headers=self._headers(),
                        json={
                            "p_segment":     segment,
                            "p_field_name":  field_name,
                            "p_field_value": field_value,
                        },
                    )
                    resp.raise_for_status()
                except Exception as exc:
                    logger.error(
                        "cohort write failed segment=%s field=%s value=%s error=%s",
                        segment, field_name, field_value, exc,
                    )

    async def list_rows_by_segment_pattern(
        self,
        pattern: str,
    ) -> list[dict[str, Any]]:
        """Return every cohort_stats row whose `segment` matches the given
        SQL LIKE pattern (e.g. ``"reminders.%"``).

        Used by the smart-reminders behavioral-learning read path to gather
        all per-(type, hour) shows + taps in one query, then compute the
        per-type-per-hour tap-through rate client-side.

        Returns rows as dicts with keys: segment, field_name, field_value,
        frequency. Empty list on error (logged); never raises — callers
        treat absence as "no cohort data yet" and degrade gracefully.
        """
        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                resp = await client.get(
                    f"{self._url}/rest/v1/cohort_stats",
                    headers={**self._headers(), "Accept": "application/json"},
                    params={
                        "segment": f"like.{pattern}",
                        "select":  "segment,field_name,field_value,frequency",
                    },
                )
                resp.raise_for_status()
                return resp.json()
            except Exception as exc:
                logger.error(
                    "cohort list_by_pattern failed pattern=%s error=%s",
                    pattern, exc,
                )
                return []

    async def get_cohort_totals(
        self,
        segment: str,
        fields: dict[str, str],
    ) -> dict[str, int]:
        """Return frequency counts for each requested (field_name, field_value) pair,
        applying k-anonymity floor: buckets below k_floor are returned as 0.
        Uses a single SUM-based check per field to gate the response.
        """
        results: dict[str, int] = {}

        async with httpx.AsyncClient(timeout=10.0) as client:
            for field_name, field_value in fields.items():
                try:
                    resp = await client.get(
                        f"{self._url}/rest/v1/cohort_stats",
                        headers={**self._headers(), "Accept": "application/json"},
                        params={
                            "segment":     f"eq.{segment}",
                            "field_name":  f"eq.{field_name}",
                            "field_value": f"eq.{field_value}",
                            "select":      "frequency",
                        },
                    )
                    resp.raise_for_status()
                    rows = resp.json()
                    freq = rows[0]["frequency"] if rows else 0
                    # k-anonymity gate: suppress buckets below floor
                    results[f"{field_name}:{field_value}"] = freq if freq >= self._k_floor else 0
                except Exception as exc:
                    logger.error(
                        "cohort read failed segment=%s field=%s error=%s",
                        segment, field_name, exc,
                    )
                    results[f"{field_name}:{field_value}"] = 0

        return results
