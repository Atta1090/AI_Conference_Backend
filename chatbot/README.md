# ConvoBridge Chatbot — Training Guide

Fine-tune Gemma 3 as a **meeting transcript Q&A chatbot** on Google Colab.

## What it learns

Given a meeting transcript + question, answer **only from the transcript**.  
If unknown → `Not mentioned in the transcript.`

## Notebook

Upload this file to Colab:

```
chatbot/colab/train_gemma3_chatbot.ipynb
```

## Colab steps

1. Runtime → Change runtime type → **GPU (T4)**
2. Accept Gemma license: https://huggingface.co/google/gemma-3-1b-it
3. Create HF token: https://huggingface.co/settings/tokens
4. Run all cells top → bottom

## Datasets (online only)

| Dataset | Use |
|---|---|
| `knkarthick/samsum` | Dialogue → synthetic meeting Q&A |
| `rajpurkar/squad` | Grounded context/question/answer |

Nothing is downloaded to your laptop.

## Training defaults

| Setting | Value |
|---|---|
| Model | `google/gemma-3-1b-it` |
| Epochs | 2 |
| Rows | 8000 |
| Batch | 24 (lower if OOM) |
| Seq length | 1536 |

## Output

Saved to Google Drive:

```
MyDrive/ConvoBridge/gemma3-chatbot-lora/
MyDrive/ConvoBridge/chatbot_checkpoints/
```

Copy adapter to backend:

```
chatbot/models/gemma3-chatbot-lora/
```

## Expected test answers (Step 8)

Transcript sample asks:

- Who will handle design? → Sara...
- When is next meeting? → Monday 10 AM
- Company IPO date? → Not mentioned in the transcript.

## If CUDA OOM

In Step 4 set:

```python
"per_device_batch_size": 16  # then 12, then 8
```

## Next after training

Wire backend endpoint `POST /chatbot/ask` to load this LoRA adapter.
