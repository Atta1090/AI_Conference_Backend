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
# Meeting transcripts arrive as dozens of short lines; batching them keeps
# summary/chatbot latency workable on a CPU-only laptop.
_MAX_BATCH = 16


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

    # Fall back to a complete HF-cache snapshot if models/opus is incomplete
    # (common when only en-ar/hi were copied into opus/ and ur lives in cache).
    cache = Path(settings.model_cache_dir)
    root = cache / f"models--{model_id.replace('/', '--')}"
    if root.exists():
        for path in root.rglob("pytorch_model.bin"):
            if path.stat().st_size > 50_000_000:
                return str(path.parent)
    return model_id


def _pair_is_installed(model_id: str) -> bool:
    """True when weights for a pair exist locally (no network needed)."""
    return _resolve_model_source(model_id) != model_id


def installed_pairs() -> dict[str, bool]:
    """Map ``"en->ur"`` to whether that Opus-MT pair is present on disk."""
    return {
        f"{src}->{tgt}": _pair_is_installed(model_id)
        for (src, tgt), model_id in languages.OPUS_PAIRS.items()
    }


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


def _translate_direct_batch(texts: list[str], source: str, target: str) -> list[str]:
    """Translate many strings, batching Marian forward passes."""
    if not texts:
        return []

    model_id = languages.opus_model_id(source, target)
    if model_id is None:
        raise ValueError(f"No direct Opus-MT model for {source}→{target}")

    import torch

    tokenizer, model = _load_pair(model_id)
    # Quantized CPU models stay on CPU; cuda models use settings.device.
    device = next(model.parameters()).device

    out: list[str] = []
    for start in range(0, len(texts), _MAX_BATCH):
        chunk = texts[start : start + _MAX_BATCH]
        encoded = tokenizer(
            chunk,
            return_tensors="pt",
            truncation=True,
            max_length=settings.translation_max_length,
            padding=True,
        )
        encoded = {k: v.to(device) for k, v in encoded.items()}

        with torch.no_grad():
            generated = model.generate(
                **encoded,
                max_length=settings.translation_max_length,
                num_beams=settings.translation_num_beams,
                early_stopping=True,
            )

        out.extend(
            line.strip()
            for line in tokenizer.batch_decode(generated, skip_special_tokens=True)
        )
    return out


def _translate_direct(text: str, source: str, target: str) -> str:
    return _translate_direct_batch([text], source, target)[0]


def translate(text: str, source_language: str, target_language: str) -> str:
    """Translate ``text`` between supported ISO-639-1 language codes."""
    return translate_batch([text], source_language, target_language)[0]


def translate_batch(
    texts: list[str],
    source_language: str,
    target_language: str,
) -> list[str]:
    """Translate many texts at once, preserving input order.

    Every text is still split into sentences (Opus-MT collapses paragraphs),
    but all sentences from all texts share one padded batch per hop, which is
    far faster than translating a meeting transcript line by line.
    """
    cleaned = [_cleanup_text(t) for t in texts]
    if source_language == target_language:
        return cleaned
    if not any(cleaned):
        return cleaned

    hops = languages.translation_path(source_language, target_language)

    pieces: list[str] = []
    owners: list[int] = []
    for index, text in enumerate(cleaned):
        if not text:
            continue
        for sentence in _split_sentences(text) or [text]:
            pieces.append(sentence)
            owners.append(index)

    for src, tgt in hops:
        pieces = [_cleanup_text(p) for p in _translate_direct_batch(pieces, src, tgt)]

    rebuilt: list[list[str]] = [[] for _ in cleaned]
    for index, piece in zip(owners, pieces):
        if piece:
            rebuilt[index].append(piece)
    out = [" ".join(parts) for parts in rebuilt]
    return _retry_if_script_mismatch(cleaned, out, source_language, target_language)


def _retry_if_script_mismatch(
    originals: list[str],
    translated: list[str],
    source: str,
    target: str,
) -> list[str]:
    """Re-run failed lines one-by-one when the batch copied the source script."""
    if source == target:
        return translated
    from app.services.multilingual import mostly_in_language

    hops = languages.translation_path(source, target)
    fixed = list(translated)
    for i, (original, current) in enumerate(zip(originals, translated)):
        if not original:
            continue
        if mostly_in_language(current, target):
            continue
        retry = original
        if not retry.endswith((".", "?", "!", "۔", "؟", "।")):
            retry = retry + "."
        try:
            for src, tgt in hops:
                retry = _cleanup_text(_translate_direct(retry, src, tgt))
        except Exception as exc:  # noqa: BLE001
            print(f"[translation] retry {source}->{target} failed ({exc})")
            continue
        if mostly_in_language(retry, target):
            fixed[i] = retry
            print(f"[translation] retried line {i} {source}->{target}")
    return fixed