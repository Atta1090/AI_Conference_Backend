from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.extractive_summary import extractive_summary


def test_extractive_summary_fills_all_sections():
    transcript = """Ahmed: Thanks for joining the sprint review.
Sara: I finished the login screen redesign yesterday.
Bilal: Payment needs about two days.
Sara: I will add the Urdu strings tomorrow.
Ahmed: We must demo to the client on Friday morning.
"""
    result = extractive_summary(transcript)

    assert "Ahmed" in result["summary"]
    assert result["key_points"]
    assert any("Urdu" in item or "Friday" in item for item in result["action_items"])
    assert result["raw"].startswith("SUMMARY:")


def test_extractive_summary_handles_blank():
    assert extractive_summary("") == {
        "summary": "",
        "key_points": [],
        "action_items": [],
        "raw": "",
    }
