"""Text-to-Speech stage using a local Coqui XTTS v2 model.

XTTS v2 is multilingual and supports voice cloning from a short speaker
reference clip. If no reference clip is configured, a built-in studio
speaker is used so the endpoint works out of the box.

The model files stay on disk, but loading/synthesis is gated by
``settings.enable_backend_tts`` (default False). The Flutter app speaks
via ``flutter_tts`` instead. Set ENABLE_BACKEND_TTS=true to re-enable.
"""

from __future__ import annotations

import os
import threading

import numpy as np

from app.core.config import settings
from app.core import languages

# XTTS downloads require accepting Coqui's terms; do so non-interactively.
os.environ.setdefault("COQUI_TOS_AGREED", "1")

_model = None
_lock = threading.Lock()


def _load():
    global _model
    if not settings.enable_backend_tts:
        raise ValueError(
            "Backend XTTS is disabled (ENABLE_BACKEND_TTS=false). "
            "Speech playback is handled on-device by flutter_tts. "
            "Set ENABLE_BACKEND_TTS=true to re-enable Coqui XTTS."
        )
    if _model is None:
        with _lock:
            if _model is None:
                from TTS.api import TTS

                use_gpu = settings.device.startswith("cuda")
                _model = TTS(settings.tts_model, gpu=use_gpu)
    return _model


def _default_speaker(model) -> str | None:
    speakers = getattr(getattr(model, "synthesizer", None), "tts_model", None)
    # TTS.api exposes .speakers for multi-speaker models.
    names = getattr(model, "speakers", None)
    if names:
        return names[0]
    return None


def synthesize(text: str, language: str) -> bytes:
    """Synthesize ``text`` in ``language`` (ISO code) to WAV bytes."""
    text = text.strip()
    if not text:
        raise ValueError("Cannot synthesize empty text.")

    xtts_lang = languages.to_xtts(language)
    if xtts_lang is None:
        raise ValueError(
            f"Text-to-Speech is not available for language '{language}'."
        )

    model = _load()

    kwargs: dict = {"text": text, "language": xtts_lang}
    if settings.tts_speaker_wav and os.path.exists(settings.tts_speaker_wav):
        kwargs["speaker_wav"] = settings.tts_speaker_wav
    else:
        speaker = _default_speaker(model)
        if speaker:
            kwargs["speaker"] = speaker

    wav = model.tts(**kwargs)

    # Coqui returns a python list / float array at the model sample rate.
    samples = np.asarray(wav, dtype=np.float32)
    sample_rate = int(
        getattr(model.synthesizer, "output_sample_rate", settings.sample_rate)
    )

    from app.services.audio_utils import encode_wav

    return encode_wav(samples, sample_rate)
