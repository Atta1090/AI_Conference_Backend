"""Meeting transcript Q&A chatbot (Gemma 3 + optional LoRA adapter).

Loads lazily on first request with 4-bit (CUDA) or CPU dynamic INT8.
Adapter path defaults to ``chatbot/models/gemma3-chatbot-lora``.
"""

from __future__ import annotations

import re
import threading
from pathlib import Path

from app.core.config import settings

_model = None
_tokenizer = None
_lock = threading.Lock()

_DEFAULT_TRANSCRIPT = """
Ahmed: We need to finish the project report by Friday.
Sara: I will handle the design section.
John: I can review the budget numbers tonight.
Ahmed: Great. Let's meet again on Monday at 10 AM.
""".strip()


def _prompt_path() -> Path:
    return settings.base_dir / "chatbot" / "prompts" / "qa_prompt.txt"


def _build_prompt(transcript: str, question: str, tokenizer=None) -> tuple[str, bool]:
    """Build the Gemma chat prompt for a transcript question.

    Uses the tokenizer's own chat template when available: the LoRA adapter was
    trained with it, and a hand-rolled prompt can make the model answer with an
    immediate end-of-turn (i.e. an empty answer). Returns
    ``(prompt, already_has_special_tokens)`` so ``<bos>`` is not added twice.
    """
    template = _prompt_path().read_text(encoding="utf-8")
    user_content = template.format(
        transcript=transcript.strip(),
        question=question.strip(),
    )

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
            print(f"[chatbot] chat template unavailable ({exc}); using fallback")

    return (
        f"<start_of_turn>user\n{user_content}<end_of_turn>\n"
        f"<start_of_turn>model\n",
        False,
    )

def _clean_answer(text: str) -> str:
    """Normalise one model reply into a plain answer string."""
    answer = (text or "").strip()

    # If the model rolled straight into another chat turn, keep only the first.
    # With special tokens stripped this looks like a bare "model" / "user" line.
    answer = re.split(
        r"\n\s*(?:model|user)\s*\n", answer, maxsplit=1, flags=re.I
    )[0]
    answer = re.split(r"<(?:start|end)_of_turn>", answer, maxsplit=1)[0]

    answer = re.sub(r"^(?:answer|response|a)\s*[:\-]\s*", "", answer, flags=re.I)
    answer = answer.replace("**", "").strip()
    return answer.strip()


def _load():
    global _model, _tokenizer
    if _model is None:
        with _lock:
            if _model is None:
                from app.services.model_quant import load_gemma_causal_lm

                _tokenizer, _model, mode = load_gemma_causal_lm(
                    settings.chatbot_model,
                    settings.chatbot_adapter_path,
                )
                print(f"[chatbot] Gemma load mode: {mode}")
    return _tokenizer, _model


def _extractive_answer(question: str, transcript: str) -> str:
    """Keyword overlap fallback when Gemma cannot load or returns empty."""
    q_words = {
        w
        for w in re.findall(r"[a-zA-Z\u0600-\u06FF]{3,}", question.lower())
        if w
        not in {
            "the",
            "and",
            "what",
            "when",
            "who",
            "where",
            "which",
            "does",
            "did",
            "about",
            "this",
            "that",
            "from",
            "with",
            "have",
            "will",
            "meeting",
        }
    }
    if not q_words:
        return "Not mentioned in the transcript."

    scored: list[tuple[int, str]] = []
    for raw in transcript.splitlines():
        line = raw.strip()
        if not line:
            continue
        lower = line.lower()
        score = sum(1 for w in q_words if w in lower)
        if score:
            scored.append((score, line))

    if not scored:
        return "Not mentioned in the transcript."

    scored.sort(key=lambda item: (-item[0], -len(item[1])))
    best = [line for _, line in scored[:3]]
    return " ".join(best)


def ask(question: str, transcript: str | None = None) -> dict:
    """Answer a question grounded in the meeting transcript."""
    used_sample = False
    text = (transcript or "").strip()
    if len(text) < 20:
        text = _DEFAULT_TRANSCRIPT
        used_sample = True

    answer = ""
    try:
        import torch

        from app.services.model_quant import gemma_stop_token_ids

        tokenizer, model = _load()
        prompt, has_specials = _build_prompt(text, question, tokenizer)

        inputs = tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=settings.chatbot_max_input_tokens,
            add_special_tokens=not has_specials,
        )
        device = next(model.parameters()).device
        inputs = {k: v.to(device) for k, v in inputs.items()}
        stop_ids = gemma_stop_token_ids(tokenizer)

        def generate(sample: bool) -> str:
            kwargs: dict = {
                "max_new_tokens": settings.chatbot_max_new_tokens,
                "min_new_tokens": 4,
                "repetition_penalty": 1.05,
                "pad_token_id": tokenizer.eos_token_id,
                "eos_token_id": stop_ids or tokenizer.eos_token_id,
            }
            if sample:
                kwargs.update(
                    do_sample=True,
                    temperature=settings.chatbot_temperature,
                    top_p=settings.chatbot_top_p,
                )
            else:
                kwargs["do_sample"] = False

            with torch.inference_mode():
                output_ids = model.generate(**inputs, **kwargs)
            generated = output_ids[0][inputs["input_ids"].shape[-1] :]
            return _clean_answer(
                tokenizer.decode(generated, skip_special_tokens=True)
            )

        answer = generate(sample=False)
        if not answer:
            answer = generate(sample=True)
    except Exception as exc:  # noqa: BLE001
        print(f"[chatbot] model failed ({exc}); using extractive fallback")

    if not answer:
        answer = _extractive_answer(question, text)
    if not answer:
        answer = "Not mentioned in the transcript."

    return {
        "answer": answer,
        "used_sample_transcript": used_sample,
    }
