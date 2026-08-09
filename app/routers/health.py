from fastapi import APIRouter

from app.core.config import settings
from app.core.languages import supported_catalogue
from app.core.stage_log import stage
from app.schemas.pipeline import HealthResponse

router = APIRouter(tags=["system"])


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    stage("HEALTH", "Phone/app checked AI server", device=settings.device)
    return HealthResponse(
        status="ok",
        service=settings.project_name,
        version=settings.version,
        device=settings.device,
    )


@router.get("/languages")
def languages():
    """List languages supported across the pipeline."""
    return {"languages": supported_catalogue()}
