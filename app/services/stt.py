"""Speech-to-Text stage using a local faster-whisper model.

The model is loaded lazily once and reused across requests (model load
is expensive; inference is cheap). Thread-safe lazy initialisation keeps
the first request from racing multiple model loads.
"""

from __future__ import annotations

import threading

import numpy as np

from app.core.config import settings
from app.schemas.pipeline import TranscriptionResult, TranscriptSegment

_model = None
_lock = threading.Lock()


def _get_model():
    global _model
    if _model is None:
        with _lock:
            if _model is None:
                # Imported here so the API can start without the heavy dep
                # resolved until STT is actually needed.
                from faster_whisper import WhisperModel

                _model = WhisperModel(
                    settings.stt_model_path,
                    device=settings.device,
                    compute_type=settings.stt_compute_type,
                )
    return _model


def transcribe(
    samples: np.ndarray,
    language: str | None = None,
) -> TranscriptionResult:
    """Transcribe mono float32 16 kHz audio into text + timed segments.

    ``language`` forces a source language (ISO-639-1); ``None`` lets
    Whisper auto-detect it.
    """
    model = _get_model()

    segments_iter, info = model.transcribe(
        samples,
        beam_size=settings.stt_beam_size,
        language=language,
        vad_filter=settings.stt_vad_filter,
        condition_on_previous_text=settings.stt_condition_on_previous_text,
        # Greedy temperature + tighter no-speech cuts down "hello how are you"
        # style hallucinations on short / quiet meeting clips.
        temperature=0.0,
        no_speech_threshold=settings.stt_no_speech_threshold,
        compression_ratio_threshold=settings.stt_compression_ratio_threshold,
        without_timestamps=True,
    )

    segments: list[TranscriptSegment] = []
    for seg in segments_iter:
        segments.append(
            TranscriptSegment(
                start=round(seg.start, 3),
                end=round(seg.end, 3),
                text=seg.text.strip(),
            )
        )

    full_text = " ".join(s.text for s in segments).strip()

    return TranscriptionResult(
        language=info.language,
        language_probability=round(float(info.language_probability), 4),
        duration=round(float(info.duration), 3),
        text=full_text,
        segments=segments,
    )
