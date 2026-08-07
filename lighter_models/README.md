# Lighter models — fine-tuning (separate from Gemma)

Ready-to-run fine-tuning for CPU-friendly models. **Does not change** your current Gemma chatbot/summarization production path.

| Task | Lighter model | Train script | Config | Output folder |
|---|---|---|---|---|
| Summarization | `google/flan-t5-small` | `summarization/colab/train_flan_t5_small.py` | `summarization/config_flan_t5_small.yaml` | `summarization/models/flan-t5-small-meeting/` |
| Chatbot | `Qwen/Qwen2.5-0.5B-Instruct` | `chatbot/colab/train_qwen05_chatbot.py` | `chatbot/config_qwen05.yaml` | `chatbot/models/qwen25-05b-chatbot-lora/` |

Approximate RAM after fine-tune (CPU inference): T5-small ~1–1.5 GB, Qwen-0.5B ~1.5–3 GB (vs Gemma ~4–6 GB).

---

## Colab notebooks (upload these)

| Notebook | Model |
|---|---|
| [`summarization/colab/train_flan_t5_small.ipynb`](../summarization/colab/train_flan_t5_small.ipynb) | FLAN-T5-small summarization |
| [`chatbot/colab/train_qwen05_chatbot.ipynb`](../chatbot/colab/train_qwen05_chatbot.ipynb) | Qwen2.5-0.5B chatbot |

Open in Google Colab → **Runtime → GPU (T4)** → Run all.

---

## 1) Summarization — FLAN-T5-small

### Prepare data (same as Gemma)

```powershell
cd D:\Current_Projects\AI-Conference-Backend
.\venv\Scripts\Activate.ps1
python summarization/scripts/download_datasets.py
python summarization/scripts/prepare_training_data.py
```

### Train (Colab GPU recommended)

```bash
pip install -r lighter_models/requirements-train.txt
python summarization/colab/train_flan_t5_small.py
```

### Test

```bash
python summarization/scripts/test_flan_t5_small.py
```

---

## 2) Chatbot — Qwen2.5-0.5B-Instruct

No local dataset download required (SamSum + SQuAD load online in the script).

### Train (Colab GPU recommended)

```bash
pip install -r lighter_models/requirements-train.txt
python chatbot/colab/train_qwen05_chatbot.py
```

If VRAM is tight, set in `chatbot/config_qwen05.yaml`:

```yaml
training:
  use_qlora: true
  per_device_train_batch_size: 4
```

### Test

```bash
python chatbot/scripts/test_qwen05_chatbot.py
```

---

## Notes

- Gemma LoRAs (`gemma3-meeting-lora`, `gemma3-chatbot-lora`) stay as they are.
- These lighter trainers write to **new** model folders only.
- Wiring the FastAPI backend to use the lighter models is a **separate** step (ask when you want that switched).
