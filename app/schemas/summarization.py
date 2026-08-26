"""Request/response models for meeting summarization."""

from __future__ import annotations

from pydantic import BaseModel, Field


class TranscriptUtterance(BaseModel):
    """One participant's line, tagged with the language it was spoken in.

    Meetings are multilingual: each caption is stored in the speaker's own
    language. Sending the tag lets the backend normalise the transcript with
    the right Opus-MT pair instead of guessing from the script.
    """

    speaker: str = Field("Speaker", description="Display name of the speaker.")
    text: str = Field(..., description="What was said, in the speaker's language.")
    lang: str = Field("en", description="ISO-639-1 code of ``text``.")


class SummarizeRequest(BaseModel):
    transcript: str = Field(..., min_length=20, description="Full meeting transcript text.")
    meeting_id: str | None = Field(None, description="Optional meeting identifier.")
    language: str | None = Field(
        None,
        description="Language to write the summary in (e.g. en, ur, ar, hi).",
    )
    utterances: list[TranscriptUtterance] | None = Field(
        None,
        description="Per-line transcript with language tags. Preferred over "
        "`transcript` when available.",
    )


class SummarizeResponse(BaseModel):
    meeting_id: str | None
    summary: str
    key_points: list[str]
    action_items: list[str]
    language: str = Field("en", description="Language the fields are written in.")
    raw: str = Field(..., description="Unparsed model output.")
