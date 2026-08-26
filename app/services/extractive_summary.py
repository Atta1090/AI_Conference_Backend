"""Deterministic meeting summary when Gemma cannot run (OOM / empty output).

Built for the laptop demo path: 8 GB RAM often cannot keep Whisper + Opus-MT
+ Gemma resident at once. Rather than show a blank Summary screen, we derive
an overview, key points and action items from the transcript text itself.

Everything here is script-aware: the same laptop that cannot run Gemma is the
one that most needs Urdu/Arabic/Hindi summaries to still come out readable.
"""

from __future__ import annotations

import re

# Speaker labels can be Urdu/Arabic/Hindi names, so match any non-colon run
# rather than an ASCII capitalised word.
_SPEAKER_RE = re.compile(r"^(?P<name>[^\s:][^:]{0,40})\s*:\s*(?P<body>.+)$")

# Sentence terminators across the four supported scripts (Urdu ۔, Arabic ؟,
# Devanagari ।) so a label-less paragraph still splits correctly.
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?۔؟।])\s+")

_ACTION_PATTERNS: dict[str, re.Pattern[str]] = {
    "en": re.compile(
        r"\b(i will|i'll|i can|will|shall|need to|needs to|must|"
        r"please|let'?s|due|by (?:monday|tuesday|wednesday|thursday|"
        r"friday|saturday|sunday|tomorrow|tonight|next week))\b",
        re.I,
    ),
    "ur": re.compile(
        r"(کروں گا|کروں گی|کریں گے|کرنا ہے|کرنا ہوگا|چاہیے|ضروری ہے|"
        r"براہ کرم|آئیے|کل|پیر|منگل|بدھ|جمعرات|جمعہ|ہفتے|اتوار|آخری تاریخ)"
    ),
    "ar": re.compile(
        r"(سوف|سأ|يجب|ينبغي|من فضلك|لنبدأ|غدا|غدًا|الاثنين|الثلاثاء|"
        r"الأربعاء|الخميس|الجمعة|السبت|الأحد|الموعد النهائي)"
    ),
    "hi": re.compile(
        r"(करूंगा|करूंगी|करेंगे|करना है|करना होगा|चाहिए|जरूरी है|कृपया|"
        r"चलिए|कल|सोमवार|मंगलवार|बुधवार|गुरुवार|शुक्रवार|शनिवार|रविवार|"
        r"अंतिम तिथि)"
    ),
}

# "Meeting with <who>." for the overview line.
_OVERVIEW_PREFIX: dict[str, str] = {
    "en": "Meeting with {who}.",
    "ur": "میٹنگ میں شامل: {who}۔",
    "ar": "اجتماع مع {who}.",
    "hi": "बैठक में शामिल: {who}।",
}

_EMPTY_OVERVIEW: dict[str, str] = {
    "en": "Meeting transcript captured; see key points below.",
    "ur": "میٹنگ کی ٹرانسکرپٹ محفوظ ہو گئی؛ اہم نکات نیچے دیکھیں۔",
    "ar": "تم تسجيل نص الاجتماع؛ انظر النقاط الرئيسية أدناه.",
    "hi": "बैठक का ट्रांसक्रिप्ट सहेजा गया; मुख्य बिंदु नीचे देखें।",
}


def _is_action(body: str, language: str) -> bool:
    """True when a turn reads like a commitment or a deadline.

    Both the transcript language and English are checked: mixed meetings leave
    English fragments inside otherwise Urdu lines.
    """
    for code in {language, "en"}:
        pattern = _ACTION_PATTERNS.get(code)
        if pattern and pattern.search(body):
            return True
    return False


def _lines(transcript: str) -> list[tuple[str, str]]:
    """Return ``(speaker, body)`` pairs; anonymous lines use ``Speaker``."""
    out: list[tuple[str, str]] = []
    for raw in transcript.splitlines():
        line = raw.strip()
        if not line:
            continue
        match = _SPEAKER_RE.match(line)
        if match:
            out.append((match.group("name").strip(), match.group("body").strip()))
        else:
            out.append(("Speaker", line))
    if out:
        return out

    # Single paragraph with no speaker labels — split into sentences.
    parts = _SENTENCE_SPLIT_RE.split(transcript.strip())
    return [("Speaker", p.strip()) for p in parts if p.strip()]


def _truncate(value: str, limit: int) -> str:
    if len(value) <= limit:
        return value
    head = value[: limit - 3]
    # Urdu/Arabic/Hindi lines may have no spaces to cut on; fall back to a hard
    # cut rather than returning the whole line.
    if " " in head:
        head = head.rsplit(" ", 1)[0]
    return head + "…"


def extractive_summary(transcript: str, language: str = "en") -> dict:
    """Build a usable summary dict without calling an LLM."""
    from app.services import multilingual

    text = (transcript or "").strip()
    if not text:
        return {"summary": "", "key_points": [], "action_items": [], "raw": ""}

    language = multilingual.normalize_code(language, default="en")
    turns = _lines(text)
    speakers = sorted({name for name, _ in turns if name != "Speaker"})

    # Overview: who spoke and the first couple of substantive lines.
    lead = _truncate(" ".join(body for _, body in turns[:3]).strip(), 320)
    if speakers:
        who = ", ".join(speakers[:5])
        prefix = _OVERVIEW_PREFIX.get(language, _OVERVIEW_PREFIX["en"]).format(who=who)
        summary = f"{prefix} {lead}".strip()
    else:
        summary = lead or _EMPTY_OVERVIEW.get(language, _EMPTY_OVERVIEW["en"])

    # Key points: one short line per early turn, de-duplicated.
    key_points: list[str] = []
    seen: set[str] = set()
    for name, body in turns:
        point = body if name == "Speaker" else f"{name}: {body}"
        point = _truncate(point, 160)
        marker = point.lower()
        if marker in seen:
            continue
        seen.add(marker)
        key_points.append(point)
        if len(key_points) >= 8:
            break

    # Action items: turns that look like commitments / deadlines.
    action_items: list[str] = []
    for name, body in turns:
        if not _is_action(body, language):
            continue
        item = _truncate(body if name == "Speaker" else f"{name}: {body}", 160)
        marker = item.lower()
        if marker in seen and item in key_points:
            # Prefer keeping it as an action item over a key point.
            key_points = [k for k in key_points if k.lower() != marker]
        if marker not in {a.lower() for a in action_items}:
            action_items.append(item)
        if len(action_items) >= 6:
            break

    raw = (
        "SUMMARY:\n"
        f"{summary}\n\n"
        "KEY_POINTS:\n"
        + ("\n".join(f"- {p}" for p in key_points) or "- None")
        + "\n\nACTION_ITEMS:\n"
        + ("\n".join(f"- {a}" for a in action_items) or "- None")
    )

    return {
        "summary": summary,
        "key_points": key_points,
        "action_items": action_items,
        "raw": raw,
    }
