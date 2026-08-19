from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.stt import sanitize_stt_text


def test_collapses_arabic_word_loop_keeps_prefix():
    loop = " ".join(["نحن"] * 40)
    text = f"ونحن أن نتحق بأننا {loop}"
    cleaned = sanitize_stt_text(text)
    words = cleaned.split()
    assert "ونحن" in words
    assert words.count("نحن") <= 2
    assert len(words) < 20


def test_drops_pure_token_loop():
    text = " ".join(["نحن"] * 30)
    assert sanitize_stt_text(text) == ""


def test_collapses_tiled_english_phrase():
    unit = "the main purpose of this application"
    text = " ".join([unit] * 4)
    assert sanitize_stt_text(text) == unit


def test_keeps_normal_sentence():
    text = "Welcome to the meeting, can you hear me clearly?"
    assert sanitize_stt_text(text) == text


def test_empty_and_whitespace():
    assert sanitize_stt_text("") == ""
    assert sanitize_stt_text("   ") == ""
