from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from starlette.concurrency import run_in_threadpool

from app.schemas.pipeline import TranscriptionResult
from app.services import audio_utils, noise_reduction, stt

router = APIRouter(prefix="/stt", tags=["speech-to-text"])


def _decode_and_transcribe(
    data: bytes,
    language: str | None,
    denoise: bool,
) -> TranscriptionResult:
    try:
        samples, sr = audio_utils.load_audio(data)
    except Exception as exc:  # noqa: BLE001 - surface decode errors to client
        raise HTTPException(status_code=400, detail=f"Could not decode audio: {exc}")

    if denoise:
        samples = noise_reduction.reduce_noise(samples, sr)

    return stt.transcribe(samples, language=language)


@router.post("/transcribe", response_model=TranscriptionResult)
async def transcribe(
    file: UploadFile = File(..., description="Meeting audio clip (wav/ogg/mp3/…)."),
    language: str | None = Form(
        None, description="Force source language (ISO code). Omit to auto-detect."
    ),
    denoise: bool = Form(True, description="Apply noise reduction before STT."),
) -> TranscriptionResult:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    # Decoding and Whisper inference are CPU-bound and would otherwise block
    # the event loop, stalling every other request until they finish.
    return await run_in_threadpool(_decode_and_transcribe, data, language, denoise)
