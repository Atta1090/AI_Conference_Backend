"""Convert raw datasets into Gemma 3 instruction-tuning JSONL.

Output format (one JSON object per line):
{
  "instruction": "...",
  "input": "<transcript>",
  "output": "SUMMARY:\\n...\\nKEY_POINTS:\\n- ...\\nACTION_ITEMS:\\n- ..."
}

Run:
    python summarization/scripts/prepare_training_data.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "summarization" / "data" / "raw"
OUT_DIR = ROOT / "summarization" / "data" / "processed"
OUT_DIR.mkdir(parents=True, exist_ok=True)

INSTRUCTION = (
    "Summarize the meeting transcript. Return SUMMARY, KEY_POINTS, and ACTION_ITEMS."
)


def _extract_key_sentences(text: str, max_points: int = 5) -> list[str]:
    """Split summary into individual key-point bullets."""
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    return [s.strip() for s in sentences if len(s.strip()) > 10][:max_points]


def _wrap_summary(summary: str) -> str:
    """Map plain summary into structured SUMMARY / KEY_POINTS / ACTION_ITEMS."""
    summary = summary.strip()
    key_points = _extract_key_sentences(summary)
    kp_block = "\n".join(f"- {kp}" for kp in key_points) if key_points else f"- {summary}"

    return (
        "SUMMARY:\n"
        f"{summary}\n\n"
        "KEY_POINTS:\n"
        f"{kp_block}\n\n"
        "ACTION_ITEMS:\n"
        "- None"
    )


def _read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows: list[dict] = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def build_processed() -> None:
    merged: list[dict] = []

    for name in sorted(RAW_DIR.glob("*.jsonl")):
        for row in _read_jsonl(name):
            text_in = (row.get("input_text") or "").strip()
            text_out = (row.get("target_text") or "").strip()
            if not text_in or not text_out:
                continue
            merged.append(
                {
                    "instruction": INSTRUCTION,
                    "input": text_in,
                    "output": _wrap_summary(text_out),
                    "source": row.get("source", name.stem),
                }
            )

    out_path = OUT_DIR / "train_meeting_summary.jsonl"
    with out_path.open("w", encoding="utf-8") as f:
        for row in merged:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    print(f"Wrote {len(merged)} training rows -> {out_path}")


if __name__ == "__main__":
    build_processed()
