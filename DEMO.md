# ConvoBridge — FYP Demo Runbook

Demo-ready checklist for examiners. Estimated time: **15–20 minutes**.

## 1. Start the AI backend

```powershell
cd D:\Current_Projects\AI-Conference-Backend
venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --reload-exclude models
```

Open http://127.0.0.1:8000/docs and confirm `/health` returns OK.

Optional smoke tests:

```powershell
pytest tests/test_api_smoke.py -q
```

## 2. Models checklist

| Asset | Location |
|-------|----------|
| Whisper STT | `models/faster-whisper-base/` |
| Opus-MT (en/ur/ar/hi) | `models/opus/` and/or `models/cache/models--Helsinki-NLP--*` |
| Summarization LoRA | `summarization/models/gemma3-meeting-lora/` |
| Chatbot LoRA | `chatbot/models/gemma3-chatbot-lora/` |
| XTTS / Gemma base | downloaded on first use into HF/Coqui cache (needs network once) |

Pre-download Opus pairs if needed:

```powershell
python download_opus_models.py
```

## 3. Flutter app

Point the client at your PC (USB phone / emulator):

```powershell
cd front_end
flutter run --dart-define=AI_SERVER_BASE_URL=http://127.0.0.1:8000
```

On a physical phone, use your LAN IP instead of `127.0.0.1`.

## 4. Two-phone multilingual meeting (the main demo)

### How it works

Each phone captures **its own** microphone, transcribes it in **that speaker's**
language, and publishes the recognized sentence as text to
`meetings/{meetingId}/utterances` in Firestore. Every other phone listens to
that collection, translates each incoming sentence into **its own** chosen
language, shows it as a caption and speaks it with the device TTS engine.

So the language each person picks controls what **they** hear and read. The
host and the joiner pick independently; neither choice affects the other.

### Before the first run

1. **Firestore rules** must allow the `utterances` subcollection. Rules do not
   cascade, so a rule written only for `meetings/{id}` is not enough — the
   symptom is that captions and audio never reach the other phone. Deploy the
   rules in `firestore.rules`, or paste them into the Firebase console.
2. **Install the TTS voices** on both phones for the languages you will demo:
   *Settings → System → Languages & input → Text-to-speech output* → install
   Urdu / Arabic / Hindi voice data. Without the voice the caption still
   appears but nothing is spoken.

### Running it

Open two terminals, one per phone:

```powershell
# Terminal 1 - phone A
cd front_end
flutter devices                      # copy the two device ids
flutter run -d <PHONE_A_ID> --dart-define=AI_SERVER_BASE_URL=http://<YOUR_LAN_IP>:8000

# Terminal 2 - phone B
cd front_end
flutter run -d <PHONE_B_ID> --dart-define=AI_SERVER_BASE_URL=http://<YOUR_LAN_IP>:8000
```

Both phones and the PC must be on the same Wi-Fi, and the URL must be your PC's
LAN IP (`ipconfig`), not `127.0.0.1`.

Then:

1. **Phone A**: Create meeting. A language sheet appears — pick e.g. **Urdu**.
   Note the 6-character meeting code in the top bar.
2. **Phone B**: Join meeting with that code. Pick a *different* language,
   e.g. **English**.
3. **Phone A speaks Urdu.** After a short pause, phone B shows an English
   caption with the speaker's name and speaks it in English.
4. **Phone B replies in English.** Phone A hears it in Urdu.
5. Either phone can change its language mid-call from the **language chip** in
   the top bar; the change only affects that phone.
6. **End** the meeting → **Summary** opens with the transcript of *both*
   speakers.
7. Tap **Ask chatbot about this transcript** and ask about the meeting.

### Controls worth pointing out

- Raw Agora audio from the other person is always muted. You hear **only** the
  translated voice in the language you selected (e.g. English → English only).
- The microphone pauses automatically while translated speech is playing, so
  the phone does not transcribe its own loudspeaker back into the meeting.

### If nothing arrives on the second phone

| Symptom | Cause |
|---------|-------|
| Captions appear locally, never remotely | Firestore rules block the `utterances` subcollection |
| Caption arrives but no voice | That language's TTS voice is not installed on the phone |
| Nothing at all, "You: …" stays empty | Backend unreachable — check the LAN IP and that port 8000 is allowed through the firewall |

## 5. Docker (optional packaging)

```powershell
docker build -t convobridge-ai .
docker run --rm -p 8000:8000 `
  -v ${PWD}/models:/app/models `
  -v ${PWD}/summarization/models:/app/summarization/models `
  -v ${PWD}/chatbot/models:/app/chatbot/models `
  convobridge-ai
```

## Future work (out of this demo scope)

- In-meeting file sharing
- Host mute / remove participant
- Cloud host (GCP/AWS) beyond Docker
- True streaming WebSocket captions (current design is 5s utterance chunks)
