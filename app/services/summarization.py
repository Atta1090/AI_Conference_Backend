"""Meeting summarization service (Gemma 3 + optional LoRA adapter).

Loads lazily on first request with 4-bit (CUDA) or CPU dynamic INT8.
For 8 GB RAM laptops use ``google/gemma-3-1b-it``; fine-tuned adapters
trained on Colab can be mounted via ``SUMMARIZATION_ADAPTER_PATH``.
"""

from __future__ import annotations

import threading
from pathlib import Path

from app.core.config import settings

_model = None
_tokenizer = None
_lock = threading.Lock()


def _prompt_path() -> Path:
    return settings.base_dir / "summarization" / "prompts" / "meeting_summary.txt"


def _build_prompt(transcript: str, tokenizer=None) -> tuple[str, bool]:
    """Wrap the transcript in Gemma's chat format.

    Prefers the tokenizer's own chat template, which is what the LoRA adapter
    was trained against; a hand-built string that is even slightly off makes
    the model emit ``<end_of_turn>`` as its very first token and return
    nothing at all. Returns ``(prompt, already_has_special_tokens)`` because
    the template inserts ``<bos>`` itself and it must not be added twice.
    """
    template = _prompt_path().read_text(encoding="utf-8")
    user_content = template.format(transcript=transcript.strip())

    if tokenizer is not None:
        try:
            prompt = tokenizer.apply_chat_template(
                [{"role": "user", "content": user_content}],
                tokenize=False,
                add_generation_prompt=True,
            )
            if prompt:
                return prompt, True
        except Exception as exc:  # noqa: BLE001
            print(f"[summarization] chat template unavailable ({exc}); using fallback")

    return (
        f"<start_of_turn>user\n{user_content}<end_of_turn>\n"
        f"<start_of_turn>model\n",
        False,
    )


def _load():
    global _model, _tokenizer
    if _model is None:
        with _lock:
            if _model is None:
                from app.services.model_quant import load_gemma_causal_lm

                _tokenizer, _model, mode = load_gemma_causal_lm(
                    settings.summarization_model,
                    settings.summarization_adapter_path,
                )
                print(f"[summarization] Gemma load mode: {mode}")
    return _tokenizer, _model


def _generate(model, tokenizer, inputs, *, sample: bool) -> str:
    """Run one decoding pass and return the newly generated text."""
    import torch

    from app.services.model_quant import gemma_stop_token_ids

    stop_ids = gemma_stop_token_ids(tokenizer)
    kwargs: dict = {
        "max_new_tokens": settings.summarization_max_new_tokens,
        # A small model sometimes picks end-of-turn as its very first token,
        # which returns an empty summary. Force it to actually write.
        "min_new_tokens": settings.summarization_min_new_tokens,
        "repetition_penalty": 1.05,
        "pad_token_id": tokenizer.eos_token_id,
        "eos_token_id": stop_ids or tokenizer.eos_token_id,
    }
    if sample:
        kwargs.update(
            do_sample=True,
            temperature=settings.summarization_temperature,
            top_p=settings.summarization_top_p,
        )
    else:
        kwargs["do_sample"] = False

    with torch.inference_mode():
        output_ids = model.generate(**inputs, **kwargs)

    generated = output_ids[0][inputs["input_ids"].shape[-1] :]
    return tokenizer.decode(generated, skip_special_tokens=True).strip()


def summarize_transcript(transcript: str) -> dict:
    """Generate structured meeting summary from transcript text.

    Prefers Gemma + LoRA. On an 8 GB laptop the model often cannot load (or
    returns empty text after an immediate end-of-turn); in that case we fall
    back to a deterministic extractive summary so the Summary screen is never
    blank during a client demo.
    """
    from app.services.extractive_summary import extractive_summary
    from summarization.scripts.parse_output import parse_summary_output

    try:
        tokenizer, model = _load()
        prompt, has_specials = _build_prompt(transcript, tokenizer)

        inputs = tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=settings.summarization_max_input_tokens,
            add_special_tokens=not has_specials,
        )
        device = next(model.parameters()).device
        inputs = {k: v.to(device) for k, v in inputs.items()}

        # Greedy first: same meeting → same summary (good for demos).
        text = _generate(model, tokenizer, inputs, sample=False)
        parsed = parse_summary_output(text)

        if not parsed["summary"] and not parsed["key_points"]:
            print("[summarization] empty greedy output; retrying with sampling")
            retry = _generate(model, tokenizer, inputs, sample=True)
            if retry.strip():
                parsed = parse_summary_output(retry)
                text = retry

        if parsed["summary"] or parsed["key_points"]:
            parsed["raw"] = text
            return parsed

        print("[summarization] model returned nothing usable; using extractive fallback")
    except Exception as exc:  # noqa: BLE001
        print(f"[summarization] model failed ({exc}); using extractive fallback")

    return extractive_summary(transcript)
