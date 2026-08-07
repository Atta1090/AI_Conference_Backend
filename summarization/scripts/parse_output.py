"""Parse summarization model output into API fields.

Small instruction-tuned models rarely reproduce a requested layout exactly:
they wrap headings in markdown, rename ``KEY_POINTS`` to ``Key Points``,
prefix everything with ``Answer:``, or skip headings altogether and just emit
prose followed by bullets. The parser therefore recognises the intended
layout when it is present and falls back to shape-based detection (prose =
summary, bullets = key points) when it is not, so the UI is never handed
three empty sections.
"""

from __future__ import annotations

import re

# Heading spellings we accept for each output field.
_HEADER_ALIASES: dict[str, tuple[str, ...]] = {
    "summary": ("summary", "overview", "meeting summary", "abstract", "tldr"),
    "key_points": (
        "key points",
        "keypoints",
        "main points",
        "highlights",
        "discussion points",
        "points",
    ),
    "action_items": (
        "action items",
        "actionitems",
        "action",
        "next steps",
        "tasks",
        "todos",
        "to do",
    ),
}

# Wrappers the model adds around the real answer; they carry no section meaning.
_IGNORED_LABELS = frozenset(
    {"answer", "response", "output", "result", "assistant", "model", "note"}
)

_BULLET_RE = re.compile(r"^\s*(?:[-*•·–—]|\d+[.)])\s+")
_HEADER_RE = re.compile(r"^([A-Za-z][A-Za-z _\-]{1,30})\s*[:\-]\s*(.*)$")

# Fragments of the prompt template itself, echoed back verbatim.
_PLACEHOLDER_PATTERNS = (
    re.compile(r"<[^>]{3,}>"),
    re.compile(r"\bone short point per line\b", re.I),
    re.compile(r"\b(two|2) to (four|4) sentences\b", re.I),
    re.compile(r"^owner\s*:\s*task\b", re.I),
    re.compile(r"\bdue\s*:\s*date or tbd\b", re.I),
    re.compile(r"^transcript\s*:?\s*$", re.I),
    re.compile(r"\buse only information from the transcript\b", re.I),
    re.compile(r"\breply in exactly this layout\b", re.I),
)

_EMPTY_VALUES = frozenset({"none", "n/a", "na", "-", "none.", "no action items"})


def _normalise_label(label: str) -> str:
    label = label.strip().lower().replace("_", " ").replace("-", " ")
    return re.sub(r"\s+", " ", label)


def _clean_line(line: str) -> str:
    """Drop markdown decoration so headings and bullets are comparable."""
    line = line.strip()
    line = re.sub(r"^[>#\s]+", "", line)
    line = line.replace("**", "").replace("__", "")
    line = re.sub(r"^\*(?!\s)|(?<!\s)\*$", "", line)
    return line.strip()


def _is_placeholder(line: str) -> bool:
    return any(pattern.search(line) for pattern in _PLACEHOLDER_PATTERNS)


def _is_bullet(line: str) -> bool:
    return bool(_BULLET_RE.match(line))


def _strip_bullet(line: str) -> str:
    return _BULLET_RE.sub("", line, count=1).strip()


def _lookup_section(label: str) -> str | None:
    for key, aliases in _HEADER_ALIASES.items():
        if label in aliases or label == key.replace("_", " "):
            return key
    return None


def _match_header(line: str) -> tuple[str | None, str, bool]:
    """Return ``(section_key, trailing_text, is_ignored_wrapper)``."""
    # A heading alone on its line, with no colon: "**Key Points**", "Summary".
    bare = _normalise_label(line.rstrip(": ").strip())
    if bare in _IGNORED_LABELS:
        return None, "", True
    bare_key = _lookup_section(bare)
    if bare_key is not None:
        return bare_key, "", False

    match = _HEADER_RE.match(line)
    if not match:
        return None, "", False

    label = _normalise_label(match.group(1))
    rest = match.group(2).strip()

    if label in _IGNORED_LABELS:
        return None, rest, True
    key = _lookup_section(label)
    if key is not None:
        return key, rest, False
    return None, "", False


def _split_sections(text: str) -> tuple[dict[str, list[str]], list[str]]:
    sections: dict[str, list[str]] = {
        "summary": [],
        "key_points": [],
        "action_items": [],
    }
    loose: list[str] = []
    current: str | None = None

    for raw_line in text.splitlines():
        line = _clean_line(raw_line)
        if not line or _is_placeholder(line):
            continue

        key, rest, ignored = _match_header(line)
        if ignored:
            # e.g. "Answer:" — keep any trailing text, but start no section.
            current = None
            if rest and not _is_placeholder(rest):
                loose.append(rest)
            continue
        if key is not None:
            current = key
            if rest and not _is_placeholder(rest):
                sections[key].append(rest)
            continue

        (loose if current is None else sections[current]).append(line)

    return sections, loose


def _clean_items(lines: list[str]) -> list[str]:
    """Bullet lines -> deduplicated list of plain strings."""
    items: list[str] = []
    seen: set[str] = set()
    for line in lines:
        value = _strip_bullet(line) if _is_bullet(line) else line.strip()
        value = value.strip(" .;")
        if not value or value.lower() in _EMPTY_VALUES:
            continue
        marker = value.lower()
        if marker in seen:
            continue
        seen.add(marker)
        items.append(value)
    return items


def _partition(lines: list[str]) -> tuple[list[str], list[str]]:
    """Split unlabelled output into prose lines and bullet lines."""
    prose: list[str] = []
    bullets: list[str] = []
    for line in lines:
        (bullets if _is_bullet(line) else prose).append(line)
    return prose, bullets


def parse_summary_output(text: str) -> dict:
    """Extract ``summary``, ``key_points`` and ``action_items`` from model text."""
    text = (text or "").strip()
    if not text:
        return {"summary": "", "key_points": [], "action_items": [], "raw": text}

    sections, loose = _split_sections(text)

    summary_lines = [line for line in sections["summary"] if not _is_bullet(line)]
    summary_bullets = [line for line in sections["summary"] if _is_bullet(line)]
    key_points = _clean_items(sections["key_points"])
    action_items = _clean_items(sections["action_items"])

    loose_prose, loose_bullets = _partition(loose)

    # No SUMMARY heading: the leading prose is the summary.
    if not summary_lines:
        summary_lines = loose_prose
        loose_prose = []

    # No KEY_POINTS heading: any remaining bullets are the key points. We do
    # not try to guess which of them are action items — misfiling a genuine
    # key point is worse than leaving Action Items empty.
    if not key_points:
        key_points = _clean_items(summary_bullets + loose_bullets)
        loose_bullets = []

    summary = " ".join(line.strip() for line in summary_lines).strip()
    if not summary:
        # Prose-free output: build a readable overview from the bullets.
        summary = " ".join(key_points[:3]).strip()
    if not summary:
        leftovers = _clean_items(loose_prose + loose_bullets)
        summary = " ".join(leftovers).strip()

    return {
        "summary": summary,
        "key_points": key_points,
        "action_items": action_items,
        "raw": text,
    }
