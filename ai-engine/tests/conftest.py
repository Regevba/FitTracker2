import pytest

from app.auth import jwt_validator
from app.config import Settings, get_settings
from app.main import create_app
from app.middleware import rate_limiter


@pytest.fixture
def test_settings() -> Settings:
    return Settings(
        supabase_url="https://example.supabase.co",
        supabase_service_key="test-service-key",
        supabase_jwks_url="https://example.supabase.co/auth/v1/.well-known/jwks.json",
    )


@pytest.fixture
def app(test_settings: Settings):
    app = create_app()
    app.dependency_overrides[get_settings] = lambda: test_settings

    yield app

    app.dependency_overrides.clear()
    rate_limiter._request_log.clear()
    jwt_validator._jwks_cache = None
