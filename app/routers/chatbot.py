from fastapi import APIRouter, HTTPException

from app.core.stage_log import stage
from app.schemas.chatbot import ChatAskRequest, ChatAskResponse
from app.services import chatbot

router = APIRouter(prefix="/chatbot", tags=["chatbot"])


@router.post("/ask", response_model=ChatAskResponse)
def ask(req: ChatAskRequest) -> ChatAskResponse:
    """Answer a question using only the provided meeting transcript."""
    q = (req.question or "").strip().replace("\n", " ")
    if len(q) > 60:
        q = q[:57] + "…"
    stage("CHATBOT", f"Question: \"{q}\"")
    try:
        result = chatbot.ask(req.question, transcript=req.transcript)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Chatbot failed: {exc}") from exc
    stage("CHATBOT", "Answer ready")

    return ChatAskResponse(
        meeting_id=req.meeting_id,
        question=req.question,
        answer=result.get("answer", ""),
        used_sample_transcript=bool(result.get("used_sample_transcript")),
    )
