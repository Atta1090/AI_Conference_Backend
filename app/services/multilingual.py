"""Language routing for the LLM stages (summary + chatbot).

Gemma 3 1B — especially quantized on CPU, and especially with an English
LoRA mounted — writes usable English but unusable Urdu/Arabic/Hindi. A meeting
transcript is also *mixed*: every participant's line is stored in the language
that participant spoke, so a one-English/one-Urdu meeting hands the model half
Urdu text and it degrades on both halves.

So both LLM stages pivot through English:

    per-line source language --Opus-MT--> English --Gemma--> English
    English --Opus-MT--> the language the user picked

Translation is batched (see ``translation.translate_batch``) so normalising a
whole transcript costs a handful of forward passes, not one per line.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from app.core import languages

SUPPORTED = frozenset(languages.LANGUAGES)
DEFAULT_LANGUAGE = "en"

_ARABIC_SCRIPT = re.compile(r"[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]")
_DEVANAGARI = re.compile(r"[\u0900-\u097F]")
_LATIN = re.compile(r"[A-Za-z]")
# Letters that exist in Urdu (Perso-Arabic) but not in standard Arabic — pe,
# che, zhe, keheh, gaf, tteh, ddal, rreh, noon-ghunna, heh-doachashmee, farsi
# yeh, yeh-barree. Their presence is the only cheap way to tell "ur" from "ar",
# since both languages share one Unicode block.
_URDU_ONLY = re.compile(
    r"[\u067E\u0686\u0698\u06A9\u06AF\u0679\u0688\u0691"
    r"\u06BA\u06BB\u06BE\u06C1\u06C2\u06C3\u06CC\u06D2]"
)
# Teh marbuta, alef maqsura, and hamza forms are strongly Arabic, not Urdu.
_ARABIC_ONLY = re.compile(r"[\u0622\u0623\u0625\u0629\u0649\u0624\u0626]")

_SPEAKER_RE = re.compile(r"^(?P<name>[^\s:][^:]{0,40})\s*:\s*(?P<body>.+)$")
# Sentence terminators across the four supported scripts.
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?۔؟।])\s+")

# Canned replies the chatbot may need in the user's own language. Machine
# translating a fixed string on every miss would be slower and less accurate.
NOT_IN_TRANSCRIPT: dict[str, str] = {
    "en": "Not mentioned in the transcript.",
    "ur": "یہ بات ٹرانسکرپٹ میں موجود نہیں ہے۔",
    "ar": "غير مذكور في النص.",
    "hi": "यह ट्रांसक्रिप्ट में मौजूद नहीं है।",
}


def normalize_code(code: str | None, default: str = DEFAULT_LANGUAGE) -> str:
    """Coerce anything the client sends ('ur-PK', 'Urdu', None) to an ISO code."""
    if not code:
        return default
    value = str(code).strip().lower().replace("_", "-")
    if not value:
        return default
    if value in SUPPORTED:
        return value
    head = value.split("-")[0]
    if head in SUPPORTED:
        return head
    by_name = {
        str(meta["name"]).lower(): iso for iso, meta in languages.LANGUAGES.items()
    }
    return by_name.get(value, default)


def detect_language(text: str, default: str = DEFAULT_LANGUAGE) -> str:
    """Best-effort script based detection across the four supported languages."""
    if not text:
        return default

    arabic = len(_ARABIC_SCRIPT.findall(text))
    devanagari = len(_DEVANAGARI.findall(text))
    latin = len(_LATIN.findall(text))

    if devanagari and devanagari >= arabic and devanagari >= latin:
        return "hi"
    if arabic and arabic >= latin:
        has_urdu = bool(_URDU_ONLY.search(text))
        has_arabic = bool(_ARABIC_ONLY.search(text))
        if has_urdu and not has_arabic:
            return "ur"
        if has_arabic and not has_urdu:
            return "ar"
        # Same script, weak discriminator: trust the room, else Urdu
        # (this product is Pakistan-first; defaulting to Arabic was tagging
        # meeting Urdu as "ar" and sending it through the wrong Opus pair).
        if default in {"ur", "ar"}:
            return default
        return "ur"
    if latin:
        return "en"
    return default


def parse_transcript(transcript: str, default_language: str = DEFAULT_LANGUAGE) -> list[dict]:
    """Turn a plain ``Name: text`` transcript into per-line entries.

    Used when the client could not send structured utterances (older app
    builds, the manually pasted transcript box, or the sample transcript).
    """
    entries: list[dict] = []
    for raw in (transcript or "").splitlines():
        line = raw.strip()
        if not line:
            continue
        match = _SPEAKER_RE.match(line)
        speaker, body = (
            (match.group("name").strip(), match.group("body").strip())
            if match
            else ("Speaker", line)
        )
        if not body:
            continue
        entries.append(
            {
                "speaker": speaker,
                "text": body,
                "lang": detect_language(body, default=default_language),
            }
        )
    return entries


def normalize_entries(
    entries: list[dict],
    default_language: str = DEFAULT_LANGUAGE,
) -> list[dict]:
    """Fill in missing/invalid speaker and language fields."""
    cleaned: list[dict] = []
    for entry in entries or []:
        text = str(entry.get("text") or "").strip()
        if not text:
            continue
        lang = normalize_code(entry.get("lang"), default=default_language)
        # A caption tagged 'en' that is plainly Urdu script (mis-set language
        # picker) would otherwise be fed to the wrong Opus pair.
        detected = detect_language(text, default=lang)
        if detected != lang and detected != "en":
            lang = detected
        cleaned.append(
            {
                "speaker": str(entry.get("speaker") or "Speaker").strip() or "Speaker",
                "text": text,
                "lang": lang,
            }
        )
    return cleaned


def to_language(texts: list[str], source: str, target: str) -> list[str]:
    """Translate a list of same-language strings, never raising."""
    if not texts:
        return []
    source = normalize_code(source)
    target = normalize_code(target)
    if source == target:
        return list(texts)

    from app.services import translation

    try:
        return translation.translate_batch(texts, source, target)
    except Exception as exc:  # noqa: BLE001 - degraded output beats a 500
        print(f"[multilingual] {source}->{target} translation failed ({exc})")
        return list(texts)


def entries_to_english(entries: list[dict]) -> list[dict]:
    """Translate every entry into English, grouping calls by source language."""
    if not entries:
        return []

    by_lang: dict[str, list[int]] = {}
    for index, entry in enumerate(entries):
        by_lang.setdefault(entry["lang"], []).append(index)

    english = [dict(entry) for entry in entries]
    for lang, indexes in by_lang.items():
        if lang == "en":
            continue
        translated = to_language([entries[i]["text"] for i in indexes], lang, "en")
        for i, text in zip(indexes, translated):
            if text.strip():
                english[i]["text"] = text.strip()
        print(f"[multilingual] normalized {len(indexes)} line(s) {lang}->en")
    return english


def render_transcript(entries: list[dict]) -> str:
    """Render entries back into the ``Name: text`` form the prompts expect."""
    return "\n".join(f"{entry['speaker']}: {entry['text']}" for entry in entries)


def english_transcript(
    transcript: str | None,
    utterances: list[dict] | None = None,
    default_language: str = DEFAULT_LANGUAGE,
) -> tuple[str, list[dict]]:
    """Return ``(english_transcript, original_entries)`` for the LLM stages."""
    entries = (
        normalize_entries(utterances, default_language)
        if utterances
        else parse_transcript(transcript or "", default_language)
    )
    if not entries:
        return (transcript or "").strip(), []
    return render_transcript(entries_to_english(entries)), entries


def dominant_language(entries: list[dict], default: str = DEFAULT_LANGUAGE) -> str:
    """The language most characters were spoken in — used as an output default."""
    weights: dict[str, int] = {}
    for entry in entries:
        weights[entry["lang"]] = weights.get(entry["lang"], 0) + len(entry["text"])
    if not weights:
        return default
    return max(weights.items(), key=lambda item: item[1])[0]


def localize(text: str, target: str, names: Iterable[str] = ()) -> str:
    """Translate one English string into the user's language."""
    if not text.strip():
        return text
    return localize_many([text], target, names)[0]


