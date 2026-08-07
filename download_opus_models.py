"""Pre-download Helsinki Opus-MT pair models for ConvoBridge (en/ur/ar/hi).

Downloads into models/opus/<name>/ using curl (reliable on Windows without
symlink privileges). The translation service prefers these local folders.

Usage (from project root, venv active):
    python download_opus_models.py
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from app.core.config import settings
from app.core.languages import OPUS_PAIRS

_PRIORITY = [
    "Helsinki-NLP/opus-mt-en-ur",
    "Helsinki-NLP/opus-mt-ur-en",
    "Helsinki-NLP/opus-mt-ar-en",
    "Helsinki-NLP/opus-mt-en-ar",
    "Helsinki-NLP/opus-mt-hi-en",
    "Helsinki-NLP/opus-mt-en-hi",
]

# Tokenizer / config files (small). Weights downloaded separately.
_SMALL_FILES = [
    "config.json",
    "generation_config.json",
    "tokenizer_config.json",
    "vocab.json",
    "source.spm",
    "target.spm",
]


def _local_dir(model_id: str) -> Path:
    name = model_id.split("/")[-1]
    return Path(settings.base_dir) / "models" / "opus" / name


def _is_complete(model_id: str) -> bool:
    root = _local_dir(model_id)
    weight = root / "pytorch_model.bin"
    return weight.exists() and weight.stat().st_size > 50_000_000


def _also_complete_in_hf_cache(model_id: str) -> bool:
    """True if an older HF-cache install already has usable weights."""
    cache = Path(settings.model_cache_dir)
    root = cache / f"models--{model_id.replace('/', '--')}"
    if not root.exists():
        return False
    for path in root.rglob("pytorch_model.bin"):
        if path.stat().st_size > 50_000_000:
            return True
    return False


def _curl(url: str, dest: Path) -> bool:
    curl = shutil.which("curl") or shutil.which("curl.exe")
    if not curl:
        raise RuntimeError("curl.exe not found on PATH")
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        curl,
        "-L",
        "--fail",
        "--retry",
        "5",
        "--retry-delay",
        "2",
        "--connect-timeout",
        "30",
        "-C",
        "-",
        "-o",
        str(dest),
        url,
    ]
    print(f"  curl {dest.name}")
    result = subprocess.run(cmd, check=False)
    return result.returncode == 0 and dest.exists() and dest.stat().st_size > 0


def _download_one(model_id: str) -> None:
    root = _local_dir(model_id)
    root.mkdir(parents=True, exist_ok=True)
    base = f"https://huggingface.co/{model_id}/resolve/main"

    for name in _SMALL_FILES:
        dest = root / name
        if dest.exists() and dest.stat().st_size > 0:
            print(f"  skip {name}")
            continue
        if not _curl(f"{base}/{name}", dest):
            # Some Opus repos omit generation_config.json — non-fatal.
            if name == "generation_config.json":
                print(f"  optional missing: {name}")
                dest.unlink(missing_ok=True)
                continue
            raise RuntimeError(f"Failed to download {model_id}/{name}")

    weight = root / "pytorch_model.bin"
    if not (weight.exists() and weight.stat().st_size > 50_000_000):
        if not _curl(f"{base}/pytorch_model.bin", weight):
            raise RuntimeError(f"Failed to download {model_id}/pytorch_model.bin")
        if weight.stat().st_size <= 50_000_000:
            raise RuntimeError(
                f"Weight file too small for {model_id}: {weight.stat().st_size} bytes"
            )


def main() -> None:
    wanted = set(OPUS_PAIRS.values())
    pairs = [m for m in _PRIORITY if m in wanted]
    pairs += sorted(wanted - set(pairs))

    print(f"Local Opus dir: {Path(settings.base_dir) / 'models' / 'opus'}")
    print(f"Models: {len(pairs)}\n")

    for model_id in pairs:
        if _is_complete(model_id):
            print(f"SKIP (local): {model_id}")
            continue
        if _also_complete_in_hf_cache(model_id):
            print(f"SKIP (hf-cache): {model_id}")
            continue
        print(f"DOWNLOAD: {model_id}")
        _download_one(model_id)
        print("  done\n")

    print("Opus-MT download pass finished.")
    for model_id in pairs:
        ok = _is_complete(model_id) or _also_complete_in_hf_cache(model_id)
        print(f"  [{'OK' if ok else 'MISSING'}] {model_id}")


if __name__ == "__main__":
    main()
