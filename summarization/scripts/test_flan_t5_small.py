"""
Smoke-test a trained FLAN-T5-small meeting summarizer (no Gemma).

Usage:
  python summarization/scripts/test_flan_t5_small.py
  python summarization/scripts/test_flan_t5_small.py --text "Alice: We ship Friday..."
"""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "summarization" / "models" / "flan-t5-small-meeting"
BASE = "google/flan-t5-small"
PROMPT = (ROOT / "summarization" / "prompts" / "meeting_summary.txt").read_text(
    encoding="utf-8"
)
SAMPLE = (ROOT / "summarization" / "samples" / "sample_transcript.txt")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", default="")
    args = parser.parse_args()

    transcript = args.text.strip()
    if not transcript and SAMPLE.exists():
        transcript = SAMPLE.read_text(encoding="utf-8")
    if not transcript:
        raise SystemExit("Provide --text or add summarization/samples/sample_transcript.txt")

    device = "cuda" if torch.cuda.is_available() else "cpu"
    tokenizer = AutoTokenizer.from_pretrained(
        str(MODEL_DIR) if MODEL_DIR.exists() else BASE
    )
    model = AutoModelForSeq2SeqLM.from_pretrained(BASE)
    if (MODEL_DIR / "adapter_config.json").exists():
        model = PeftModel.from_pretrained(model, str(MODEL_DIR))
        print(f"Loaded LoRA from {MODEL_DIR}")
    elif MODEL_DIR.exists() and (MODEL_DIR / "config.json").exists():
        model = AutoModelForSeq2SeqLM.from_pretrained(str(MODEL_DIR))
        print(f"Loaded full model from {MODEL_DIR}")
    else:
        print("No fine-tuned weights found — using base FLAN-T5-small")

    model.to(device).eval()
    source = PROMPT.format(transcript=transcript)
    inputs = tokenizer(source, return_tensors="pt", truncation=True, max_length=512)
    inputs = {k: v.to(device) for k, v in inputs.items()}
    with torch.no_grad():
        out = model.generate(**inputs, max_new_tokens=256, num_beams=4)
    print(tokenizer.decode(out[0], skip_special_tokens=True))


if __name__ == "__main__":
    main()
