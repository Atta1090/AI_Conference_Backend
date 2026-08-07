"""Download summarization datasets into summarization/data/raw.

Run from repo root:
    python summarization/scripts/download_datasets.py
"""

from __future__ import annotations

import json
from pathlib import Path

from datasets import load_dataset

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "summarization" / "data" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)


def save_jsonl(rows: list[dict], path: Path) -> None:
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"Saved {len(rows)} rows -> {path}")


def download_samsum() -> None:
    print("Downloading SAMSum...")
    ds = load_dataset("knkarthick/samsum")
    for split in ds:
        rows = [
            {
                "id": ex["id"],
                "source": "samsum",
                "input_text": ex["dialogue"],
                "target_text": ex["summary"],
            }
            for ex in ds[split]
        ]
        save_jsonl(rows, RAW_DIR / f"samsum_{split}.jsonl")


def download_qmsum() -> None:
    """Try Hugging Face mirror first; print manual fallback if missing."""
    print("Downloading QMSum (HF mirror if available)...")
    try:
        ds = load_dataset("knkarthick/QMSum")
        for split in ds:
            rows = []
            for ex in ds[split]:
                rows.append(
                    {
                        "id": ex.get("id", ""),
                        "source": "qmsum",
                        "input_text": ex.get("meeting_transcript", ex.get("transcript", "")),
                        "target_text": ex.get("summary", ""),
                        "query": ex.get("query", ""),
                    }
                )
            save_jsonl(rows, RAW_DIR / f"qmsum_{split}.jsonl")
    except Exception as exc:  # noqa: BLE001
        print(
            "QMSum HF load failed. Manual download:\n"
            "  https://github.com/Yale-LILY/QMSum\n"
            f"  Reason: {exc}"
        )


if __name__ == "__main__":
    download_samsum()
    download_qmsum()
    print("Done.")
