"""Manual check: summary + chatbot in every supported language.

Runs the real services (Opus-MT, and Gemma when it fits in RAM) against a
mixed English/Urdu meeting, which is exactly the case the client reported.

    python scripts/check_multilingual_ai.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.chatbot import ask
from app.services.summarization import summarize_transcript

UTTERANCES = [
    {
        "speaker": "Ahmed",
        "text": "Welcome everyone. We must ship the login screen this week.",
        "lang": "en",
    },
    {
        "speaker": "Sara",
        "text": "میں کل لاگ ان اسکرین مکمل کروں گی۔",
        "lang": "ur",
    },
    {
        "speaker": "Ahmed",
        "text": "Bilal, can you finish the payment module by Friday?",
        "lang": "en",
    },
    {
        "speaker": "Bilal",
        "text": "جی، ادائیگی کا ماڈیول جمعہ تک تیار ہو جائے گا۔",
        "lang": "ur",
    },
]

TRANSCRIPT = "\n".join(f"{u['speaker']}: {u['text']}" for u in UTTERANCES)

QUESTIONS = {
    "en": "Who will finish the payment module?",
    "ur": "ادائیگی کا ماڈیول کون مکمل کرے گا؟",
    "ar": "من سينهي وحدة الدفع؟",
    "hi": "भुगतान मॉड्यूल कौन पूरा करेगा?",
}


def main() -> None:
    for language in ("en", "ur", "ar", "hi"):
        print(f"\n{'=' * 60}\nLANGUAGE: {language}\n{'=' * 60}")

        result = summarize_transcript(
            TRANSCRIPT, language=language, utterances=UTTERANCES
        )
        print(f"[summary lang] {result.get('language')}")
        print(f"[summary]      {result.get('summary')}")
        for point in result.get("key_points", []):
            print(f"  - point:  {point}")
        for item in result.get("action_items", []):
            print(f"  - action: {item}")

        answer = ask(
            QUESTIONS[language],
            transcript=TRANSCRIPT,
            language=language,
            utterances=UTTERANCES,
        )
        print(f"[question]     {QUESTIONS[language]}")
        print(f"[answer lang]  {answer.get('language')}")
        print(f"[answer]       {answer.get('answer')}")


if __name__ == "__main__":
    main()
