"""Clear stage-by-stage terminal logs for ConvoBridge backend demos."""

from __future__ import annotations

from datetime import datetime


def stage(step: str, message: str, **extra: object) -> None:
    """Print one human-readable pipeline stage line to the server terminal."""
    ts = datetime.now().strftime("%H:%M:%S")
    bits = [f"[{ts}]", "[ConvoBridge]", f"[{step}]", message]
    if extra:
        detail = " | ".join(f"{k}={v}" for k, v in extra.items())
        bits.append(f"({detail})")
    print(" ".join(bits), flush=True)


def banner() -> None:
    stage(
        "BOOT",
        "AI backend ready — watching for /health /stt /translate /summarize /chatbot",
    )
