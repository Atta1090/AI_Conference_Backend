#!/usr/bin/env bash
# One-time setup on the Google Cloud GPU VM.
# Does NOT touch your Windows laptop venv.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Creating cloud venv at .venv_cloud"
python3 -m venv .venv_cloud
# shellcheck disable=SC1091
source .venv_cloud/bin/activate

python -m pip install --upgrade pip

echo "==> Installing CUDA PyTorch (GPU)"
# Adjust cu121/cu124 if the Deep Learning image uses a newer CUDA.
pip install --index-url https://download.pytorch.org/whl/cu124 torch torchaudio

echo "==> Installing project requirements"
pip install -r requirements.txt
pip install "peft>=0.13.0" "accelerate>=0.33.0" watchfiles

echo "==> Checking CUDA"
python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
else:
    print("WARNING: CUDA not visible. Check NVIDIA drivers on the VM.")
PY

echo "==> Setup done. Start with:"
echo "    source .venv_cloud/bin/activate"
echo "    export DEVICE=cuda"
echo "    export HF_TOKEN=your_token"
echo "    python cloud_gpu/run_cloud.py"
