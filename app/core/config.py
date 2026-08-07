"""Central configuration for the ConvoBridge AI backend.

Values are read from environment variables (see ``.env``) with sensible
defaults so the service runs out-of-the-box for local development.
"""

from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


class Settings:
    """Application settings.

    All heavy AI models are loaded lazily on first use, so importing this
    module (and starting the API) stays fast and cheap.
    """

    def __init__(self) -> None:
        self.project_name: str = "ConvoBridge AI Backend"
        self.version: str = "1.0.0"

        # Root of the repository (…/AI-Conference-Backend).
        self.base_dir: Path = Path(__file__).resolve().parents[2]

        # Compute backend for the AI models: "cpu" or "cuda".
        self.device: str = os.getenv("DEVICE", "cpu")

        # ---- Audio ----
        # Whisper and the noise-reduction pipeline operate on 16 kHz mono PCM.
        self.sample_rate: int = int(os.getenv("SAMPLE_RATE", "16000"))
        self.upload_dir: Path = Path(os.getenv("UPLOAD_DIR", self.base_dir / "uploads"))

        # ---- Speech-to-Text (faster-whisper) ----
        self.stt_model_path: str = os.getenv(
            "STT_MODEL_PATH", str(self.base_dir / "models" / "faster-whisper-base")
        )
        # int8 keeps memory/latency low on CPU; use "float16" on GPU.
        self.stt_compute_type: str = os.getenv(
            "STT_COMPUTE_TYPE", "int8" if self.device == "cpu" else "float16"
        )
        self.stt_beam_size: int = int(os.getenv("STT_BEAM_SIZE", "1"))
        # Skip non-speech regions; speeds up quiet / pause-heavy audio.
        self.stt_vad_filter: bool = _env_bool("STT_VAD_FILTER", True)
        # Must stay false — otherwise Whisper stitches prior phrases into the
        # next utterance ("hello…" replayed before "meeting tomorrow").
        self.stt_condition_on_previous_text: bool = _env_bool(
            "STT_CONDITION_ON_PREVIOUS_TEXT", False
        )
        # Higher = treat more ambiguous audio as silence (fewer hallucinations).
        self.stt_no_speech_threshold: float = float(
            os.getenv("STT_NO_SPEECH_THRESHOLD", "0.6")
        )
        self.stt_compression_ratio_threshold: float = float(
            os.getenv("STT_COMPRESSION_RATIO_THRESHOLD", "2.4")
        )

        # ---- Noise reduction ----
        # Strength of spectral-gating noise suppression (0.0 - 1.0).
        self.noise_reduction_strength: float = float(
            os.getenv("NOISE_REDUCTION_STRENGTH", "0.85")
        )
        self.noise_stationary: bool = _env_bool("NOISE_STATIONARY", False)

        # ---- Translation (Opus-MT pair models, 4 languages: en/ur/ar/hi) ----
        # Individual pair IDs live in app.core.languages.OPUS_PAIRS.
        # TRANSLATION_MODEL is kept only as a legacy env override hint.
        self.translation_model: str = os.getenv(
            "TRANSLATION_MODEL", "Helsinki-NLP/opus-mt-en-ur"
        )
        self.translation_max_length: int = int(
            os.getenv("TRANSLATION_MAX_LENGTH", "512")
        )
        # More beams = better phrasing on short lines like "where are you".
        self.translation_num_beams: int = int(os.getenv("TRANSLATION_NUM_BEAMS", "4"))
        # Dynamic INT8 saves RAM but measurably corrupts Opus output on CPU;
        # off by default so meeting captions/voice stay accurate.
        self.opus_cpu_dynamic_int8: bool = _env_bool("OPUS_CPU_DYNAMIC_INT8", False)

        # ---- Text-to-Speech (Coqui XTTS v2) ----
        # Kept on disk but disabled by default — Flutter speaks via flutter_tts.
        # Set ENABLE_BACKEND_TTS=true to re-enable server-side XTTS synthesis.
        self.enable_backend_tts: bool = _env_bool("ENABLE_BACKEND_TTS", False)
        self.tts_model: str = os.getenv(
            "TTS_MODEL", "tts_models/multilingual/multi-dataset/xtts_v2"
        )
        # Reference speaker sample used to condition XTTS voice cloning.
        self.tts_speaker_wav: str = os.getenv("TTS_SPEAKER_WAV", "")

        # Where model weights are cached (HuggingFace / Coqui).
        self.model_cache_dir: Path = Path(
            os.getenv("MODEL_CACHE_DIR", self.base_dir / "models" / "cache")
        )

        # ---- Summarization (Gemma 3) ----
        self.summarization_model: str = os.getenv(
            "SUMMARIZATION_MODEL", "google/gemma-3-1b-it"
        )
        self.summarization_adapter_path: str = os.getenv(
            "SUMMARIZATION_ADAPTER_PATH",
            str(self.base_dir / "summarization" / "models" / "gemma3-meeting-lora"),
        )
        self.summarization_max_input_tokens: int = int(
            os.getenv("SUMMARIZATION_MAX_INPUT_TOKENS", "4096")
        )
        # 1024 tokens of summary is far more than a meeting needs and costs
        # minutes of CPU time on a laptop; 384 covers the structured layout.
        self.summarization_max_new_tokens: int = int(
            os.getenv("SUMMARIZATION_MAX_NEW_TOKENS", "384")
        )
        self.summarization_min_new_tokens: int = int(
            os.getenv("SUMMARIZATION_MIN_NEW_TOKENS", "32")
        )
        self.summarization_temperature: float = float(
            os.getenv("SUMMARIZATION_TEMPERATURE", "0.3")
        )
        self.summarization_top_p: float = float(os.getenv("SUMMARIZATION_TOP_P", "0.9"))

        # ---- Chatbot Q&A (Gemma 3 + LoRA) ----
        self.chatbot_model: str = os.getenv(
            "CHATBOT_MODEL", "google/gemma-3-1b-it"
        )
        self.chatbot_adapter_path: str = os.getenv(
            "CHATBOT_ADAPTER_PATH",
            str(self.base_dir / "chatbot" / "models" / "gemma3-chatbot-lora"),
        )
        self.chatbot_max_input_tokens: int = int(
            os.getenv("CHATBOT_MAX_INPUT_TOKENS", "4096")
        )
        self.chatbot_max_new_tokens: int = int(
            os.getenv("CHATBOT_MAX_NEW_TOKENS", "256")
        )
        self.chatbot_temperature: float = float(
            os.getenv("CHATBOT_TEMPERATURE", "0.2")
        )
        self.chatbot_top_p: float = float(os.getenv("CHATBOT_TOP_P", "0.9"))

        # ---- Gemma quantization ----
        # CUDA: real NF4 4-bit via bitsandbytes.
        # CPU: bitsandbytes 4-bit is unavailable → dynamic INT8 fallback.
        self.gemma_load_in_4bit: bool = _env_bool("GEMMA_LOAD_IN_4BIT", True)
        # Dynamic INT8 halves Gemma's RAM but wrecks a 1B model: measured
        # output degraded to corrupted tokens and a single sentence repeated
        # in place of the summary. Off by default; set to 1 only if fp32 will
        # not fit and a poor summary is better than none.
        self.gemma_cpu_dynamic_int8: bool = _env_bool("GEMMA_CPU_DYNAMIC_INT8", False)
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        self.model_cache_dir.mkdir(parents=True, exist_ok=True)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
