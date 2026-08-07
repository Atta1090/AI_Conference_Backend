"""Cloud GPU server entrypoint (separate from local run_dev.py).

Listens on 0.0.0.0 so a phone / Flutter client can reach this VM over the
public internet. Prefers DEVICE=cuda when available.

Does not change local development: keep using ``python run_dev.py`` on the laptop.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

import uvicorn


def main() -> None:
    # Prefer GPU on the cloud VM; fall back to CPU if CUDA is missing.
    os.environ.setdefault("DEVICE", "cuda")
    # Keep backend XTTS off — Flutter uses flutter_tts (same as local).
    os.environ.setdefault("ENABLE_BACKEND_TTS", "false")
    # Faster STT on GPU / cloud.
    os.environ.setdefault("STT_COMPUTE_TYPE", "float16")
    os.environ.setdefault("STT_BEAM_SIZE", "1")

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))

    print(f"Starting ConvoBridge cloud backend on http://{host}:{port}")
    print(
        f"DEVICE={os.environ.get('DEVICE')}  "
        f"HF_TOKEN set={bool(os.getenv('HF_TOKEN'))}"
    )

    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        reload=False,
    )


if __name__ == "__main__":
    main()
