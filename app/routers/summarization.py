from fastapi import APIRouter, HTTPException

from app.schemas.summarization import SummarizeRequest, SummarizeResponse
from app.services import summarization

router = APIRouter(prefix="/summarize", tags=["summarization"])


@router.post("", response_model=SummarizeResponse)
def summarize(req: SummarizeRequest) -> SummarizeResponse:
    """Generate meeting summary, key points, and action items from transcript."""
    try:
        result = summarization.summarize_transcript(req.transcript)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Summarization failed: {exc}")

    return SummarizeResponse(
        meeting_id=req.meeting_id,
        summary=result.get("summary", ""),
        key_points=result.get("key_points", []),
        action_items=result.get("action_items", []),
        raw=result.get("raw", ""),
    )
