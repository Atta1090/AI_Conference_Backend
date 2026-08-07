from faster_whisper import WhisperModel

print("Loading local Whisper model...")

model = WhisperModel(
    "models/faster-whisper-base",
    device="cpu",
    compute_type="int8"
)

print("Model loaded successfully!")

segments, info = model.transcribe(
    "sample_audio/11.ogg",
    beam_size=5
)

print(f"\nDetected Language: {info.language}")
print(f"Language Probability: {info.language_probability:.2f}")

print("\nTranscript:\n")

for segment in segments:
    print(
        f"[{segment.start:.2f}s -> {segment.end:.2f}s] {segment.text}"
    )