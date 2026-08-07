"""API smoke tests for ConvoBridge FastAPI backend.

Run from project root (venv active):
    pytest tests/test_api_smoke.py -q
"""

from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"


def test_languages_pakistan_set():
    r = client.get("/languages")
    assert r.status_code == 200
    codes = {row["code"] for row in r.json()["languages"]}
    assert codes == {"en", "ur", "ar", "hi"}


def test_translate_rejects_unsupported():
    r = client.post(
        "/translate",
        json={
            "text": "Hello",
            "source_language": "en",
            "target_language": "fr",
        },
    )
    assert r.status_code == 400


def _opus_en_ur_available() -> bool:
    root = Path(__file__).resolve().parents[1]
    local = root / "models" / "opus" / "opus-mt-en-ur" / "pytorch_model.bin"
    if local.exists() and local.stat().st_size > 50_000_000:
        return True
    cache = root / "models" / "cache"
    for path in cache.rglob("pytorch_model.bin"):
        if "opus-mt-en-ur" in str(path) and path.stat().st_size > 50_000_000:
            return True
    return False


@pytest.mark.skipif(not _opus_en_ur_available(), reason="Opus en-ur weights missing")
def test_translate_en_ur():
    r = client.post(
        "/translate",
        json={
            "text": "Hello everyone",
            "source_language": "en",
            "target_language": "ur",
        },
    )
    assert r.status_code == 200
    body = r.json()
    assert body["translated_text"].strip()