def localize_many(
    texts: list[str],
    target: str,
    names: Iterable[str] = (),
) -> list[str]:
    """Translate English strings into the user's language, keeping order.

    Speaker names are held out of the translation. Opus-MT has no way to copy
    an unknown proper noun through: measured on this repo, "Bilal will finish
    the payment module" comes back attributing the task to a different person
    entirely, and no sentinel token survives the en->ur model (it even rewrites
    Latin digits as Urdu-Indic ones). Splitting the name off is the only way to
    keep attribution correct.
    """
    if not texts:
        return []
    target = normalize_code(target)
    if target == "en":
        return list(texts)

    name_re = _names_pattern(names)
    name_only_re = _name_only_pattern(names)

    # One entry per sentence: (text index, name prefix, separator, body).
    # ``body`` is None for a sentence that is just a name — "Bilal." is a
    # complete chatbot answer and must not be handed to the translator.
    parts: list[tuple[int, str | None, str, str | None]] = []
    for index, text in enumerate(texts):
        for sentence in _split_sentences(text):
            if name_only_re is not None and name_only_re.match(sentence):
                parts.append((index, sentence, "", None))
                continue
            name, separator, body = _split_leading_name(sentence, name_re)
            parts.append((index, name, separator, body))

    bodies = [body for _, _, _, body in parts if body is not None]
    translated = iter(to_language(bodies, "en", target))

    rebuilt: list[list[str]] = [[] for _ in texts]
    for index, name, separator, body in parts:
        if body is None:
            rebuilt[index].append(name or "")
            continue
        new_body = next(translated, "").strip() or body
        rebuilt[index].append(f"{name}{separator}{new_body}" if name else new_body)

    # Never let a failed line blank out a bullet the user should see.
    return [
        " ".join(pieces).strip() or original
        for original, pieces in zip(texts, rebuilt)
    ]


