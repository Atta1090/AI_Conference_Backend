"""Translation stage using lightweight Helsinki Opus-MT pair models.

Only 4 languages are supported (en, ur, ar, hi). Each direction loads its
own small model (~300 MB) lazily and caches it. Cross pairs without a
direct Opus model (e.g. ur→ar) pivot through English.
"""

from __future__ import annotations

import re
import threading
from pathlib import Path

from app.core import languages
from app.core.config import settings

# Cache: model_id → (tokenizer, model)
_models: dict[str, tuple] = {}
_lock = threading.Lock()

_WS_RE = re.compile(r"\s+")
_PUNCT_RE = re.compile(r"([!?.,])\1+")
# Opus-MT is trained on sentence pairs; whole paragraphs often collapse
# into a short, wrong line. Split on end punctuation (incl. Urdu/Arabic).
_SENT_SPLIT_RE = re.compile(r"(?<=[.!?۔؟！])\s+")


def _cleanup_text(text: str) -> str:
    """Light normalisation so short spoken lines translate more reliably."""
    cleaned = text.strip()
    cleaned = _WS_RE.sub(" ", cleaned)
    cleaned = _PUNCT_RE.sub(r"\1", cleaned)
    return cleaned.strip()


def _split_sentences(text: str) -> list[str]:
    """Split into sentence-sized chunks for more reliable Opus-MT output."""
    parts = _SENT_SPLIT_RE.split(text.strip())
    return [p.strip() for p in parts if p and p.strip()]


def _resolve_model_source(model_id: str) -> str:
    """Prefer locally downloaded models/opus/<name> over Hub/cache."""
    local = settings.base_dir / "models" / "opus" / model_id.split("/")[-1]
    weight = local / "pytorch_model.bin"
    if weight.exists() and weight.stat().st_size > 50_000_000:
        return str(local)
    return model_id


def _load_pair(model_id: str):
    """Lazy-load and cache one Opus-MT pair model."""
    if model_id in _models:
        return _models[model_id]

    with _lock:
        if model_id in _models:
            return _models[model_id]

        import torch  # noqa: F401
        from transformers import MarianMTModel, MarianTokenizer

        source = _resolve_model_source(model_id)
        kwargs: dict = {}
        # Hub ids use the shared HF cache; local folders load as-is.
        if not Path(source).exists():
            kwargs["cache_dir"] = str(settings.model_cache_dir)

        try:
            tokenizer = MarianTokenizer.from_pretrained(source, **kwargs)
            model = MarianMTModel.from_pretrained(
                source,
                low_cpu_mem_usage=True,
                **kwargs,
            )
        except Exception as exc:  # noqa: BLE001
            raise RuntimeError(
                f"Failed to load translation model '{model_id}'. "
                "Run: python download_opus_models.py "
                "(needs HuggingFace network access)."
            ) from exc
        model.to(settings.device)
        model.eval()
        from app.services.model_quant import maybe_quantize_opus

        model, qmode = maybe_quantize_opus(model)
        if qmode != "none":
            print(f"[translation] Opus {model_id} quant mode: {qmode}")
        _models[model_id] = (tokenizer, model)
        return tokenizer, model


def _translate_direct(text: str, source: str, target: str) -> str:
    model_id = languages.opus_model_id(source, target)
    if model_id is None:
        raise ValueError(f"No direct Opus-MT model for {source}→{target}")

    import torch

    tokenizer, model = _load_pair(model_id)
    encoded = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=settings.translation_max_length,
        padding=True,
    )
    # Quantized CPU models stay on CPU; cuda models use settings.device.
    device = next(model.parameters()).device
    encoded = {k: v.to(device) for k, v in encoded.items()}

    with torch.no_grad():
        generated = model.generate(
            **encoded,
            max_length=settings.translation_max_length,
            num_beams=settings.translation_num_beams,
            early_stopping=True,
        )

    return tokenizer.batch_decode(generated, skip_special_tokens=True)[0].strip()


def translate(text: str, source_language: str, target_language: str) -> str:
    """Translate ``text`` between supported ISO-639-1 language codes."""
    text = _cleanup_text(text)
    if not text:
        return ""
    if source_language == target_language:
        return text

    hops = languages.translation_path(source_language, target_language)
    sentences = _split_sentences(text)
    if not sentences:
        sentences = [text]

    translated_parts: list[str] = []
    for sentence in sentences:
        current = sentence
        for src, tgt in hops:
            current = _cleanup_text(_translate_direct(current, src, tgt))
        if current:
            translated_parts.append(current)
    return " ".join(translated_parts)