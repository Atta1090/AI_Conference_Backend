"""Request/response models for meeting transcript Q&A chatbot."""

from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.summarization import TranscriptUtterance


class ChatAskRequest(BaseModel):
    question: str = Field(..., min_length=1, description="User question about the meeting.")
    transcript: str | None = Field(
        None,
        description="Meeting transcript context. If omitted, a built-in sample is used for demo.",
    )
    meeting_id: str | None = Field(None, description="Optional meeting identifier.")
    language: str | None = Field(
        None,
        description="Language to answer in (e.g. en, ur, ar, hi). Defaults to "
        "the language the question is written in.",
    )
    utterances: list[TranscriptUtterance] | None = Field(
        None,
        description="Per-line transcript with language tags. Preferred over "
        "`transcript` when available.",
    )


class ChatAskResponse(BaseModel):
    meeting_id: str | None
    question: str
    answer: str
    language: str = Field("en", description="Language the answer is written in.")
    used_sample_transcript: bool = Field(
        False,
        description="True when the server filled in a demo transcript.",
    )
