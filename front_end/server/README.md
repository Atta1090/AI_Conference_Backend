# AI Server (FastAPI) — LEGACY / DO NOT USE FOR NEW INTEGRATION

> **Deprecated for ConvoBridge Flutter.**
>
> The Flutter app is now wired to the **real backend** at the repo root:
> `AI-Conference-Backend/app/` via `POST /pipeline/process`, `POST /translate`, `POST /summarize`.
>
> Keep this folder only for historical Colab experiments. Prefer:
>
> ```bash
> cd AI-Conference-Backend
> uvicorn app.main:app --host 0.0.0.0 --port 8000
> ```
>
> See `front_end/README.md` for Flutter `AI_SERVER_BASE_URL` setup.

---

# (Legacy) AI Server (FastAPI) — Colab + ngrok

This folder contains a FastAPI server that exposes a single endpoint:

- `POST /pipeline`: audio → Whisper STT → NLLB-200 translate → Coqui TTS

## Quick start (local Python)

1) Create venv and install:

```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

2) Run:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

3) Test:

- `GET /health`

## Colab + ngrok (recommended for GPU)

1) Open a Colab notebook and run:

```bash
pip install -r requirements.txt
```

2) Start server:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

3) In a new cell, start ngrok on port 8000 and copy the HTTPS URL.

4) Run Flutter with:

```bash
flutter run --dart-define=AI_SERVER_BASE_URL=https://xxxx.ngrok-free.app
```

## Notes

- Models are heavy. The default code is structured so you can plug in your exact Whisper/NLLB/Coqui model choices.
- If you want streaming (true real-time), we will add websocket endpoints next.

