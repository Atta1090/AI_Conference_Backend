"""Request/response models for meeting transcript Q&A chatbot."""

from __future__ import annotations

from pydantic import BaseModel, Field


class ChatAskRequest(BaseModel):
    question: str = Field(..., min_length=1, description="User question about the meeting.")
    transcript: str | None = Field(
        None,
        description="Meeting transcript context. If omitted, a built-in sample is used for demo.",
    )
    meeting_id: str | None = Field(None, description="Optional meeting identifier.")


class ChatAskResponse(BaseModel):
    meeting_id: str | None
    question: str
    answer: str
    used_sample_transcript: bool = Field(
        False,
        description="True when the server filled in a demo transcript.",
    )
