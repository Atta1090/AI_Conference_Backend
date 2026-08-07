"""Pydantic request/response models for the meeting audio pipeline."""

from __future__ import annotations

from pydantic import BaseModel, Field


class TranscriptSegment(BaseModel):
    start: float = Field(..., description="Segment start time in seconds.")
    end: float = Field(..., description="Segment end time in seconds.")
    text: str = Field(..., description="Transcribed text for the segment.")


class TranscriptionResult(BaseModel):
    language: str = Field(..., description="Detected source language (ISO-639-1).")
    language_probability: float = Field(
        ..., description="Confidence of the detected language (0-1)."
    )
    duration: float = Field(..., description="Audio duration in seconds.")
    text: str = Field(..., description="Full transcript text.")
    segments: list[TranscriptSegment] = Field(default_factory=list)


class TranslationRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Text to translate.")
    source_language: str = Field(
        "auto", description="Source language ISO code, or 'auto' to detect."
    )
    target_language: str = Field(..., description="Target language ISO code.")


class TranslationResult(BaseModel):
    source_language: str
    target_language: str
    source_text: str
    translated_text: str


class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Text to synthesize.")
    language: str = Field(..., description="Language ISO code of the text.")


class PipelineResult(BaseModel):
    """End-to-end result: denoise -> STT -> translate -> (TTS handled via URL)."""

    detected_language: str
    language_probability: float
    duration: float
    transcript: str
    segments: list[TranscriptSegment]
    target_language: str
    translated_text: str
    noise_reduction_applied: bool
    tts_audio_url: str | None = Field(
        None, description="Relative URL to fetch synthesized target-language audio."
    )


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    device: str
