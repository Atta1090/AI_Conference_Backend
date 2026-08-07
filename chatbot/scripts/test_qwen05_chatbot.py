"""
Smoke-test a trained Qwen2.5-0.5B chatbot LoRA (no Gemma).

Usage:
  python chatbot/scripts/test_qwen05_chatbot.py
"""

from __future__ import annotations

from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

ROOT = Path(__file__).resolve().parents[2]
ADAPTER = ROOT / "chatbot" / "models" / "qwen25-05b-chatbot-lora"
BASE = "Qwen/Qwen2.5-0.5B-Instruct"
PROMPT = (ROOT / "chatbot" / "prompts" / "qa_prompt.txt").read_text(encoding="utf-8")

SAMPLE_TRANSCRIPT = """
Alice: We need to finish the backend by Friday.
Bob: I will handle the deployment.
Alice: Great, let's sync Monday at 10 AM. Sara will handle design.
""".strip()


def main() -> None:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    tokenizer = AutoTokenizer.from_pretrained(BASE, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    dtype = torch.float16 if device == "cuda" else torch.float32
    model = AutoModelForCausalLM.from_pretrained(
        BASE, torch_dtype=dtype, trust_remote_code=True
    )
    if (ADAPTER / "adapter_config.json").exists():
        model = PeftModel.from_pretrained(model, str(ADAPTER))
        print(f"Loaded LoRA from {ADAPTER}")
    else:
        print("No adapter found — using base Qwen2.5-0.5B-Instruct")

    model.to(device).eval()
    question = "Who will handle design?"
    user = PROMPT.format(transcript=SAMPLE_TRANSCRIPT, question=question)
    messages = [{"role": "user", "content": user}]
    text = tokenizer.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=True
    )
    inputs = tokenizer(text, return_tensors="pt").to(device)
    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=128,
            do_sample=False,
            pad_token_id=tokenizer.pad_token_id,
        )
    gen = out[0][inputs["input_ids"].shape[-1] :]
    print(tokenizer.decode(gen, skip_special_tokens=True).strip())


if __name__ == "__main__":
    main()
