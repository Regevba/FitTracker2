"""
JWT validation using Supabase JWKS endpoint.
JWKS keys are cached for 5 minutes to avoid hammering the auth server.
Only tokens with role == "authenticated" are accepted.
"""

import time
import logging
from typing import Any

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)

_bearer = HTTPBearer()

# Simple in-process JWKS cache: (keys_list, fetched_at_epoch)
_jwks_cache: tuple[list[dict], float] | None = None
_JWKS_TTL = 300  # 5 minutes


async def _fetch_jwks(jwks_url: str) -> list[dict]:
    global _jwks_cache
    now = time.monotonic()

    if _jwks_cache is not None:
        keys, fetched_at = _jwks_cache
        if now - fetched_at < _JWKS_TTL:
            return keys

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(jwks_url)
        response.raise_for_status()
        data = response.json()

    keys = data.get("keys", [])
    _jwks_cache = (keys, now)
    logger.info("JWKS refreshed (%d keys)", len(keys))
    return keys


async def get_verified_claims(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if token.count(".") != 2:
        raise credentials_exception

    try:
        keys = await _fetch_jwks(settings.supabase_jwks_url)
    except Exception as exc:
        logger.error("JWKS fetch failed: %s", exc)
        raise credentials_exception

    for key in keys:
        try:
            claims = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=settings.supabase_jwt_audience,
                options={"verify_exp": True},
            )
            # Enforce Supabase authenticated role claim
            if claims.get("role") != "authenticated":
                raise credentials_exception
            return claims
        except JWTError:
            continue

    raise credentials_exception
