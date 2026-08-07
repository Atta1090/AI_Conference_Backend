# ConvoBridge AI Backend
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY download_opus_models.py ./

# Models are expected via volume mounts:
#   -v ./models:/app/models
#   -v ./summarization/models:/app/summarization/models
#   -v ./chatbot/models:/app/chatbot/models

ENV PYTHONUNBUFFERED=1
ENV DEVICE=cpu
ENV MODEL_CACHE_DIR=/app/models/cache

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
