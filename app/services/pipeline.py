"""End-to-end meeting audio pipeline orchestration.

Chains the four stages required for a multilingual meeting turn:

    raw audio -> noise reduction -> speech-to-text -> translation -> TTS

Each stage is independently usable via its own service/endpoint; this
module wires them together for the common "one utterance in, translated
audio out" flow.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from app.core import languages
from app.core.config import settings
from app.schemas.pipeline import PipelineResult
from app.services import audio_utils, noise_reduction, stt, translation, tts

# Synthesized audio is written here and exposed via /media/<file>.
TTS_OUTPUT_DIR: Path = settings.upload_dir / "tts"
TTS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def _save_tts(wav_bytes: bytes) -> str:
    filename = f"{uuid.uuid4().hex}.wav"
    (TTS_OUTPUT_DIR / filename).write_bytes(wav_bytes)
    return f"/media/tts/{filename}"


def run_pipeline(
    audio_bytes: bytes,
    target_language: str,
    source_language: str | None = None,
    denoise: bool = True,
    synthesize_speech: bool = True,
) -> PipelineResult:
    """Run the full meeting pipeline on a single audio clip."""
    samples, sr = audio_utils.load_audio(audio_bytes)

    if denoise:
        samples = noise_reduction.reduce_noise(samples, sr)

    transcription = stt.transcribe(samples, language=source_language)

    detected = transcription.language
    # Prefer an explicit source language; otherwise use STT detection.
    # If Whisper detects something outside en/ur/ar/hi, fail clearly.
    src = source_language or detected
    if not languages.is_supported(src):
        raise ValueError(
            f"Detected/source language '{src}' is not supported for translation. "
            f"Supported: {sorted(languages.LANGUAGES)}. "
            "Pass source_language=en|ur|ar|hi explicitly."
        )

    translated_text = translation.translate(
        transcription.text,
        source_language=src,
        target_language=target_language,
    )

    tts_url: str | None = None
    # XTTS is hidden unless ENABLE_BACKEND_TTS=true; Flutter uses flutter_tts.
    if (
        synthesize_speech
        and settings.enable_backend_tts
        and translated_text
    ):
        try:
            wav = tts.synthesize(translated_text, target_language)
            tts_url = _save_tts(wav)
        except ValueError:
            # e.g. TTS unavailable for the target language; keep text output.
            tts_url = None

    return PipelineResult(
        detected_language=detected,
        language_probability=transcription.language_probability,
        duration=transcription.duration,
        transcript=transcription.text,
        segments=transcription.segments,
        target_language=target_language,
        translated_text=translated_text,
        noise_reduction_applied=denoise,
        tts_audio_url=tts_url,
    )
