"""Audio I/O helpers for the meeting pipeline.

Everything downstream (noise reduction, Whisper STT) works on mono
float32 samples at a fixed sample rate, so this module centralises
decoding, resampling and encoding.
"""

from __future__ import annotations

import io

import librosa
import numpy as np
import soundfile as sf

from app.core.config import settings


def load_audio(data: bytes, target_sr: int | None = None) -> tuple[np.ndarray, int]:
    """Decode arbitrary audio bytes into mono float32 samples.

    Supports any format libsndfile/audioread can read (wav, ogg, flac,
    mp3, m4a, …). Returns ``(samples, sample_rate)``.
    """
    target_sr = target_sr or settings.sample_rate
    with io.BytesIO(data) as buffer:
        # librosa handles resampling + mono downmix in one call.
        samples, sr = librosa.load(buffer, sr=target_sr, mono=True)
    return samples.astype(np.float32), sr


def encode_wav(samples: np.ndarray, sample_rate: int | None = None) -> bytes:
    """Encode mono float32 samples to 16-bit PCM WAV bytes."""
    sample_rate = sample_rate or settings.sample_rate
    samples = np.clip(samples, -1.0, 1.0)
    with io.BytesIO() as buffer:
        sf.write(buffer, samples, sample_rate, format="WAV", subtype="PCM_16")
        return buffer.getvalue()


def duration_seconds(samples: np.ndarray, sample_rate: int | None = None) -> float:
    sample_rate = sample_rate or settings.sample_rate
    return round(len(samples) / float(sample_rate), 3)
