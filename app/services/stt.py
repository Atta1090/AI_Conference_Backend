"""Speech-to-Text stage using a local faster-whisper model.

The model is loaded lazily once and reused across requests (model load
is expensive; inference is cheap). Thread-safe lazy initialisation keeps
the first request from racing multiple model loads.
"""

from __future__ import annotations

import re
import threading
from collections import Counter

import numpy as np

from app.core.config import settings
from app.schemas.pipeline import TranscriptionResult, TranscriptSegment

_model = None
_lock = threading.Lock()

# Split on whitespace; keeps Arabic / CJK tokens intact as whole words.
_WORD_RE = re.compile(r"\S+")


def sanitize_stt_text(text: str) -> str:
    """Collapse Whisper repetition loops; drop unrecoverable hallucinations.

    Whisper often gets stuck on one token (e.g. Arabic «نحن نحن نحن…») or
    repeats a short phrase many times on quiet / noisy clips. Those loops
    must not reach Firestore transcripts or live captions.
    """
    text = (text or "").strip()
    if not text:
        return ""

    words = _WORD_RE.findall(text)
    if not words:
        return ""

    original_n = len(words)
    # Exact phrase tiled 3+ times → keep one copy.
    words = _collapse_tiled_phrase(words)
    # Consecutive identical tokens → keep at most two.
    words = _collapse_word_runs(words, max_run=2)

    uniq = {w.casefold() for w in words}
    # Pure token loop (only one distinct word, long original run).
    if len(uniq) == 1 and original_n >= 6:
        return ""
    if _is_repetition_hallucination(words):
        return ""

    return " ".join(words).strip()


def _collapse_word_runs(words: list[str], max_run: int = 2) -> list[str]:
    out: list[str] = []
    run_key: str | None = None
    run_len = 0
    for w in words:
        key = w.casefold()
        if key == run_key:
            run_len += 1
            if run_len <= max_run:
                out.append(w)
        else:
            run_key = key
            run_len = 1
            out.append(w)
    return out


def _collapse_tiled_phrase(words: list[str], max_unit: int = 12) -> list[str]:
    n = len(words)
    if n < 6:
        return words
    keys = [w.casefold() for w in words]
    upper = min(max_unit, n // 3)
    for size in range(1, upper + 1):
        if n % size != 0:
            continue
        reps = n // size
        if reps < 3:
            continue
        unit = keys[:size]
        if all(keys[i * size : (i + 1) * size] == unit for i in range(reps)):
            return words[:size]
    return words


def _is_repetition_hallucination(words: list[str]) -> bool:
    """True when one token dominates a long utterance (classic Whisper loop)."""
    if len(words) < 8:
        return False
    counts = Counter(w.casefold() for w in words)
    _top, top_count = counts.most_common(1)[0]
    return top_count >= 6 and (top_count / len(words)) >= 0.45


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
        cleaned = sanitize_stt_text(seg.text.strip())
        if not cleaned:
            continue
        segments.append(
            TranscriptSegment(
                start=round(seg.start, 3),
                end=round(seg.end, 3),
                text=cleaned,
            )
        )

    full_text = sanitize_stt_text(" ".join(s.text for s in segments))

    return TranscriptionResult(
        language=info.language,
        language_probability=round(float(info.language_probability), 4),
        duration=round(float(info.duration), 3),
        text=full_text,
        segments=segments,
    )
