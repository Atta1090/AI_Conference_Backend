# ConvoBridge Flutter Frontend

Flutter client for ConvoBridge. AI features talk to the **real FastAPI backend** in the repo root (`app/`), not the legacy nested `front_end/server/`.

## Connected AI endpoints

| Screen / feature | Backend endpoint |
|---|---|
| Translate screen | `POST /translate` |
| Summary screen | `POST /summarize` |
| AI Chat (Q&A) | `POST /chatbot/ask` |
| 1:1 audio call | `POST /pipeline/process` + `GET /media/tts/...` |
| Health check (client) | `GET /health` |

Chatbot uses adapter at `chatbot/models/gemma3-chatbot-lora/` when present.

## Configure backend URL

Set `AI_SERVER_BASE_URL` (no trailing slash).

### Same PC (Flutter desktop / Chrome)

```bash
flutter run --dart-define=AI_SERVER_BASE_URL=http://127.0.0.1:8000
```

### Android emulator → host machine backend

```bash
flutter run --dart-define=AI_SERVER_BASE_URL=http://10.0.2.2:8000
```

### Physical phone on same Wi‑Fi as GPU PC

```bash
flutter run --dart-define=AI_SERVER_BASE_URL=http://192.168.x.x:8000
```

Replace `192.168.x.x` with your PC LAN IP.

### ngrok (optional)

```bash
flutter run --dart-define=AI_SERVER_BASE_URL=https://xxxx.ngrok-free.app
```

Client automatically adds `ngrok-skip-browser-warning` when the URL contains `ngrok`.

Default in [`lib/app_config.dart`](lib/app_config.dart): `http://127.0.0.1:8000`.

## Start the real backend

From repo root (`AI-Conference-Backend`):

```bash
# Activate venv first
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Use `0.0.0.0` so phones on LAN can connect. Do **not** use `front_end/server` for this integration.

## Connectivity checklist

1. Open `http://<backend-host>:8000/health` in the phone/emulator browser → should return JSON.
2. Open `http://<backend-host>:8000/docs` → Swagger UI.
3. Flutter **Translate**: English → Urdu text.
4. Flutter **Summary**: paste a 20+ character transcript → overview / key points / action items.
5. 1:1 audio call: short speak → transcript + translation; TTS plays from `/media/tts/...`.
6. If summarizing with fine-tuned weights, ensure:

```text
summarization/models/gemma3-meeting-lora/adapter_config.json
summarization/models/gemma3-meeting-lora/adapter_model.safetensors
```

## Legacy note

[`server/`](server/) (old Colab `/pipeline` + base64 TTS) is **legacy**. The Flutter `AiClient` now calls the root `app/` API:

- `POST /pipeline/process` (multipart field `file`)
- response field `translated_text`
- TTS via `tts_audio_url` then downloaded by the client

## Agora

Override with:

```bash
flutter run --dart-define=AGORA_APP_ID=your_app_id
```
