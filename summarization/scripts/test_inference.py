"""Local inference smoke-test for summarization (before API wiring).

Run from repo root:
    python summarization/scripts/test_inference.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from summarization.scripts.parse_output import parse_summary_output  # noqa: E402

SAMPLE = ROOT / "summarization" / "samples" / "sample_transcript.txt"
PROMPT_FILE = ROOT / "summarization" / "prompts" / "meeting_summary.txt"


def main() -> None:
    transcript = SAMPLE.read_text(encoding="utf-8")
    prompt_template = PROMPT_FILE.read_text(encoding="utf-8")
    prompt = prompt_template.format(transcript=transcript)

    print("Loading summarization model (this may take a while)...")
    from app.services.summarization import summarize_transcript

    result = summarize_transcript(transcript)
    parsed = parse_summary_output(result.get("raw", ""))

    print("\n=== SUMMARY ===")
    print(parsed["summary"])
    print("\n=== KEY POINTS ===")
    for p in parsed["key_points"]:
        print("-", p)
    print("\n=== ACTION ITEMS ===")
    for a in parsed["action_items"]:
        print("-", a)


if __name__ == "__main__":
    main()
