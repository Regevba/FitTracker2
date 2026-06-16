from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    supabase_url: str
    supabase_service_key: str
    supabase_jwks_url: str
    supabase_jwt_audience: str = "authenticated"
    rate_limit_per_hour: int = 10
    k_anonymity_floor: int = 50

    # DEPRECATED (foundation-models-tier3, 2026-06-15): the `escalate_to_llm`
    # signal is now consumed ON-DEVICE via Apple Private Cloud Compute (Tier 3b
    # in the iOS AIOrchestrator), which needs no API key and no DPA (Apple does
    # not retain prompts). The server-side LLM call this key was reserved for is
    # no longer planned, so `llm_api_key` stays unset by design. Left in place
    # (not deleted) so any future server-side escalation can reuse the slot.
    llm_api_key: str | None = None


def get_settings() -> Settings:
    return Settings()
