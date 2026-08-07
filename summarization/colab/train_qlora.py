"""
QLoRA fine-tuning script for Gemma 3 (run on Google Colab with GPU).

Colab quick start
-----------------
1. Runtime -> Change runtime type -> GPU (T4/L4)
2. Upload this repo (or clone from Git) to Colab
3. Run:

   !pip install -q transformers peft bitsandbytes datasets accelerate trl pyyaml
   !python summarization/colab/train_qlora.py

4. Save output adapter to Google Drive:
   summarization/models/gemma3-meeting-lora

5. Download adapter folder to your backend machine.
"""

from __future__ import annotations

from pathlib import Path

import torch
import yaml
from datasets import load_dataset
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
except ImportError:
    SFTConfig = None

ROOT = Path(__file__).resolve().parents[2]
CFG = yaml.safe_load((ROOT / "summarization" / "config.yaml").read_text(encoding="utf-8"))

DATA_PATH = ROOT / "summarization" / "data" / "processed" / "train_meeting_summary.jsonl"
OUT_DIR = ROOT / "summarization" / "models" / "gemma3-meeting-lora"
PROMPT_TEMPLATE = (ROOT / "summarization" / "prompts" / "meeting_summary.txt").read_text(encoding="utf-8")


def format_example(row: dict) -> str:
    """Build a Gemma chat-format training example using the same prompt
    template that the API uses at inference time."""
    user_content = PROMPT_TEMPLATE.format(transcript=row["input"])
    return (
        f"<start_of_turn>user\n"
        f"{user_content}<end_of_turn>\n"
        f"<start_of_turn>model\n"
        f"{row['output']}<end_of_turn>"
    )


def main() -> None:
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"Missing {DATA_PATH}. Run prepare_training_data.py first."
        )

    model_id = CFG["base_model"]
    train_cfg = CFG["training"]

    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
    )

    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    tokenizer.padding_side = "right"
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        quantization_config=bnb_config,
        device_map="auto",
        trust_remote_code=True,
    )
    model = prepare_model_for_kbit_training(model)

    lora_config = LoraConfig(
        r=train_cfg["lora_r"],
        lora_alpha=train_cfg["lora_alpha"],
        lora_dropout=train_cfg["lora_dropout"],
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    )
    model = get_peft_model(model, lora_config)

    ds = load_dataset("json", data_files={"train": str(DATA_PATH)})["train"]
    ds = ds.map(lambda x: {"text": format_example(x)})

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    common = dict(
        output_dir=str(OUT_DIR),
        num_train_epochs=train_cfg["num_epochs"],
        per_device_train_batch_size=train_cfg["per_device_batch_size"],
        gradient_accumulation_steps=train_cfg["gradient_accumulation_steps"],
        learning_rate=train_cfg["learning_rate"],
        logging_steps=20,
        save_steps=train_cfg["save_steps"],
        save_total_limit=2,
        bf16=torch.cuda.is_available(),
        report_to="none",
    )

    if SFTConfig is not None:
        try:
            args = SFTConfig(max_length=train_cfg["max_seq_length"], **common)
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
                max_seq_length=train_cfg["max_seq_length"],
            )
    else:
        args = TrainingArguments(**common)
        trainer = SFTTrainer(
            model=model,
            args=args,
            train_dataset=ds,
            tokenizer=tokenizer,
            max_seq_length=train_cfg["max_seq_length"],
        )
    trainer.train()
    trainer.model.save_pretrained(str(OUT_DIR))
    tokenizer.save_pretrained(str(OUT_DIR))
    print(f"Saved LoRA adapter -> {OUT_DIR}")


if __name__ == "__main__":
    main()
