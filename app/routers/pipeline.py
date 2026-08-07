from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from starlette.concurrency import run_in_threadpool

from app.core import languages
from app.schemas.pipeline import PipelineResult
from app.services import pipeline

router = APIRouter(prefix="/pipeline", tags=["pipeline"])


@router.post("/process", response_model=PipelineResult)
async def process(
    file: UploadFile = File(..., description="Meeting audio clip."),
    target_language: str = Form(..., description="Listener's language (ISO code)."),
    source_language: str | None = Form(
        None, description="Speaker language; omit to auto-detect."
    ),
    denoise: bool = Form(True, description="Apply noise reduction first."),
    synthesize_speech: bool = Form(
        True, description="Also generate translated TTS audio."
    ),
) -> PipelineResult:
    """Run the full meeting turn: denoise -> STT -> translate -> TTS."""
    if not languages.is_supported(target_language):
        raise HTTPException(
            status_code=400, detail=f"Unsupported target language '{target_language}'."
        )
    if source_language and not languages.is_supported(source_language):
        raise HTTPException(
            status_code=400, detail=f"Unsupported source language '{source_language}'."
        )

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    try:
        # The full denoise -> STT -> translate -> TTS chain is CPU-bound and
        # would block the event loop for its entire duration.
        return await run_in_threadpool(
            pipeline.run_pipeline,
            audio_bytes=data,
            target_language=target_language,
            source_language=source_language,
            denoise=denoise,
            synthesize_speech=synthesize_speech,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Pipeline failed: {exc}") from exc
