from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.core import languages
from app.core.config import settings
from app.schemas.pipeline import TTSRequest
from app.services import tts

router = APIRouter(prefix="/tts", tags=["text-to-speech"])


@router.post(
    "/speak",
    responses={200: {"content": {"audio/wav": {}}}},
    response_class=Response,
)
def speak(req: TTSRequest):
    """Synthesize speech for the given text and return a WAV file.

    Disabled by default — XTTS stays on disk but is not loaded. Re-enable with
    ENABLE_BACKEND_TTS=true. The Flutter app uses flutter_tts instead.
    """
    if not settings.enable_backend_tts:
        raise HTTPException(
            status_code=503,
            detail=(
                "Backend XTTS is disabled. Speech is handled on-device via "
                "flutter_tts. Set ENABLE_BACKEND_TTS=true to use /tts/speak."
            ),
        )
    if not languages.is_supported(req.language):
        raise HTTPException(
            status_code=400, detail=f"Unsupported language '{req.language}'."
        )
    try:
        wav = tts.synthesize(req.text, req.language)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return Response(content=wav, media_type="audio/wav")
