"""
In-memory rate limiter: 10 requests per segment per hour, keyed on JWT sub.
Note: in-memory state does not persist across process restarts or
across multiple Railway replicas. Acceptable for current scale;
upgrade to Redis-backed limiter if horizontal scaling is required.
"""

import time
import logging
from collections import defaultdict

from fastapi import Depends, HTTPException, status

from app.auth.jwt_validator import get_verified_claims
from app.config import Settings, get_settings

logger = logging.getLogger(__name__)

# { (sub, segment): [(timestamp, ...), ...] }
_request_log: dict[tuple[str, str], list[float]] = defaultdict(list)
_WINDOW = 3600.0  # 1 hour in seconds


def make_rate_limit_dependency(segment: str):
    """Return a FastAPI dependency that enforces the per-segment rate limit."""

    async def check_rate_limit(
        claims: dict = Depends(get_verified_claims),
        settings: Settings = Depends(get_settings),
    ) -> None:
        sub = claims.get("sub", "unknown")
        key = (sub, segment)
        now = time.monotonic()
        window_start = now - _WINDOW

        # Evict timestamps outside the rolling window
        _request_log[key] = [t for t in _request_log[key] if t > window_start]

        if len(_request_log[key]) >= settings.rate_limit_per_hour:
            logger.warning("Rate limit hit: sub=%s segment=%s", sub, segment)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded: {settings.rate_limit_per_hour} requests per hour per segment",
            )

        _request_log[key].append(now)

    return check_rate_limit
