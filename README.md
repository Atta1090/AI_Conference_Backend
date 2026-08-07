# AI Conference Backend (ConvoBridge)

Python/FastAPI backend for **ConvoBridge**, an AI-powered multilingual video
conferencing app. This service exposes the core **meeting audio pipeline** as
REST APIs, using fully **local, open-source models** (no paid cloud APIs).

**Client / full install guide (every step):** see
[`CLIENT_SETUP_REQUIREMENTS.md`](CLIENT_SETUP_REQUIREMENTS.md).  
**Short demo runbook:** see [`DEMO.md`](DEMO.md).

## Meeting Audio Pipeline

```
raw audio  ->  noise reduction  ->  speech-to-text  ->  translation  ->  text-to-speech
             (spectral gating)     (faster-whisper)      (Opus-MT)         (Coqui XTTS v2)
```

Supported translation languages (Pakistan-focused): **English, Urdu, Arabic, Hindi**.
Urdu↔English is the priority pair; other directions use English as a pivot when needed.

## Modules & Endpoints

| Stage            | Model / Library        | Endpoint             |
| ---------------- | ---------------------- | -------------------- |
| Noise reduction  | `noisereduce`          | `POST /noise/reduce` |
| Speech-to-Text   | `faster-whisper` (base)| `POST /stt/transcribe` |
| Translation      | Helsinki Opus-MT pairs | `POST /translate`    |
| Text-to-Speech   | Coqui XTTS v2          | `POST /tts/speak`    |
| Full pipeline    | all of the above       | `POST /pipeline/process` |
| Health / info    | —                      | `GET /health`, `GET /languages` |

Synthesized audio is served from `/media/tts/<file>.wav`.

## Tech Stack

- FastAPI + Uvicorn
- Python 3.11
- faster-whisper (STT), noisereduce (denoise), Helsinki Opus-MT (translation), Coqui XTTS v2 (TTS)
- librosa / soundfile for audio I/O

## Setup

```bash
python -m venv venv
venv\Scripts\activate            # Windows
pip install -r requirements.txt

# STT model is expected at models/faster-whisper-base
# Opus-MT / XTTS weights download on first use
# into models/cache (needs HuggingFace network access).

# Pre-download all 6 Opus-MT pairs (~300 MB each):
python download_opus_models.py

# If huggingface.co is blocked/slow:
#   set HF_ENDPOINT=https://hf-mirror.com
#   python download_opus_models.py
```

## Run

```bash
# Recommended: only watches app/ so HF cache writes do not abort downloads
python run_dev.py

# Do NOT use bare --reload from the repo root — StatReload picks up *.py
# files written into models/cache/ and restarts mid-download.
# If you prefer uvicorn CLI:
#   uvicorn app.main:app --reload --reload-dir app
```

Then open the interactive API docs at http://127.0.0.1:8000/docs

## Configuration

All settings have defaults and can be overridden via environment variables
(see `app/core/config.py`), e.g. `DEVICE=cuda`, `STT_COMPUTE_TYPE=float16`,
`NOISE_REDUCTION_STRENGTH=0.9`, `TTS_SPEAKER_WAV=/path/to/voice.wav`.

### Gemma quantization on CPU

`GEMMA_CPU_DYNAMIC_INT8` defaults to **off**. Dynamic INT8 roughly halves the
RAM Gemma needs, but on a 1B model it degrades output badly — measured on this
repo it produced corrupted tokens and one sentence repeated in place of the
whole summary. Full precision on CPU needs about 4 GB and produces usable
summaries and chatbot answers. Turn INT8 back on (`GEMMA_CPU_DYNAMIC_INT8=1`)
only if the model will not otherwise fit, accepting much lower quality.

`SUMMARIZATION_MAX_NEW_TOKENS` defaults to 384. A meeting summary needs far
less than the previous 1024, and each extra token costs real time on CPU.

## Project Layout

```
app/
  core/         config, language code mappings
  schemas/      pydantic request/response models
  services/     audio_utils, noise_reduction, stt, translation, tts, pipeline
  routers/      health, stt, noise, translation, tts, pipeline
  main.py       FastAPI app wiring
models/         local model weights (faster-whisper-base, cache/)
sample_audio/   sample clips for testing
```

## Notes

- Coqui XTTS v2 does not include an Urdu voice; the pipeline falls back to the
  closest available voice (Hindi) for Urdu TTS. Translation still targets Urdu.
- Real-time video (Agora/WebRTC), auth and the database (Firebase) are handled
  by the Flutter client per the project document; this backend is the AI layer.
