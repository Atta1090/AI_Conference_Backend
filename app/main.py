"""ConvoBridge AI Backend — FastAPI application entry point.

Exposes the meeting audio pipeline as REST endpoints:

* ``/stt/transcribe``   — Speech-to-Text (faster-whisper)
* ``/noise/reduce``     — Noise reduction (spectral gating)
* ``/translate``        — Translation (Opus-MT: en/ur/ar/hi)
* ``/tts/speak``        — Text-to-Speech (Coqui XTTS v2; disabled by default)
* ``/pipeline/process`` — Full denoise -> STT -> translate (-> optional TTS)
* ``/summarize``        — Meeting summarization (Gemma 3)
* ``/chatbot/ask``      — Meeting transcript Q&A (Gemma 3)
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.core.stage_log import banner, stage
from app.routers import chatbot, health, noise, pipeline, stt, summarization, translation, tts

app = FastAPI(
    title=settings.project_name,
    version=settings.version,
    description="AI backend for multilingual video conferencing (ConvoBridge).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def stage_request_log(request: Request, call_next):
    """Log each API hit so the terminal shows what the phones are doing."""
    path = request.url.path
    # Skip noisy static media probes.
    if path.startswith("/media"):
        return await call_next(request)

    client = request.client.host if request.client else "?"
    stage("HTTP", f"{request.method} {path}", from_ip=client)
    response = await call_next(request)
    stage(
        "HTTP",
        f"{request.method} {path} → {response.status_code}",
        from_ip=client,
    )
    return response


@app.on_event("startup")
def _on_startup() -> None:
    banner()

app.include_router(health.router)
app.include_router(stt.router)
app.include_router(noise.router)
app.include_router(translation.router)
app.include_router(tts.router)
app.include_router(pipeline.router)
app.include_router(summarization.router)
app.include_router(chatbot.router)

# Serve synthesized TTS audio referenced by PipelineResult.tts_audio_url.
app.mount("/media", StaticFiles(directory=str(settings.upload_dir)), name="media")


@app.get("/", tags=["system"])
def root():
    return {
        "message": "ConvoBridge AI Backend is running",
        "docs": "/docs",
        "modules": [
            "stt",
            "noise",
            "translate",
            "tts",
            "pipeline",
            "summarize",
            "chatbot",
        ],
    }
