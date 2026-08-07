# Module 2 — Meeting Summarization (Gemma 3)

Post-meeting intelligence for **ConvoBridge**: transcript → **summary**, **key points**, **action items**.

**Model:** Gemma 3 (`google/gemma-3-4b-it` for Colab fine-tuning, `google/gemma-3-1b-it` for local inference)

---

## Directory layout

```text
summarization/
  config.yaml              # training + inference settings
  requirements-train.txt   # Colab-only dependencies
  prompts/
    meeting_summary.txt    # production prompt template
  data/
    raw/                   # downloaded datasets (jsonl)
    processed/             # training-ready jsonl
  models/
    gemma3-meeting-lora/   # LoRA adapter after Colab training
  scripts/
    download_datasets.py
    prepare_training_data.py
    parse_output.py
    test_inference.py
  colab/
    train_qlora.py         # QLoRA fine-tuning (GPU)
  samples/
    sample_transcript.txt
```

API integration lives in `app/services/summarization.py` → `POST /summarize`.

---

## Step-by-step execution plan

### Phase 1 — Setup (your laptop)

**Step 1.** Activate environment and install new deps:

```powershell
cd D:\Current_Projects\AI-Conference-Backend
venv\Scripts\activate
pip install peft datasets pyyaml
```

**Step 2.** Accept Gemma license on Hugging Face:

- https://huggingface.co/google/gemma-3-1b-it
- https://huggingface.co/google/gemma-3-4b-it

Login locally:

```powershell
huggingface-cli login
```

**Step 3.** Download training datasets:

```powershell
python summarization/scripts/download_datasets.py
```

**Step 4.** Build processed training file:

```powershell
python summarization/scripts/prepare_training_data.py
```

Output: `summarization/data/processed/train_meeting_summary.jsonl`

---

### Phase 2 — Fine-tune on Google Colab (recommended)

Your 8 GB laptop should **not** fine-tune Gemma 3. Use Colab GPU.

**Step 5.** Open Google Colab → **Runtime → Change runtime type → GPU (T4/L4)**.

**Step 6.** Upload this repo (or clone from Git) into Colab.

**Step 7.** Install training deps:

```python
!pip install -q -r summarization/requirements-train.txt
!huggingface-cli login
```

**Step 8.** Upload `train_meeting_summary.jsonl` if prepared on laptop:

- `summarization/data/processed/train_meeting_summary.jsonl`

Or run download + prepare scripts in Colab first.

**Step 9.** Train:

```python
!python summarization/colab/train_qlora.py
```

**Step 10.** Save adapter to Drive and download to laptop/server:

```text
summarization/models/gemma3-meeting-lora/
```

---

### Phase 3 — Inference (16 GB machine recommended)

**Step 11.** Place adapter folder at:

```text
summarization/models/gemma3-meeting-lora/
```

**Step 12.** Optional `.env` overrides:

```env
SUMMARIZATION_MODEL=google/gemma-3-1b-it
SUMMARIZATION_ADAPTER_PATH=summarization/models/gemma3-meeting-lora
DEVICE=cpu
```

**Step 13.** Smoke test:

```powershell
python summarization/scripts/test_inference.py
```

**Step 14.** Start API:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open http://127.0.0.1:8000/docs → **POST /summarize**

---

## API usage

**Endpoint:** `POST /summarize`

```json
{
  "meeting_id": "meet-001",
  "transcript": "Host: We discussed API integration...",
  "language": "en"
}
```

**Response:**

```json
{
  "meeting_id": "meet-001",
  "summary": "...",
  "key_points": ["...", "..."],
  "action_items": ["Participant A: ..."],
  "raw": "SUMMARY:\n..."
}
```

---

## Datasets (with links)

| Dataset | Purpose | Link |
|---------|---------|------|
| SAMSum | Dialogue summarization warm-up | https://huggingface.co/datasets/knkarthick/samsum |
| QMSum | Meeting/query summarization | https://github.com/Yale-LILY/QMSum |
| AMI | Real meeting domain (optional) | https://groups.inf.ed.ac.uk/ami/download/ |
| ICSI | Real meeting domain (optional) | https://groups.inf.ed.ac.uk/ami/icsi/download/ |

---

## Hardware guidance

| Machine | Role |
|---------|------|
| 8 GB laptop | Data prep, API dev, single-module tests |
| 16 GB DDR4 PC | Inference + full backend demo |
| Google Colab GPU | QLoRA fine-tuning (Gemma 3 4B) |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `MemoryError` on laptop | Use 16 GB machine or `gemma-3-1b-it` only |
| HF gated model error | Accept license + `huggingface-cli login` |
| Empty KEY_POINTS | Improve fine-tune data or prompt; check `parse_output.py` |
| Colab disconnect | Save checkpoints to Google Drive every epoch |

---

## Next module (after summarization)

- **Module 2B:** Transcript chatbot (`POST /chat`) with FAISS retrieval over meeting chunks.
