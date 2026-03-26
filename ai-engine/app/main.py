from functools import lru_cache

from fastapi import FastAPI

from app.config import Settings, get_settings
from app.routers import training, nutrition, recovery, stats


@lru_cache
def _settings() -> Settings:
    return get_settings()


def create_app() -> FastAPI:
    app = FastAPI(
        title="FitTracker AI Engine",
        description="Federated cohort intelligence — GDPR-compliant population insights",
        version="1.0.0",
    )

    app.include_router(training.router, prefix="/v1/training", tags=["training"])
    app.include_router(nutrition.router, prefix="/v1/nutrition", tags=["nutrition"])
    app.include_router(recovery.router, prefix="/v1/recovery", tags=["recovery"])
    app.include_router(stats.router,    prefix="/v1/stats",    tags=["stats"])

    @app.get("/health", tags=["infra"])
    async def health() -> dict:
        return {"status": "ok"}

    return app


app = create_app()
