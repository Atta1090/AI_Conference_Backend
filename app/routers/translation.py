from fastapi import APIRouter, HTTPException

from app.core import languages
from app.core.stage_log import stage
from app.schemas.pipeline import TranslationRequest, TranslationResult
from app.services import translation

router = APIRouter(prefix="/translate", tags=["translation"])


@router.post("", response_model=TranslationResult)
def translate(req: TranslationRequest) -> TranslationResult:
    if req.source_language == "auto":
        raise HTTPException(
            status_code=400,
            detail="Provide an explicit source_language for standalone translation.",
        )
    for code in (req.source_language, req.target_language):
        if not languages.is_supported(code):
            raise HTTPException(
                status_code=400, detail=f"Unsupported language '{code}'."
            )

    src_preview = req.text.strip().replace("\n", " ")
    if len(src_preview) > 60:
        src_preview = src_preview[:57] + "…"
    stage(
        "TRANSLATE",
        f"{req.source_language}→{req.target_language}: \"{src_preview}\"",
    )
    try:
        translated = translation.translate(
            req.text,
            source_language=req.source_language,
            target_language=req.target_language,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    out_preview = translated.strip().replace("\n", " ")
    if len(out_preview) > 60:
        out_preview = out_preview[:57] + "…"
    stage("TRANSLATE", f"Done → \"{out_preview}\"")
    return TranslationResult(
        source_language=req.source_language,
        target_language=req.target_language,
        source_text=req.text,
        translated_text=translated,
    )
