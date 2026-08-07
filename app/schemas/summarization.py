"""Request/response models for meeting summarization."""

from __future__ import annotations

from pydantic import BaseModel, Field


class SummarizeRequest(BaseModel):
    transcript: str = Field(..., min_length=20, description="Full meeting transcript text.")
    meeting_id: str | None = Field(None, description="Optional meeting identifier.")
    language: str | None = Field(
        None, description="Optional language hint (e.g. en, ur)."
    )


class SummarizeResponse(BaseModel):
    meeting_id: str | None
    summary: str
    key_points: list[str]
    action_items: list[str]
    raw: str = Field(..., description="Unparsed model output.")
