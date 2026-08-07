from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from starlette.concurrency import run_in_threadpool

from app.services import audio_utils, noise_reduction

router = APIRouter(prefix="/noise", tags=["noise-reduction"])


def _denoise_to_wav(data: bytes, strength: float) -> bytes:
    try:
        samples, sr = audio_utils.load_audio(data)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"Could not decode audio: {exc}")

    cleaned = noise_reduction.reduce_noise(samples, sr, strength=strength)
    return audio_utils.encode_wav(cleaned, sr)


@router.post(
    "/reduce",
    responses={200: {"content": {"audio/wav": {}}}},
    response_class=Response,
)
async def reduce(
    file: UploadFile = File(..., description="Noisy audio clip."),
    strength: float = Form(
        0.85, ge=0.0, le=1.0, description="Suppression strength (0-1)."
    ),
):
    """Return a denoised 16 kHz mono WAV of the uploaded audio."""
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    # Spectral gating is CPU-bound; keep it off the event loop.
    wav = await run_in_threadpool(_denoise_to_wav, data, strength)
    return Response(content=wav, media_type="audio/wav")
