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


@router.get("/languages/readiness")
def languages_readiness():
    """Report which translation pairs are actually installed on this machine.

    A missing Urdu pair is the usual reason non-English meetings fall back to
    English captions and summaries, and it is otherwise invisible until a demo
    is already running.
    """
    from app.services.translation import installed_pairs

    pairs = installed_pairs()
    missing = sorted(name for name, ready in pairs.items() if not ready)
    stage(
        "HEALTH",
        "Translation readiness checked",
        ready=len(pairs) - len(missing),
        missing=len(missing),
    )
    return {
        "pairs": pairs,
        "missing": missing,
        "all_ready": not missing,
        "hint": (
            "Run: python download_opus_models.py"
            if missing
            else "All Opus-MT pairs installed."
        ),
    }
