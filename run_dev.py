"""Dev server entrypoint that will not abort model downloads on reload.

Uvicorn's default StatReload watches every ``*.py`` under the project root.
HuggingFace writes ``*.py`` into ``models/cache/`` during downloads, which
triggers a reload and kills the in-flight download (KeyboardInterrupt).

``--reload-exclude`` only works when the optional ``watchfiles`` package is
installed, so we instead limit reload watching to ``app/``.
"""

from __future__ import annotations

from pathlib import Path

import uvicorn

ROOT = Path(__file__).resolve().parent


if __name__ == "__main__":
    # 0.0.0.0 = reachable from phones on the same Wi‑Fi.
    # 127.0.0.1 would only accept connections from this PC, so physical
    # phones never get STT / translate / captions.
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        # Only watch application source — never models/, uploads/, venv/, etc.
        reload_dirs=[str(ROOT / "app")],
        reload_excludes=[
            "models",
            "models/*",
            "uploads",
            "uploads/*",
            "venv",
            "venv/*",
            ".git",
            ".git/*",
        ],
    )
