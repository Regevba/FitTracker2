import os
import pytest

@pytest.fixture(autouse=True)
def mock_env_vars():
    """Inject mock environment variables for the test suite before any app modules evaluate Settings."""
    os.environ["SUPABASE_URL"] = "https://mock.supabase.co"
    os.environ["SUPABASE_SERVICE_KEY"] = "mock-service-key"
    os.environ["SUPABASE_JWKS_URL"] = "https://mock.supabase.co/auth/v1/.well-known/jwks.json"
    yield
    os.environ.pop("SUPABASE_URL", None)
    os.environ.pop("SUPABASE_SERVICE_KEY", None)
    os.environ.pop("SUPABASE_JWKS_URL", None)
