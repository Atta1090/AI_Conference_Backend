"""
Fine-tune Qwen2.5-0.5B-Instruct as a meeting transcript Q&A chatbot
(lighter than Gemma-3-1B).

Builds training rows online from SamSum (+ optional SQuAD), same idea as the
Gemma chatbot notebook, but saves a separate adapter:

  chatbot/models/qwen25-05b-chatbot-lora/

Colab / GPU quick start
-----------------------
  !pip install -q transformers peft datasets accelerate trl bitsandbytes
  !python chatbot/colab/train_qwen05_chatbot.py

This does NOT replace Gemma training. It is a separate lighter path.
"""

from __future__ import annotations

import random
from pathlib import Path

import torch
import yaml
from datasets import Dataset, load_dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    TrainingArguments,
)
from trl import SFTTrainer

try:
    from trl import SFTConfig
except ImportError:  # older trl
    SFTConfig = None

ROOT = Path(__file__).resolve().parents[2]
CFG = yaml.safe_load(
    (ROOT / "chatbot" / "config_qwen05.yaml").read_text(encoding="utf-8")
)
OUT_DIR = ROOT / CFG["adapter_path"]
PROMPT_TEMPLATE = (ROOT / "chatbot" / "prompts" / "qa_prompt.txt").read_text(
    encoding="utf-8"
)

QUESTION_BANK = [
    "What was discussed?",
    "What are the main points?",
    "What decisions were made?",
    "What are the next steps?",
    "Who is responsible for follow-up?",
    "When is the next meeting?",
    "What problems were mentioned?",
    "Summarize the conversation briefly.",
]


def _clip(text: str, max_chars: int = 1800) -> str:
    text = (text or "").strip()
    if len(text) <= max_chars:
        return text
    return text[: max_chars - 3] + "..."


def _build_prompt(transcript: str, question: str) -> str:
    return PROMPT_TEMPLATE.format(
        transcript=_clip(transcript),
        question=question.strip(),
    )


def _samsum_rows(max_rows: int) -> list[dict]:
    ds = load_dataset(CFG["datasets"]["dialogue"], split="train")
    rows: list[dict] = []
    for ex in ds:
        dialogue = (ex.get("dialogue") or "").strip()
        summary = (ex.get("summary") or "").strip()
        if len(dialogue) < 40 or len(summary) < 10:
            continue
        q = random.choice(QUESTION_BANK)
        # Grounded answer from the dialogue summary.
        rows.append(
            {
                "transcript": dialogue,
                "question": q,
                "answer": summary,
            }
        )
        if len(rows) >= max_rows:
            break
    return rows


def _squad_rows(max_rows: int) -> list[dict]:
    name = CFG["datasets"].get("squad")
    if not name or max_rows <= 0:
        return []
    ds = load_dataset(name, split="train")
    rows: list[dict] = []
    for ex in ds:
        context = (ex.get("context") or "").strip()
        question = (ex.get("question") or "").strip()
        answers = ex.get("answers") or {}
        texts = answers.get("text") or []
        if not context or not question or not texts:
            continue
        answer = texts[0].strip()
        if not answer:
            continue
        rows.append(
            {
                "transcript": context,
                "question": question,
                "answer": answer,
            }
        )
        # Negative / not-mentioned examples help the model refuse.
        if len(rows) % 5 == 0:
            rows.append(
                {
                    "transcript": context,
                    "question": "What is the company's IPO date?",
                    "answer": "Not mentioned in the transcript.",
                }
            )
        if len(rows) >= max_rows:
            break
    return rows


def _to_chat_text(tokenizer, row: dict) -> str:
    user = _build_prompt(row["transcript"], row["question"])
    messages = [
        {"role": "user", "content": user},
        {"role": "assistant", "content": row["answer"]},
    ]
    # Qwen chat template; fallback to plain text if missing.
    if getattr(tokenizer, "chat_template", None):
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=False,
        )
    return (
        f"<|im_start|>user\n{user}<|im_end|>\n"
        f"<|im_start|>assistant\n{row['answer']}<|im_end|>\n"
    )


def main() -> None:
    random.seed(42)
    train_cfg = CFG["training"]
    model_id = CFG["base_model"]
    max_rows = int(train_cfg.get("max_train_rows", 6000))
    samsum_n = max(1, int(max_rows * 0.7))
    squad_n = max(0, max_rows - samsum_n)

    print("Building training rows (SamSum + SQuAD)...")
    raw_rows = _samsum_rows(samsum_n) + _squad_rows(squad_n)
    random.shuffle(raw_rows)
    print(f"Total rows: {len(raw_rows)}")

    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    if train_cfg.get("use_qlora", False):
        bnb = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_use_double_quant=True,
        )
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            quantization_config=bnb,
            device_map="auto",
            trust_remote_code=True,
        )
        model = prepare_model_for_kbit_training(model)
    else:
        dtype = torch.bfloat16 if torch.cuda.is_available() else torch.float32
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            torch_dtype=dtype,
            device_map="auto" if torch.cuda.is_available() else None,
            trust_remote_code=True,
        )

    lora = LoraConfig(
        r=int(train_cfg["lora_r"]),
        lora_alpha=int(train_cfg["lora_alpha"]),
        lora_dropout=float(train_cfg["lora_dropout"]),
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    )
    model = get_peft_model(model, lora)
    model.print_trainable_parameters()

    texts = [_to_chat_text(tokenizer, r) for r in raw_rows]
    ds = Dataset.from_dict({"text": texts})

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    common = dict(
        output_dir=str(OUT_DIR / "checkpoints"),
        num_train_epochs=float(train_cfg["num_epochs"]),
        per_device_train_batch_size=int(train_cfg["per_device_train_batch_size"]),
        gradient_accumulation_steps=int(train_cfg["gradient_accumulation_steps"]),
        learning_rate=float(train_cfg["learning_rate"]),
        logging_steps=20,
        save_steps=int(train_cfg["save_steps"]),
        save_total_limit=2,
        bf16=torch.cuda.is_available(),
        gradient_checkpointing=bool(train_cfg.get("gradient_checkpointing", True)),
        report_to="none",
    )

    max_len = int(train_cfg["max_seq_length"])
    if SFTConfig is not None:
        try:
            args = SFTConfig(max_length=max_len, **common)
            trainer = SFTTrainer(
                model=model,
                args=args,
                train_dataset=ds,
                processing_class=tokenizer,
            )
        except TypeError:
            args = TrainingArguments(**common)
            trainer = SFTTrainer(
                model=model,
                args=args,
                train_dataset=ds,
                tokenizer=tokenizer,
                max_seq_length=max_len,
                dataset_text_field="text",
            )
    else:
        args = TrainingArguments(**common)
        trainer = SFTTrainer(
            model=model,
            args=args,
            train_dataset=ds,
            tokenizer=tokenizer,
            max_seq_length=max_len,
            dataset_text_field="text",
        )

    trainer.train()
    trainer.model.save_pretrained(str(OUT_DIR))
    tokenizer.save_pretrained(str(OUT_DIR))
    print(f"Saved Qwen0.5B chatbot LoRA -> {OUT_DIR}")


if __name__ == "__main__":
    main()
