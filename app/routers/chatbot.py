from fastapi import APIRouter, HTTPException

from app.schemas.chatbot import ChatAskRequest, ChatAskResponse
from app.services import chatbot

router = APIRouter(prefix="/chatbot", tags=["chatbot"])


@router.post("/ask", response_model=ChatAskResponse)
def ask(req: ChatAskRequest) -> ChatAskResponse:
    """Answer a question using only the provided meeting transcript."""
    try:
        result = chatbot.ask(req.question, transcript=req.transcript)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Chatbot failed: {exc}") from exc

    return ChatAskResponse(
        meeting_id=req.meeting_id,
        question=req.question,
        answer=result.get("answer", ""),
        used_sample_transcript=bool(result.get("used_sample_transcript")),
    )
