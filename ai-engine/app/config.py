from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    supabase_url: str
    supabase_service_key: str
    supabase_jwks_url: str
    supabase_jwt_audience: str = "authenticated"
    rate_limit_per_hour: int = 10
    k_anonymity_floor: int = 50

    # Optional — must remain unset until LLM sub-processor DPA is in place
    llm_api_key: str | None = None


def get_settings() -> Settings:
    return Settings()