def _name_alternation(names: Iterable[str]) -> str | None:
    """Regex alternation of speaker names, longest first so 'Ali Raza' beats 'Ali'."""
    unique = sorted(
        {n.strip() for n in names if n and n.strip() and n.strip() != "Speaker"},
        key=len,
        reverse=True,
    )
    if not unique:
        return None
    return "|".join(re.escape(n) for n in unique)


def _names_pattern(names: Iterable[str]) -> re.Pattern[str] | None:
    alternation = _name_alternation(names)
    if alternation is None:
        return None
    return re.compile(
        rf"^({alternation})(\s*[:,\-–—]\s*|\s+)(.+)$",
        re.IGNORECASE | re.DOTALL,
    )


def _name_only_pattern(names: Iterable[str]) -> re.Pattern[str] | None:
    """Matches a sentence that carries nothing but a speaker name."""
    alternation = _name_alternation(names)
    if alternation is None:
        return None
    return re.compile(rf"^\W*({alternation})\W*$", re.IGNORECASE)


def _split_leading_name(
    sentence: str,
    name_re: re.Pattern[str] | None,
) -> tuple[str | None, str, str]:
    """Split ``"Bilal: ship it"`` into ``("Bilal", ": ", "ship it")``."""
    if name_re is None:
        return None, "", sentence
    match = name_re.match(sentence.strip())
    if not match:
        return None, "", sentence
    separator = ": " if ":" in match.group(2) else " "
    return match.group(1), separator, match.group(3).strip()


def _split_sentences(text: str) -> list[str]:
    parts = [p.strip() for p in _SENTENCE_SPLIT_RE.split(text.strip()) if p.strip()]
    return parts or [text.strip()]


def not_in_transcript(language: str) -> str:
    return NOT_IN_TRANSCRIPT.get(normalize_code(language), NOT_IN_TRANSCRIPT["en"])


def mostly_in_language(text: str, language: str) -> bool:
    """True when ``text`` is written in the expected script.

    Used after Opus-MT: if en→ur silently copies the English source, the
    summary/chatbot must not pretend the user's language was produced.
    """
    language = normalize_code(language)
    sample = (text or "").strip()
    if not sample:
        return True
    if language == "en":
        return bool(_LATIN.search(sample))
    if language in {"ur", "ar"}:
        return bool(_ARABIC_SCRIPT.search(sample))
    if language == "hi":
        return bool(_DEVANAGARI.search(sample))
    return True


def to_english(text: str, hint: str = DEFAULT_LANGUAGE) -> str:
    """Translate ``text`` into English using the script it is actually in.

    The meeting picker language is only a hint. An Urdu user who types an
    English chatbot question must not run that English through opus-mt-ur-en
    (that is how mixed-language Q&A used to come back as garbage).
    """
    sample = (text or "").strip()
    if not sample:
        return sample
    source = detect_language(sample, default=normalize_code(hint))
    if source == "en":
        return sample
    out = to_language([sample], source, "en")[0].strip()
    return out or sample
