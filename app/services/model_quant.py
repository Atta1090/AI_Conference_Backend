"""Shared quantized model loading helpers for ConvoBridge.

Gemma (chatbot / summarization):
  * CUDA  → bitsandbytes NF4 4-bit (true 4-bit)
  * CPU   → load float32 then torch dynamic INT8 on Linear layers
            (bitsandbytes 4-bit needs NVIDIA CUDA; dynamic INT8 is the
            practical CPU equivalent for RAM + speed)

Opus-MT:
  * CPU   → optional dynamic INT8 after load
"""

from __future__ import annotations

import logging
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)


def _cuda_available() -> bool:
    try:
        import torch

        return settings.device.startswith("cuda") and torch.cuda.is_available()
    except Exception:
        return False


def load_gemma_causal_lm(model_id: str, adapter_path: str | Path | None = None):
    """Load Gemma (or compatible causal LM) with 4-bit when possible.

    Returns ``(tokenizer, model, quant_mode)`` where ``quant_mode`` is one of:
    ``bnb-4bit``, ``dynamic-int8``, ``fp16``, ``fp32``.
    """
    import torch
    from peft import PeftModel
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(
        model_id,
        trust_remote_code=True,
        cache_dir=str(settings.model_cache_dir),
    )
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    use_cuda = _cuda_available()
    want_4bit = settings.gemma_load_in_4bit
    quant_mode = "fp32"
    model_kwargs: dict = {
        "trust_remote_code": True,
        "cache_dir": str(settings.model_cache_dir),
    }

    if want_4bit and use_cuda:
        try:
            from transformers import BitsAndBytesConfig

            compute_dtype = (
                torch.bfloat16
                if torch.cuda.is_bf16_supported()
                else torch.float16
            )
            model_kwargs["quantization_config"] = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=compute_dtype,
                bnb_4bit_use_double_quant=True,
            )
            model_kwargs["device_map"] = "auto"
            quant_mode = "bnb-4bit"
            logger.info("Loading %s in bitsandbytes 4-bit (NF4)", model_id)
        except Exception as exc:  # noqa: BLE001
            logger.warning("4-bit load unavailable (%s); falling back.", exc)
            model_kwargs.pop("quantization_config", None)
            model_kwargs.pop("device_map", None)

    if quant_mode != "bnb-4bit":
        if use_cuda:
            model_kwargs["torch_dtype"] = torch.float16
            model_kwargs["device_map"] = "auto"
            model_kwargs["low_cpu_mem_usage"] = True
            quant_mode = "fp16"
        else:
            # Avoid meta-tensor trap on CPU (no device_map).
            model_kwargs["torch_dtype"] = torch.float32
            model_kwargs["low_cpu_mem_usage"] = False
            quant_mode = "fp32"

    model = AutoModelForCausalLM.from_pretrained(model_id, **model_kwargs)

    adapter = Path(adapter_path) if adapter_path else None
    if adapter and adapter.exists() and (adapter / "adapter_config.json").exists():
        try:
            model = PeftModel.from_pretrained(
                model,
                str(adapter),
                # On 4-bit GPU, peft handles device_map; on CPU keep weights real.
                low_cpu_mem_usage=use_cuda,
            )
            logger.info("Loaded LoRA adapter from %s", adapter)
        except Exception as exc:  # noqa: BLE001
            logger.warning("LoRA adapter load failed (%s); using base model.", exc)

    if quant_mode == "bnb-4bit":
        model.eval()
        return tokenizer, model, quant_mode

    if not use_cuda:
        model.to("cpu")
        if settings.gemma_cpu_dynamic_int8:
            try:
                # Merge LoRA into base so dynamic quant sees plain Linear layers.
                if hasattr(model, "merge_and_unload"):
                    model = model.merge_and_unload()
                model = torch.quantization.quantize_dynamic(
                    model, {torch.nn.Linear}, dtype=torch.qint8
                )
                quant_mode = "dynamic-int8"
                logger.info("Applied CPU dynamic INT8 quantization to %s", model_id)
            except Exception as exc:  # noqa: BLE001
                logger.warning("CPU dynamic INT8 failed (%s); keeping fp32.", exc)

    model.eval()
    return tokenizer, model, quant_mode


def gemma_stop_token_ids(tokenizer) -> list[int]:
    """Token ids that should end generation.

    Gemma marks the end of a reply with ``<end_of_turn>``, not with the
    tokenizer's ``eos_token``. Without it the model keeps going and starts a
    fresh ``<start_of_turn>model`` block, which shows up in the answer as a
    stray "model" line followed by a second, usually contradictory reply.
    """
    ids: list[int] = []
    if tokenizer.eos_token_id is not None:
        ids.append(tokenizer.eos_token_id)

    for token in ("<end_of_turn>", "<eos>"):
        try:
            token_id = tokenizer.convert_tokens_to_ids(token)
        except Exception:  # noqa: BLE001
            continue
        if isinstance(token_id, int) and token_id >= 0 and token_id not in ids:
            ids.append(token_id)

    return ids


def maybe_quantize_opus(model):
    """Apply CPU dynamic INT8 to an Opus/Marian model when enabled."""
    if not settings.opus_cpu_dynamic_int8:
        return model, "none"
    if _cuda_available():
        return model, "none"
    try:
        import torch

        model = torch.quantization.quantize_dynamic(
            model, {torch.nn.Linear}, dtype=torch.qint8
        )
        logger.info("Applied CPU dynamic INT8 quantization to Opus-MT")
        return model, "dynamic-int8"
    except Exception as exc:  # noqa: BLE001
        logger.warning("Opus INT8 quantize failed (%s)", exc)
        return model, "none"
