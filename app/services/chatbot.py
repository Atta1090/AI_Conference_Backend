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

# The prompt asks the model for this exact sentence when it finds nothing; we
# swap it for the user's language instead of machine translating it.
_NOT_FOUND_EN = "Not mentioned in the transcript."


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
        return _NOT_FOUND_EN

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
        return _NOT_FOUND_EN

    scored.sort(key=lambda item: (-item[0], -len(item[1])))
    best = [line for _, line in scored[:3]]
    return " ".join(best)


def ask(
    question: str,
    transcript: str | None = None,
    language: str | None = None,
    utterances: list[dict] | None = None,
) -> dict:
    """Answer a question grounded in the meeting transcript.

    The transcript and the question are both normalised to English (Gemma 1B
    only reasons reliably in English), then the answer is translated back into
    the language the question was asked in.
    """
    from app.services import multilingual

    used_sample = False
    raw_transcript = (transcript or "").strip()
    hint = multilingual.normalize_code(language)
    # An explicit picker choice wins; otherwise answer in the question's script.
    reply_language = (
        multilingual.normalize_code(language)
        if language
        else multilingual.detect_language(question, default="en")
    )

    speaker_names: set[str] = set()
    if len(raw_transcript) < 20 and not utterances:
        text = _DEFAULT_TRANSCRIPT
        used_sample = True
        speaker_names = {"Ahmed", "Sara", "John"}
    else:
        english, entries = multilingual.english_transcript(
            raw_transcript,
            utterances=utterances,
            default_language=hint,
        )
        text = english.strip() or raw_transcript
        speaker_names = {entry["speaker"] for entry in entries}

    english_question = multilingual.to_english(question, hint=reply_language)

    answer = ""
    try:
        import torch

        from app.services.model_quant import gemma_stop_token_ids

        tokenizer, model = _load()
        prompt, has_specials = _build_prompt(text, english_question, tokenizer)

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
        answer = _extractive_answer(english_question, text)

    missing = not answer or answer.strip().rstrip(".").lower() == (
        _NOT_FOUND_EN.rstrip(".").lower()
    )
    if missing:
        return {
            "answer": multilingual.not_in_transcript(reply_language),
            "language": reply_language,
            "used_sample_transcript": used_sample,
        }

    if reply_language != "en":
        # Speaker names stay verbatim: a translated name would answer "who
        # owns this task" with the wrong person.
        localized = multilingual.localize(answer, reply_language, speaker_names)
        if localized.strip():
            answer = localized.strip()
        print(f"[chatbot] localized answer en->{reply_language}")

    return {
        "answer": answer,
        "language": reply_language,
        "used_sample_transcript": used_sample,
    }
