"""Parser tests covering the output shapes Gemma actually produced.

Each case here is a real formatting deviation observed while demoing, not a
hypothetical: the point is that none of them may result in an empty summary.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from summarization.scripts.parse_output import parse_summary_output


def test_exact_requested_layout():
    text = """SUMMARY:
The team reviewed the release plan and agreed on Friday as the cutoff.

KEY_POINTS:
- Backend work is complete
- QA needs two more days

ACTION_ITEMS:
- Sara: finish the design section (due: Friday)
"""
    result = parse_summary_output(text)

    assert result["summary"].startswith("The team reviewed the release plan")
    assert result["key_points"] == [
        "Backend work is complete",
        "QA needs two more days",
    ]
    assert result["action_items"] == [
        "Sara: finish the design section (due: Friday)"
    ]


def test_markdown_headings_and_spaced_names():
    text = """**Summary**
Budget numbers were reviewed and approved.

**Key Points**
* Revenue is up
* Hiring is paused

**Action Items**
* John to review the budget tonight
"""
    result = parse_summary_output(text)

    assert result["summary"] == "Budget numbers were reviewed and approved."
    assert result["key_points"] == ["Revenue is up", "Hiring is paused"]
    assert result["action_items"] == ["John to review the budget tonight"]


def test_answer_wrapper_with_bare_bullets():
    """The failure that produced empty Key Points on the demo build."""
    text = """Answer:
- The report is due Friday
- Sara owns the design section
- Budget review happens tonight
"""
    result = parse_summary_output(text)

    assert result["key_points"] == [
        "The report is due Friday",
        "Sara owns the design section",
        "Budget review happens tonight",
    ]
    # Nothing is labelled, so we do not invent action items.
    assert result["action_items"] == []
    assert result["summary"], "summary must never be empty when text exists"


def test_prose_only_output():
    text = (
        "The group discussed the Friday deadline and split up the remaining "
        "work between design, budget and QA."
    )
    result = parse_summary_output(text)

    assert result["summary"] == text
    assert result["key_points"] == []


def test_prose_then_bullets_without_headings():
    text = """The team agreed to ship on Friday.
- Design is done
- Budget review pending
"""
    result = parse_summary_output(text)

    assert result["summary"] == "The team agreed to ship on Friday."
    assert result["key_points"] == ["Design is done", "Budget review pending"]


def test_template_placeholders_are_dropped():
    text = """SUMMARY:
<2-4 sentence overview>

KEY_POINTS:
- one short point per line

ACTION_ITEMS:
- owner: task (due: date or TBD)
"""
    result = parse_summary_output(text)

    assert result["summary"] == ""
    assert result["key_points"] == []
    assert result["action_items"] == []


def test_none_action_items_are_empty_not_literal():
    text = """SUMMARY:
Quick sync with no follow-ups.

KEY_POINTS:
- Everything is on track

ACTION_ITEMS:
- None
"""
    result = parse_summary_output(text)

    assert result["action_items"] == []
    assert result["key_points"] == ["Everything is on track"]


def test_numbered_lists_and_duplicates():
    text = """Key Points:
1. Ship on Friday
2. Ship on Friday
3. Freeze the branch
"""
    result = parse_summary_output(text)

    assert result["key_points"] == ["Ship on Friday", "Freeze the branch"]


def test_transcript_speaker_lines_are_not_treated_as_headings():
    text = """Summary:
Ahmed and Sara agreed on the plan.
Ahmed: we finish by Friday.
"""
    result = parse_summary_output(text)

    assert "Ahmed: we finish by Friday." in result["summary"]


@pytest.mark.parametrize("text", ["", "   ", "\n\n"])
def test_blank_output_is_safe(text):
    result = parse_summary_output(text)

    assert result == {
        "summary": "",
        "key_points": [],
        "action_items": [],
        "raw": text.strip(),
    }
