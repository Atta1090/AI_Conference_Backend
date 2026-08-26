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
_ARABIC_CHARS = re.compile(r"[\u0600-\u06FF]")
_DEVANAGARI_CHARS = re.compile(r"[\u0900-\u097F]")
_LATIN_CHARS = re.compile(r"[A-Za-z]")

# Bias Whisper toward the expected script (helps Urdu/Arabic a lot on base).
_LANG_PROMPTS: dict[str, str] = {
    "ur": "السلام علیکم۔ یہ ایک ویڈیو میٹنگ کی گفتگو ہے۔",
    "ar": "السلام عليكم. هذه محادثة في اجتماع عبر الفيديو.",
    "hi": "नमस्ते। यह एक वीडियो मीटिंग की बातचीत है।",
    "en": "Hello. This is a video meeting conversation.",
}


def sanitize_stt_text(text: str, language: str | None = None) -> str:
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

    cleaned = " ".join(words).strip()
    if language and _is_unrelated_hallucination(cleaned, language):
        return ""
    return cleaned


def _is_unrelated_hallucination(text: str, language: str) -> bool:
    """Drop obvious Whisper junk, but keep English words spoken under Urdu.

    A hard "must be Arabic script" filter hid real speech: Whisper-base often
    emits English for Urdu audio, and the other phone then received nothing.
    Those English lines are translated into the listener's language instead.
    """
    if language not in {"ur", "ar", "hi"}:
        return False
    lower = text.casefold()
    if re.search(r"\b(tbsp|tablespoon|subscribe|thank you for watching)\b", lower):
        return True
    latin = len(_LATIN_CHARS.findall(text))
    arabic = len(_ARABIC_CHARS.findall(text))
    deva = len(_DEVANAGARI_CHARS.findall(text))
    native = arabic if language in {"ur", "ar"} else deva
    # Pure Latin and no native script *and* very long: likely a looped English
    # hallucination, not a short code-switched meeting line.
    if native == 0 and latin >= 80:
        return True
    return False


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

    # Urdu/Arabic/Hindi need a wider beam on the small base model.
    beam = settings.stt_beam_size
    if language in {"ur", "ar", "hi"}:
        beam = max(beam, 5)

    kwargs: dict = {
        "beam_size": beam,
        "language": language,
        "vad_filter": settings.stt_vad_filter,
        "condition_on_previous_text": settings.stt_condition_on_previous_text,
        # Greedy temperature + tighter no-speech cuts down "hello how are you"
        # style hallucinations on short / quiet meeting clips.
        "temperature": 0.0,
        "no_speech_threshold": settings.stt_no_speech_threshold,
        "compression_ratio_threshold": settings.stt_compression_ratio_threshold,
        "without_timestamps": True,
    }
    prompt = _LANG_PROMPTS.get(language or "")
    if prompt:
        kwargs["initial_prompt"] = prompt

    segments_iter, info = model.transcribe(samples, **kwargs)

    segments: list[TranscriptSegment] = []
    for seg in segments_iter:
        cleaned = sanitize_stt_text(seg.text.strip(), language=language)
        if not cleaned:
            continue
        segments.append(
            TranscriptSegment(
                start=round(seg.start, 3),
                end=round(seg.end, 3),
                text=cleaned,
            )
        )

    full_text = sanitize_stt_text(
        " ".join(s.text for s in segments), language=language
    )

    return TranscriptionResult(
        language=info.language,
        language_probability=round(float(info.language_probability), 4),
        duration=round(float(info.duration), 3),
        text=full_text,
        segments=segments,
    )
