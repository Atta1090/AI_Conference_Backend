from fastapi import APIRouter, HTTPException

from app.core.stage_log import stage
from app.schemas.summarization import SummarizeRequest, SummarizeResponse
from app.services import summarization

router = APIRouter(prefix="/summarize", tags=["summarization"])


@router.post("", response_model=SummarizeResponse)
def summarize(req: SummarizeRequest) -> SummarizeResponse:
    """Generate meeting summary, key points, and action items from transcript."""
    utterances = (
        [u.model_dump() for u in req.utterances] if req.utterances else None
    )
    stage(
        "SUMMARY",
        "Generating meeting summary",
        chars=len(req.transcript or ""),
        language=req.language or "auto",
        lines=len(utterances or []),
    )
    try:
        result = summarization.summarize_transcript(
            req.transcript,
            language=req.language,
            utterances=utterances,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Summarization failed: {exc}")
    stage(
        "SUMMARY",
        "Summary ready",
        points=len(result.get("key_points", [])),
        language=result.get("language", "en"),
    )

    return SummarizeResponse(
        meeting_id=req.meeting_id,
        summary=result.get("summary", ""),
        key_points=result.get("key_points", []),
        action_items=result.get("action_items", []),
        language=result.get("language", "en"),
        raw=result.get("raw", ""),
    )
