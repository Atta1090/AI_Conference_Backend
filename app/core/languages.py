"""Language helpers for the ConvoBridge 4-language pipeline.

Supported languages (Pakistan-focused):
  en — English
  ur — Urdu (must-have)
  ar — Arabic
  hi — Hindi

Translation uses Helsinki Opus-MT pair models (lightweight).
Pairs without a direct Opus model are routed through English.
"""

from __future__ import annotations

# ISO-639-1 → display name + XTTS voice code.
# XTTS has no native Urdu; Hindi voice is the closest fallback.
LANGUAGES: dict[str, dict[str, str | None]] = {
    "en": {"name": "English", "xtts": "en"},
    "ur": {"name": "Urdu", "xtts": "hi"},
    "ar": {"name": "Arabic", "xtts": "ar"},
    "hi": {"name": "Hindi", "xtts": "hi"},
}

# Direct Opus-MT Hugging Face model IDs for supported pairs.
# Missing pairs are handled by pivoting through English in the service.
OPUS_PAIRS: dict[tuple[str, str], str] = {
    ("ur", "en"): "Helsinki-NLP/opus-mt-ur-en",
    ("en", "ur"): "Helsinki-NLP/opus-mt-en-ur",
    ("ar", "en"): "Helsinki-NLP/opus-mt-ar-en",
    ("en", "ar"): "Helsinki-NLP/opus-mt-en-ar",
    ("hi", "en"): "Helsinki-NLP/opus-mt-hi-en",
    ("en", "hi"): "Helsinki-NLP/opus-mt-en-hi",
}


def is_supported(code: str) -> bool:
    return code in LANGUAGES


def opus_model_id(source: str, target: str) -> str | None:
    """Return Opus-MT model id for a direct pair, or None if pivot needed."""
    return OPUS_PAIRS.get((source, target))


def translation_path(source: str, target: str) -> list[tuple[str, str]]:
    """Return ordered (src, tgt) hops for translation.

    Direct pair when available; otherwise source→en→target.
    """
    if source == target:
        return []
    if not is_supported(source) or not is_supported(target):
        raise ValueError(
            f"Unsupported language pair '{source}'→'{target}'. "
            f"Supported: {sorted(LANGUAGES)}"
        )
    if (source, target) in OPUS_PAIRS:
        return [(source, target)]
    if source != "en" and target != "en":
        # e.g. ur→ar via English
        return [(source, "en"), ("en", target)]
    raise ValueError(
        f"No Opus-MT route for '{source}'→'{target}'. "
        f"Available direct pairs: {sorted(OPUS_PAIRS)}"
    )


def to_xtts(code: str) -> str | None:
    """Map an ISO-639-1 code to its Coqui XTTS code."""
    if code not in LANGUAGES:
        raise ValueError(
            f"Unsupported language '{code}'. Supported: {sorted(LANGUAGES)}"
        )
    return LANGUAGES[code]["xtts"]


def language_name(code: str) -> str:
    entry = LANGUAGES.get(code)
    return entry["name"] if entry else code  # type: ignore[return-value]


def supported_catalogue() -> list[dict[str, str | None]]:
    return [
        {
            "code": code,
            "name": meta["name"],
            "tts_available": meta["xtts"] is not None,
        }
        for code, meta in LANGUAGES.items()
    ]
