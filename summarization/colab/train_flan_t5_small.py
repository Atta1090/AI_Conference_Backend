"""
Fine-tune FLAN-T5-small for meeting summarization (lighter than Gemma).

Uses the same processed JSONL as the Gemma pipeline:
  summarization/data/processed/train_meeting_summary.jsonl

Colab / GPU quick start
-----------------------
  !pip install -q transformers peft datasets accelerate evaluate
  !python summarization/colab/train_flan_t5_small.py

Output:
  summarization/models/flan-t5-small-meeting/

This does NOT replace Gemma training (train_qlora.py). It is a separate path.
"""

from __future__ import annotations

from pathlib import Path

import torch
import yaml
from datasets import load_dataset
from peft import LoraConfig, TaskType, get_peft_model
from transformers import (
    AutoModelForSeq2SeqLM,
    AutoTokenizer,
    DataCollatorForSeq2Seq,
    Seq2SeqTrainer,
    Seq2SeqTrainingArguments,
)

ROOT = Path(__file__).resolve().parents[2]
CFG = yaml.safe_load(
    (ROOT / "summarization" / "config_flan_t5_small.yaml").read_text(encoding="utf-8")
)

DATA_PATH = ROOT / CFG["datasets"]["train_jsonl"]
OUT_DIR = ROOT / CFG["adapter_path"]
PROMPT_TEMPLATE = (
    ROOT / "summarization" / "prompts" / "meeting_summary.txt"
).read_text(encoding="utf-8")


def _source_text(row: dict) -> str:
    return PROMPT_TEMPLATE.format(transcript=row["input"].strip())


def main() -> None:
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"Missing {DATA_PATH}. Run:\n"
            "  python summarization/scripts/download_datasets.py\n"
            "  python summarization/scripts/prepare_training_data.py"
        )

    model_id = CFG["base_model"]
    train_cfg = CFG["training"]
    max_rows = int(train_cfg.get("max_train_rows", 8000))
    max_src = int(train_cfg["max_source_length"])
    max_tgt = int(train_cfg["max_target_length"])

    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_id)

    if not train_cfg.get("full_finetune", False):
        lora = LoraConfig(
            r=int(train_cfg["lora_r"]),
            lora_alpha=int(train_cfg["lora_alpha"]),
            lora_dropout=float(train_cfg["lora_dropout"]),
            bias="none",
            task_type=TaskType.SEQ_2_SEQ_LM,
            target_modules=["q", "v"],
        )
        model = get_peft_model(model, lora)
        model.print_trainable_parameters()

    ds = load_dataset("json", data_files={"train": str(DATA_PATH)})["train"]
    if max_rows and len(ds) > max_rows:
        ds = ds.shuffle(seed=42).select(range(max_rows))

    def tokenize(batch: dict) -> dict:
        sources = [
            PROMPT_TEMPLATE.format(transcript=t.strip()) for t in batch["input"]
        ]
        model_inputs = tokenizer(
            sources,
            max_length=max_src,
            truncation=True,
            padding=False,
        )
        labels = tokenizer(
            text_target=batch["output"],
            max_length=max_tgt,
            truncation=True,
            padding=False,
        )
        model_inputs["labels"] = labels["input_ids"]
        return model_inputs

    tokenized = ds.map(
        tokenize,
        batched=True,
        remove_columns=ds.column_names,
        desc="Tokenizing FLAN-T5 examples",
    )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    use_bf16 = torch.cuda.is_available() and torch.cuda.is_bf16_supported()
    use_fp16 = torch.cuda.is_available() and not use_bf16

    args = Seq2SeqTrainingArguments(
        output_dir=str(OUT_DIR / "checkpoints"),
        num_train_epochs=float(train_cfg["num_epochs"]),
        per_device_train_batch_size=int(train_cfg["per_device_batch_size"]),
        gradient_accumulation_steps=int(train_cfg["gradient_accumulation_steps"]),
        learning_rate=float(train_cfg["learning_rate"]),
        logging_steps=20,
        save_steps=int(train_cfg["save_steps"]),
        save_total_limit=2,
        predict_with_generate=True,
        generation_max_length=max_tgt,
        bf16=use_bf16,
        fp16=use_fp16,
        report_to="none",
        remove_unused_columns=False,
    )

    collator = DataCollatorForSeq2Seq(tokenizer=tokenizer, model=model)
    trainer = Seq2SeqTrainer(
        model=model,
        args=args,
        train_dataset=tokenized,
        data_collator=collator,
        processing_class=tokenizer,
    )

    trainer.train()
    trainer.model.save_pretrained(str(OUT_DIR))
    tokenizer.save_pretrained(str(OUT_DIR))
    print(f"Saved FLAN-T5-small meeting model -> {OUT_DIR}")


if __name__ == "__main__":
    main()
