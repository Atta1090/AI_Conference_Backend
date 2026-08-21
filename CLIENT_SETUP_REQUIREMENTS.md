# ConvoBridge — Complete Client Setup Requirements

This document is the **full handoff guide** for installing, configuring, and
running the ConvoBridge project (FastAPI AI backend + Flutter mobile app).

Follow the steps **in order**. Do not skip sections marked **Required**.

---

## Table of contents

1. [What you receive](#1-what-you-receive)
2. [System requirements](#2-system-requirements)
3. [Install prerequisites](#3-install-prerequisites)
4. [Get the project code](#4-get-the-project-code)
5. [Backend setup (Python / FastAPI)](#5-backend-setup-python--fastapi)
6. [Download / place AI models](#6-download--place-ai-models)
7. [Environment variables](#7-environment-variables)
8. [Firebase & Agora setup](#8-firebase--agora-setup)
9. [Flutter app setup](#9-flutter-app-setup)
10. [Run the system (daily use)](#10-run-the-system-daily-use)
11. [Two-phone multilingual meeting demo](#11-two-phone-multilingual-meeting-demo)
12. [Feature checklist](#12-feature-checklist)
13. [Troubleshooting](#13-troubleshooting)
14. [Delivery checklist (developer → client)](#14-delivery-checklist-developer--client)

---

## 1. What you receive

| Item | Description |
|------|-------------|
| Backend (`app/`, `run_dev.py`, `requirements.txt`) | FastAPI AI service: STT, translation, summary, chatbot |
| Flutter app (`front_end/`) | Android/iOS client: meetings, captions, TTS, translator |
| Firestore rules (`firestore.rules`) | Required for live captions / translated voice |
| Model download script (`download_opus_models.py`) | Downloads Opus-MT translation pairs |
| Docs (`README.md`, `DEMO.md`, this file) | Architecture + demo runbook |

**Usually NOT in the Git repo** (too large or secret — share separately if needed):

| Item | Why |
|------|-----|
| `venv/` | Recreate with `python -m venv` |
| `.env` | Secrets — create from `.env.example` |
| `models/` (Whisper, Opus, HF cache) | Large; download or copy from Drive |
| `summarization/models/`, `chatbot/models/` | Fine-tuned LoRA adapters (if not in package) |
| Firebase service-account private keys | Never commit |

---

## 2. System requirements

### Hardware (Recommended)

| Resource | Minimum | Recommended for demo |
|----------|---------|----------------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32 GB (summary/chatbot on CPU) |
| Disk free | 20 GB | 40 GB+ (models + caches) |
| GPU | Optional | NVIDIA GPU + CUDA speeds Gemma a lot |
| Network | Wi‑Fi for phones + PC | Same LAN for all devices |

### Software

| Software | Version / notes |
|----------|-----------------|
| OS | Windows 10/11 (documented), macOS/Linux also work |
| Python | **3.11** (required; match project) |
| Git | Latest |
| Flutter SDK | Stable, Dart SDK **^3.8.1** (see `front_end/pubspec.yaml`) |
| Android Studio | SDK + platform tools; USB debugging enabled on phones |
| Chrome / Edge | Optional — for http://127.0.0.1:8000/docs |

### Accounts / keys you need

| Service | Purpose |
|---------|---------|
| Firebase project | Auth + Firestore (meetings, utterances) |
| Agora account | Video/audio channels (App ID) |
| Hugging Face account | Gemma models (accept license; may need `HF_TOKEN`) |
| GitHub (optional) | Private repo access if code is delivered via Git |

---

## 3. Install prerequisites

### Step 3.1 — Python 3.11

1. Install Python 3.11 from https://www.python.org/downloads/
2. During install, enable **Add Python to PATH**.
3. Verify:

```powershell
python --version
# Expect: Python 3.11.x
```

### Step 3.2 — Git

```powershell
git --version
```

### Step 3.3 — Flutter

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Verify:

```powershell
flutter doctor
flutter --version
```

3. Fix any issues `flutter doctor` reports (Android SDK, licenses, etc.).

```powershell
flutter doctor --android-licenses
```

### Step 3.4 — Android device setup

On each demo phone:

1. Enable **Developer options** → **USB debugging**.
2. Connect via USB (or wireless debugging).
3. Accept the PC’s RSA fingerprint prompt.
4. Confirm:

```powershell
flutter devices
```

You should see each phone listed with a device ID.

### Step 3.5 — Install on-device TTS voices (Required for spoken translation)

On each phone:

**Settings → System → Languages & input → Text-to-speech output**

Install voice data for languages you will demo: **English, Urdu, Arabic, Hindi**.

**Urdu is required for the client demo.** On each phone:
1. Preferred engine: **Google Text-to-speech**
2. Install **Urdu (Pakistan)** voice data
3. Without it, both-sides-Urdu meetings show captions but often **no spoken audio**

Also ensure Opus Urdu pairs exist on the PC:
`models/opus/opus-mt-en-ur` and `models/opus/opus-mt-ur-en`
(run `python download_opus_models.py` if missing).

Without the voice pack, captions may still appear but **no speech** is heard.

---

## 4. Get the project code

### Option A — Private GitHub (recommended)

```powershell
cd D:\Current_Projects
git clone <PRIVATE_REPO_URL> AI-Conference-Backend
cd AI-Conference-Backend
```

### Option B — Zip / Google Drive

1. Extract the zip to a path **without spaces if possible**, e.g.  
   `D:\Current_Projects\AI-Conference-Backend`
2. If models were shared as a separate zip, extract them into the correct
   folders (see [Section 6](#6-download--place-ai-models)).

---

## 5. Backend setup (Python / FastAPI)

Open PowerShell in the project root:

```powershell
cd D:\Current_Projects\AI-Conference-Backend
```

### Step 5.1 — Create virtual environment

```powershell
python -m venv venv
```

### Step 5.2 — Activate venv

```powershell
.\venv\Scripts\Activate.ps1
```

Your prompt should show `(venv)`.

> If PowerShell blocks scripts:  
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### Step 5.3 — Upgrade pip

```powershell
python -m pip install --upgrade pip
```

### Step 5.4 — Install Python dependencies

```powershell
pip install -r requirements.txt
```

This installs FastAPI, Uvicorn, faster-whisper, torch, transformers, peft,
coqui-tts, and related packages. It can take **10–30+ minutes**.

### Step 5.5 — Confirm import works

```powershell
python -c "from app.main import app; print('OK', app.title)"
```

---

## 6. Download / place AI models

Models are **required** for a working demo. Paths below are relative to the
project root.

### Step 6.1 — Folder layout (target)

```
models/
  faster-whisper-base/     ← Whisper STT (Required)
  opus/                    ← Opus-MT pairs (Required)
  cache/                   ← HuggingFace / Coqui cache (auto-created)
summarization/models/
  gemma3-meeting-lora/     ← Meeting summary LoRA (Required for summary)
chatbot/models/
  gemma3-chatbot-lora/     ← Meeting chatbot LoRA (Required for Q&A)
```

### Step 6.2 — Whisper STT (`faster-whisper-base`) — Required

Place the model at:

```
models/faster-whisper-base/
```

If the developer shared a Drive folder of models, copy that folder here.

Alternatively, download with Hugging Face CLI (venv active):

```powershell
huggingface-cli download Systran/faster-whisper-base --local-dir models/faster-whisper-base
```

### Step 6.3 — Opus-MT translation pairs — Required

```powershell
python download_opus_models.py
```

Downloads ~6 Helsinki Opus-MT pairs (en↔ur, en↔ar, en↔hi) into `models/opus/`.

If `huggingface.co` is blocked or slow:

```powershell
$env:HF_ENDPOINT = "https://hf-mirror.com"
python download_opus_models.py
```

### Step 6.4 — Summarization & chatbot LoRA adapters

Copy (or receive from developer):

| Adapter | Path |
|---------|------|
| Meeting summary | `summarization/models/gemma3-meeting-lora/` |
| Meeting chatbot | `chatbot/models/gemma3-chatbot-lora/` |

Base model `google/gemma-3-1b-it` downloads on **first use** into the HF cache
(needs network + Hugging Face license acceptance).

### Step 6.5 — Hugging Face login (for Gemma) — Required once

1. Create/login at https://huggingface.co  
2. Accept the Gemma model license on the model page.  
3. Create an access token (read).  
4. In the venv:

```powershell
huggingface-cli login
# paste token when prompted
```

Or set for the session:

```powershell
$env:HF_TOKEN = "hf_xxxxxxxx"
```

### Step 6.6 — Verify model presence

```powershell
Test-Path models\faster-whisper-base
Test-Path models\opus
Test-Path summarization\models\gemma3-meeting-lora
Test-Path chatbot\models\gemma3-chatbot-lora
```

All should return `True` before a full feature demo.

---

## 7. Environment variables

The backend reads settings from **environment variables** (see
`app/core/config.py`). Defaults work for local CPU demos.

### Step 7.1 — Optional `.env` file

Copy the example:

```powershell
copy .env.example .env
```

> Note: the app does **not** auto-load `.env` unless you export variables
> yourself or use a loader. Safest approach on Windows: set variables in the
> same PowerShell session before `python run_dev.py`, or set system env vars.

### Step 7.2 — Important variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `DEVICE` | `cpu` | `cpu` or `cuda` |
| `STT_COMPUTE_TYPE` | `int8` (CPU) | Whisper compute type |
| `TRANSLATION_NUM_BEAMS` | `4` | Opus beam search quality |
| `OPUS_CPU_DYNAMIC_INT8` | `false` | Keep **off** (hurts quality) |
| `GEMMA_CPU_DYNAMIC_INT8` | `false` | Keep **off** (hurts quality) |
| `ENABLE_BACKEND_TTS` | `false` | Flutter uses on-device TTS |
| `HF_TOKEN` | — | Hugging Face access for Gemma |
| `STT_MODEL_PATH` | `models/faster-whisper-base` | Override Whisper path |

Example (CPU demo session):

```powershell
$env:DEVICE = "cpu"
$env:ENABLE_BACKEND_TTS = "false"
```

---

## 8. Firebase & Agora setup

### Step 8.1 — Firebase project

1. Open https://console.firebase.google.com  
2. Use the project that matches the app’s `google-services.json` /  
   `firebase_options.dart`, **or** create a new project and regenerate Flutter
   Firebase config with FlutterFire CLI.
3. Enable:
   - **Authentication** → Email/Password (and any providers the app uses)
   - **Cloud Firestore**

### Step 8.2 — Deploy Firestore rules — Required

Live captions / translated voice use:

```
meetings/{meetingId}/utterances/{utteranceId}
calls/{callId}/utterances/{utteranceId}
```

Rules **do not cascade**. Deploy the provided file:

```powershell
# If Firebase CLI is installed and logged in:
firebase deploy --only firestore:rules
```

Or paste the contents of `firestore.rules` into  
**Firebase Console → Firestore → Rules → Publish**.

If rules are wrong: one phone speaks, the other never gets captions/voice.

### Step 8.3 — Flutter Firebase files

Ensure these exist and match the Firebase project:

| File | Role |
|------|------|
| `front_end/lib/firebase_options.dart` | Flutter Firebase init |
| `front_end/android/app/google-services.json` | Android Firebase |

Share these securely with the client if they were not in the zip/repo.

### Step 8.4 — Agora

1. Create an Agora project → copy **App ID**.  
2. Pass it when running Flutter:

```powershell
flutter run --dart-define=AGORA_APP_ID=YOUR_AGORA_APP_ID
```

Or update the default in `front_end/lib/app_config.dart` (then full rebuild).

---

## 9. Flutter app setup

```powershell
cd D:\Current_Projects\AI-Conference-Backend\front_end
flutter pub get
```

### Step 9.1 — Point app at your PC’s AI server

Physical phones **cannot** use `127.0.0.1` (that is the phone itself).

1. On the PC, find Wi‑Fi IPv4:

```powershell
ipconfig
# Look under "Wireless LAN adapter Wi-Fi" → IPv4 Address
# Example: 192.168.100.27
```

2. Update `front_end/lib/app_config.dart` default **or** always pass:

```powershell
--dart-define=AI_SERVER_BASE_URL=http://192.168.100.27:8000
```

`AI_SERVER_BASE_URL` is compile-time. After changing IP, do a **full restart**
(`flutter run` again), not only hot reload.

### Step 9.2 — Same Wi‑Fi

PC + both phones must be on the **same Wi‑Fi** network. Guest/AP isolation
networks often block phone → PC connections.

### Step 9.3 — Windows Firewall

Allow **Python** inbound on private networks for port **8000**, or create an
inbound rule for TCP 8000.

---

## 10. Run the system (daily use)

### Step 10.1 — Start AI backend

```powershell
cd D:\Current_Projects\AI-Conference-Backend
.\venv\Scripts\Activate.ps1
python run_dev.py
```

You must see:

```
Uvicorn running on http://0.0.0.0:8000
Application startup complete.
```

Verify in a browser on the PC:

- http://127.0.0.1:8000/docs  
- http://127.0.0.1:8000/health  

From a phone browser on the same Wi‑Fi:

- http://`<PC_IP>`:8000/docs  

If the phone browser cannot open docs, the Flutter app will also fail
(`Connection timed out`).

### Step 10.2 — Optional API smoke tests

```powershell
pytest tests/test_api_smoke.py -q
```

### Step 10.3 — Run Flutter on one or two phones

```powershell
cd D:\Current_Projects\AI-Conference-Backend\front_end
flutter devices

# Phone A
flutter run -d <PHONE_A_ID> --dart-define=AI_SERVER_BASE_URL=http://<PC_IP>:8000

# Phone B (second terminal)
flutter run -d <PHONE_B_ID> --dart-define=AI_SERVER_BASE_URL=http://<PC_IP>:8000
```

---

## 11. Two-phone multilingual meeting demo

### How it works (short)

1. Each phone records **its own** mic.  
2. Backend STT recognizes speech in that speaker’s language.  
3. Text is published to Firestore `utterances`.  
4. The other phone translates into **its** preferred language, shows caption,
   and speaks via **on-device TTS**.  
5. Raw Agora remote audio is muted so users hear only the translated voice.

### Demo steps

1. Start backend (`python run_dev.py`) — confirm `0.0.0.0:8000`.  
2. Launch app on Phone A and Phone B with correct `AI_SERVER_BASE_URL`.  
3. Sign in / register on both phones (Firebase Auth).  
4. **Phone A**: Create meeting → pick language (e.g. **Urdu**) → note 6-char code.  
5. **Phone B**: Join with code → pick different language (e.g. **English**).  
6. Phone A speaks → after a short pause, Phone B shows English caption + voice.  
7. Phone B replies → Phone A hears Urdu.  
8. End meeting → open **Summary**.  
9. Open **Ask chatbot** and ask a question about the transcript.

### Also test

| Screen | What to verify |
|--------|----------------|
| AI Translator | English paragraph → full Urdu (sentence-by-sentence Opus-MT) |
| Language chip mid-call | Only that phone’s captions/voice language changes |
| History | Past sessions listed |

---

## 12. Feature checklist

| # | Feature | Backend | Flutter |
|---|---------|---------|---------|
| 1 | Preferred language per user | translate + STT | language picker |
| 2 | Live captions in selected language | STT + translate | caption overlay |
| 3 | Translated spoken voice | translate | `flutter_tts` |
| 4 | Meeting summarization | Gemma + LoRA | summary screen |
| 5 | Chatbot on transcript | Gemma + LoRA | chatbot UI |
| 6 | Two-phone cross-language meeting | all of above + Firestore | create/join meeting |
| 7 | Standalone text translator | `/translate` | AI Translator screen |

---

## 13. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Connection timed out` to `192.168.x.x:8000` | Wrong IP / firewall / backend bound to localhost | `ipconfig`, update `AI_SERVER_BASE_URL`, use `python run_dev.py` (`0.0.0.0`), allow port 8000 |
| `/docs` works on PC, not on phone | Different Wi‑Fi or AP isolation | Same network; test phone browser |
| Captions never reach other phone | Firestore rules missing `utterances` | Deploy `firestore.rules` |
| Caption OK, no voice | TTS voice not installed | Install language voice pack |
| Translation is one short wrong sentence | Old backend without sentence split | Restart backend with latest `translation.py` |
| Summary/chatbot fail / HF error | No HF login / license | `huggingface-cli login`, accept Gemma license |
| Port 8000 already in use | Another Python process | Stop old process or change port |
| Hot reload didn’t change server URL | `fromEnvironment` is compile-time | Full `flutter run` restart |
| Using `.\.venv\...` | Wrong folder name | Use `.\venv\Scripts\Activate.ps1` |

---

## 14. Delivery checklist (developer → client)

Use this when handing over the project.

### Must send

- [ ] Private Git repo invite **or** project zip (source)
- [ ] This file: `CLIENT_SETUP_REQUIREMENTS.md`
- [ ] `README.md` + `DEMO.md`
- [ ] `firestore.rules` (and confirm deployed on the Firebase project)
- [ ] Firebase config files if not in repo (`google-services.json`, `firebase_options.dart`)
- [ ] Agora App ID (secure channel)
- [ ] Whisper folder **or** download instructions
- [ ] Opus download command verified
- [ ] Summarization + chatbot LoRA folders (Drive if large)
- [ ] Hugging Face notes (Gemma license + token)
- [ ] 15–20 minute live demo walkthrough

### Must NOT put in public Git

- [ ] `.env` / real API tokens
- [ ] Firebase service-account JSON with private keys
- [ ] Unnecessary: `venv/`, `uploads/`, huge raw training datasets

### Confirm before handover meeting

- [ ] `python run_dev.py` shows `0.0.0.0:8000`
- [ ] Phone browser opens `http://<PC_IP>:8000/docs`
- [ ] Two-phone meeting: both directions speak + captions
- [ ] Translator: multi-sentence English → full Urdu
- [ ] Summary + chatbot open after meeting

---

## Quick reference (commands only)

```powershell
# Backend
cd D:\Current_Projects\AI-Conference-Backend
.\venv\Scripts\Activate.ps1
python download_opus_models.py
python run_dev.py

# Flutter (replace IP and device id)
cd D:\Current_Projects\AI-Conference-Backend\front_end
flutter run -d <DEVICE_ID> --dart-define=AI_SERVER_BASE_URL=http://<PC_IP>:8000
```

PC LAN IP:

```powershell
ipconfig
```

API docs: http://127.0.0.1:8000/docs  

For a shorter examiner-focused demo script, see **`DEMO.md`**.  
For architecture overview, see **`README.md`**.
