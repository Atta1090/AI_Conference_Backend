import base64
from dataclasses import dataclass
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

app = FastAPI(title="Voice Translation Pipeline")


@dataclass
class PipelineOut:
  transcript: str
  translation: str
  tts_audio_bytes: Optional[bytes]
  tts_mime: str = "audio/wav"


# --- Model loading (lazy) ---
_whisper = None
_nllb_tokenizer = None
_nllb_model = None
_tts = None


def _load_whisper():
  global _whisper
  if _whisper is not None:
    return _whisper
  import whisper
  _whisper = whisper.load_model("base")
  return _whisper


def _load_nllb():
  global _nllb_tokenizer, _nllb_model
  if _nllb_model is not None and _nllb_tokenizer is not None:
    return _nllb_tokenizer, _nllb_model
  from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
  model_name = "facebook/nllb-200-distilled-600M"
  _nllb_tokenizer = AutoTokenizer.from_pretrained(model_name)
  _nllb_model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
  return _nllb_tokenizer, _nllb_model


def _load_tts():
  global _tts
  if _tts is not None:
    return _tts
  from TTS.api import TTS
  # A default multi-lingual model (change based on your needs)
  _tts = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False)
  return _tts


def transcribe_with_whisper(audio_path: str, src_lang: str) -> str:
  model = _load_whisper()
  # Let Whisper detect if src_lang is empty
  kwargs = {}
  if src_lang:
    kwargs["language"] = src_lang
  result = model.transcribe(audio_path, **kwargs)
  return (result.get("text") or "").strip()


def translate_with_nllb(text: str, src_lang: str, tgt_lang: str) -> str:
  tok, model = _load_nllb()
  if not text.strip():
    return ""

  # NLLB expects language codes like "eng_Latn". Mapping is project-specific.
  # For MVP we pass through and rely on you to add a mapping table.
  # If you send ISO-639-1 (en, ur, hi), you MUST map them here.
  src = src_lang
  tgt = tgt_lang

  inputs = tok(text, return_tensors="pt")
  forced_bos = tok.lang_code_to_id.get(tgt) if hasattr(tok, "lang_code_to_id") else None
  if forced_bos is None:
    # fallback: no forced language
    out = model.generate(**inputs, max_new_tokens=256)
  else:
    out = model.generate(**inputs, forced_bos_token_id=forced_bos, max_new_tokens=256)
  return tok.batch_decode(out, skip_special_tokens=True)[0].strip()


def tts_with_coqui(text: str, lang: str) -> Optional[bytes]:
  if not text.strip():
    return None
  tts = _load_tts()
  # Coqui TTS may require speaker_wav / language settings depending on model.
  # We return WAV bytes written to a temp file then read back.
  import tempfile
  import os

  fd, path = tempfile.mkstemp(suffix=".wav")
  os.close(fd)
  try:
    # xtts_v2 supports language argument for some setups; adjust as needed.
    tts.tts_to_file(text=text, file_path=path, language=lang or None)
    with open(path, "rb") as f:
      return f.read()
  finally:
    try:
      os.remove(path)
    except OSError:
      pass


@app.get("/health")
def health():
  return {"ok": True}


@app.post("/pipeline")
async def pipeline(
  audio: UploadFile = File(...),
  src_lang: str = Form(""),
  tgt_lang: str = Form(""),
  include_tts: str = Form("1"),
):
  import tempfile
  import os

  # Save uploaded audio to temp file
  suffix = ".wav"
  fd, path = tempfile.mkstemp(suffix=suffix)
  os.close(fd)
  try:
    data = await audio.read()
    with open(path, "wb") as f:
      f.write(data)

    transcript = transcribe_with_whisper(path, src_lang)
    translation = translate_with_nllb(transcript, src_lang, tgt_lang)

    tts_audio = None
    if include_tts == "1":
      tts_audio = tts_with_coqui(translation, tgt_lang)

    payload = {
      "transcript": transcript,
      "translation": translation,
      "tts_mime": "audio/wav",
      "tts_audio_b64": base64.b64encode(tts_audio).decode("utf-8") if tts_audio else "",
    }
    return JSONResponse(payload)
  except Exception as e:
    return JSONResponse({"error": str(e)}, status_code=500)
  finally:
    try:
      os.remove(path)
    except OSError:
      pass

