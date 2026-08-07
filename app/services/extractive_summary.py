"""Deterministic meeting summary when Gemma cannot run (OOM / empty output).

Built for the laptop demo path: 8 GB RAM often cannot keep Whisper + Opus-MT
+ Gemma resident at once. Rather than show a blank Summary screen, we derive
an overview, key points and action items from the transcript text itself.
"""

from __future__ import annotations

import re

_SPEAKER_RE = re.compile(
    r"^(?P<name>[A-Z][\w .'-]{0,30})\s*:\s*(?P<body>.+)$"
)
_ACTION_RE = re.compile(
    r"\b(i will|i'll|i can|will|shall|need to|needs to|must|"
    r"please|let'?s|due|by (?:monday|tuesday|wednesday|thursday|"
    r"friday|saturday|sunday|tomorrow|tonight|next week))\b",
    re.I,
)


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
    parts = re.split(r"(?<=[.!?])\s+", transcript.strip())
    return [("Speaker", p.strip()) for p in parts if p.strip()]


def extractive_summary(transcript: str) -> dict:
    """Build a usable summary dict without calling an LLM."""
    text = (transcript or "").strip()
    if not text:
        return {"summary": "", "key_points": [], "action_items": [], "raw": ""}

    turns = _lines(text)
    speakers = sorted({name for name, _ in turns if name != "Speaker"})

    # Overview: who spoke and the first couple of substantive lines.
    lead = " ".join(body for _, body in turns[:3]).strip()
    if len(lead) > 320:
        lead = lead[:317].rsplit(" ", 1)[0] + "…"
    if speakers:
        who = ", ".join(speakers[:5])
        summary = f"Meeting with {who}. {lead}"
    else:
        summary = lead or "Meeting transcript captured; see key points below."

    # Key points: one short line per early turn, de-duplicated.
    key_points: list[str] = []
    seen: set[str] = set()
    for name, body in turns:
        point = body if name == "Speaker" else f"{name}: {body}"
        if len(point) > 160:
            point = point[:157].rsplit(" ", 1)[0] + "…"
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
        if not _ACTION_RE.search(body):
            continue
        item = body if name == "Speaker" else f"{name}: {body}"
        if len(item) > 160:
            item = item[:157].rsplit(" ", 1)[0] + "…"
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
