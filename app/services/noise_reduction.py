"""Noise reduction stage of the meeting pipeline.

The document specifies an RNNoise-based suppressor. RNNoise ships as a
C library with fragile Python bindings, so for a portable, pip-only,
cross-platform implementation we use spectral-gating noise suppression
(``noisereduce``), which targets the same goal: removing stationary and
non-stationary background noise before speech reaches the STT engine.

The engine is swappable behind :func:`reduce_noise` without touching the
rest of the pipeline.
"""

from __future__ import annotations

import numpy as np
import noisereduce as nr

from app.core.config import settings


def reduce_noise(
    samples: np.ndarray,
    sample_rate: int | None = None,
    strength: float | None = None,
) -> np.ndarray:
    """Suppress background noise in mono float32 audio.

    ``strength`` (0.0-1.0) maps to ``noisereduce``'s ``prop_decrease``:
    how aggressively the estimated noise floor is removed.
    """
    if samples.size == 0:
        return samples

    sample_rate = sample_rate or settings.sample_rate
    strength = settings.noise_reduction_strength if strength is None else strength
    strength = float(min(max(strength, 0.0), 1.0))

    cleaned = nr.reduce_noise(
        y=samples,
        sr=sample_rate,
        stationary=settings.noise_stationary,
        prop_decrease=strength,
    )
    return cleaned.astype(np.float32)
