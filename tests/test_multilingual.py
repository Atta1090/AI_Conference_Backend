from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services import multilingual as ml


def test_normalize_code_accepts_locales_and_names():
    assert ml.normalize_code("ur") == "ur"
    assert ml.normalize_code("ur-PK") == "ur"
    assert ml.normalize_code("Urdu") == "ur"
    assert ml.normalize_code("en_US") == "en"
    assert ml.normalize_code(None) == "en"
    assert ml.normalize_code("klingon") == "en"


def test_detect_language_separates_urdu_from_arabic():
    assert ml.detect_language("مواصلات کا نظام بہت اہم ہے") == "ur"
    assert ml.detect_language("هذه محادثة في اجتماع عبر الفيديو") == "ar"
    assert ml.detect_language("यह एक वीडियो मीटिंग है") == "hi"
    assert ml.detect_language("Welcome to the meeting") == "en"


def test_detect_language_uses_room_hint_when_script_is_ambiguous():
    # Arabic-script text with no Urdu-only letters could be either language.
    ambiguous = "السلام"
    assert ml.detect_language(ambiguous, default="ur") == "ur"
    assert ml.detect_language(ambiguous, default="ar") == "ar"


def test_detect_language_falls_back_to_default_for_empty_text():
    assert ml.detect_language("", default="hi") == "hi"
    assert ml.detect_language("123 456", default="ur") == "ur"


def test_parse_transcript_tags_each_line():
    transcript = "Ahmed: Welcome to the meeting\nSara: میں تیار ہوں"
    entries = ml.parse_transcript(transcript)
    assert [e["speaker"] for e in entries] == ["Ahmed", "Sara"]
    assert entries[0]["lang"] == "en"
    assert entries[1]["lang"] == "ur"


def test_parse_transcript_handles_unlabelled_lines():
    entries = ml.parse_transcript("just a plain sentence")
    assert entries == [
        {"speaker": "Speaker", "text": "just a plain sentence", "lang": "en"}
    ]


def test_normalize_entries_corrects_a_mislabelled_language():
    entries = ml.normalize_entries(
        [{"speaker": "Ali", "text": "یہ اردو ہے", "lang": "en"}]
    )
    assert entries[0]["lang"] == "ur"


def test_normalize_entries_drops_blank_lines_and_defaults_speaker():
    entries = ml.normalize_entries(
        [
            {"text": "   ", "lang": "en"},
            {"text": "Hello there", "lang": "en"},
        ]
    )
    assert len(entries) == 1
    assert entries[0]["speaker"] == "Speaker"


def test_dominant_language_weights_by_length():
    entries = [
        {"speaker": "A", "text": "hi", "lang": "en"},
        {"speaker": "B", "text": "یہ ایک لمبا اردو جملہ ہے", "lang": "ur"},
    ]
    assert ml.dominant_language(entries) == "ur"


def test_render_transcript_round_trips_speaker_labels():
    entries = [{"speaker": "Ali", "text": "Hello", "lang": "en"}]
    assert ml.render_transcript(entries) == "Ali: Hello"


def test_detect_language_defaults_unmarked_perso_arabic_to_urdu():
    # No room hint, no Urdu-only letter: still prefer Urdu over Arabic.
    assert ml.detect_language("السلام", default="en") == "ur"


def test_to_english_leaves_english_questions_alone():
    question = "Who will finish the payment module?"
    assert ml.to_english(question, hint="ur") == question
    assert ml.to_english(question, hint="ar") == question


def test_mostly_in_language_checks_script():
    assert ml.mostly_in_language("Hello there everyone", "en")
    assert ml.mostly_in_language("مواصلات کا نظام بہت اہم ہے", "ur")
    assert not ml.mostly_in_language("Hello there everyone", "ur")
    assert not ml.mostly_in_language("Hello there everyone", "hi")


def test_not_in_transcript_is_localized():
    assert ml.not_in_transcript("en") == "Not mentioned in the transcript."
    assert ml.not_in_transcript("ur") != ml.not_in_transcript("en")
    assert ml.not_in_transcript("bogus") == ml.not_in_transcript("en")


def test_localize_many_keeps_english_untouched():
    texts = ["one", "two"]
    assert ml.localize_many(texts, "en") == texts


def test_split_leading_name_matches_longest_name_first():
    pattern = ml._names_pattern(["Ali", "Ali Raza"])
    name, separator, body = ml._split_leading_name("Ali Raza: ship it", pattern)
    assert name == "Ali Raza"
    assert separator == ": "
    assert body == "ship it"


def test_split_leading_name_handles_a_plain_space():
    pattern = ml._names_pattern(["Bilal"])
    name, separator, body = ml._split_leading_name(
        "Bilal will finish the module.", pattern
    )
    assert name == "Bilal"
    assert separator == " "
    assert body == "will finish the module."


def test_split_leading_name_ignores_unknown_names():
    pattern = ml._names_pattern(["Bilal"])
    name, _, body = ml._split_leading_name("Sara will review it.", pattern)
    assert name is None
    assert body == "Sara will review it."


def test_names_pattern_is_empty_without_real_names():
    assert ml._names_pattern([]) is None
    assert ml._names_pattern(["Speaker", "  "]) is None
