# Google Cloud GPU backend (separate from local laptop setup)

This folder is **optional**. Your normal local flow (`python run_dev.py` + USB phone) stays unchanged.

Use this only when you want the FastAPI backend on a **Google Cloud GPU VM** for speed.
The Flutter app still runs on your phone; only the AI server moves to the cloud.

## What stays the same
- Existing app code is not modified for this path
- Local `run_dev.py` still works on your laptop
- Phone still uses `flutter_tts` for voice (backend XTTS stays disabled by default)

## What gets faster on GPU
- Whisper STT
- Opus translation
- Gemma chatbot / summarization

---

## Tonight checklist (Google Cloud free trial)

### 1) Create / open Google Cloud
1. Go to https://console.cloud.google.com/
2. Start **Free Trial** (needs a credit/debit card; Google usually gives ~$300 credit)
3. Create or select a project, e.g. `convobridge-demo`

### 2) Enable APIs
In Cloud Shell or local `gcloud`:

```bash
gcloud services enable compute.googleapis.com
```

### 3) Create a GPU VM (recommended starter)

```bash
gcloud compute instances create convobridge-gpu \
  --zone=us-central1-a \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --maintenance-policy=TERMINATE \
  --boot-disk-size=100GB \
  --image-family=pytorch-latest-gpu \
  --image-project=deeplearning-platform-release \
  --scopes=https://www.googleapis.com/auth/cloud-platform
```

Notes:
- T4 is usually the easiest GPU to get on trial
- If GPU quota is denied, request **NVIDIA T4** quota for that region, or try another zone (`us-east1-c`, `europe-west4-a`)
- Deep Learning VM images already include NVIDIA drivers + CUDA-friendly Python

### 4) Open port 8000 (so your phone can reach the API)

```bash
gcloud compute firewall-rules create allow-convobridge-8000 \
  --allow=tcp:8000 \
  --target-tags=convobridge \
  --source-ranges=0.0.0.0/0 \
  --description="ConvoBridge FastAPI"
```

Then attach the network tag to the VM:

```bash
gcloud compute instances add-tags convobridge-gpu \
  --zone=us-central1-a \
  --tags=convobridge
```

### 5) Copy project to the VM

From your PC (PowerShell), in the repo root:

```powershell
gcloud compute scp --recurse `
  "D:\Current_Projects\AI-Conference-Backend" `
  convobridge-gpu:~/AI-Conference-Backend `
  --zone=us-central1-a `
  --compress
```

Or clone from GitHub on the VM if the repo is pushed.

### 6) SSH into the VM and install

```bash
gcloud compute ssh convobridge-gpu --zone=us-central1-a
```

On the VM:

```bash
cd ~/AI-Conference-Backend
bash cloud_gpu/setup_vm.sh
```

Set your Hugging Face token (gated Gemma):

```bash
export HF_TOKEN="hf_xxxxxxxx"
export DEVICE=cuda
```

Start the cloud backend (separate entrypoint — does not replace local `run_dev.py`):

```bash
source .venv_cloud/bin/activate
python cloud_gpu/run_cloud.py
```

You should see something like: `Uvicorn running on http://0.0.0.0:8000`

### 7) Get the VM public IP

```bash
gcloud compute instances describe convobridge-gpu \
  --zone=us-central1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Example: `34.123.45.67`

### 8) Point Flutter at the cloud (no code edits)

On your PC, with phone connected:

```powershell
cd D:\Current_Projects\AI-Conference-Backend\front_end
flutter run --dart-define=AI_SERVER_BASE_URL=http://YOUR_VM_PUBLIC_IP:8000
```

Or use the helper script:

```powershell
.\cloud_gpu\flutter_run_cloud.ps1 -AiServerUrl "http://YOUR_VM_PUBLIC_IP:8000"
```

**Do not use** `adb reverse` for this path — the phone talks to the public cloud IP directly (phone needs internet).

### 9) Quick health check

From your PC browser or PowerShell:

```powershell
curl http://YOUR_VM_PUBLIC_IP:8000/health
```

---

## Cost / safety tips for demo night
- **Stop the VM** when done so credits are not burned:
  ```bash
  gcloud compute instances stop convobridge-gpu --zone=us-central1-a
  ```
- GPU VMs are the expensive part — don’t leave them running overnight
- Keep `HF_TOKEN` as an environment variable; don’t commit it

## Fallback if GPU quota fails
1. Request GPU quota in IAM & Admin → Quotas
2. Or create a **CPU-only** larger VM (`n1-standard-8`) — still often faster than your 8 GB laptop, but not as fast as T4
3. Or stay on local laptop for the video (safest if time is short)

## Local vs cloud (how you choose each day)

| Goal | Command |
|---|---|
| Local laptop (USB phone) | `python run_dev.py` + `adb reverse` + `flutter run` |
| Cloud GPU | VM: `python cloud_gpu/run_cloud.py` + phone: `flutter run --dart-define=AI_SERVER_BASE_URL=http://IP:8000` |
