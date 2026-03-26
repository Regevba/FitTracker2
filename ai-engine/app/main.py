import logging
from functools import lru_cache

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.config import Settings, get_settings
from app.routers import training, nutrition, recovery, stats

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


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

    @app.exception_handler(404)
    async def not_found_handler(request: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(status_code=404, content={"detail": "Not found"})

    @app.exception_handler(500)
    async def internal_error_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.error("Unhandled error on %s %s: %s", request.method, request.url.path, exc)
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})

    return app


app = create_app()
