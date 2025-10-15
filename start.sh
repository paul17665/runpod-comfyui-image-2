#!/usr/bin/env bash
set -euo pipefail
export PYTHONUNBUFFERED=1

# Show GPU if present (non-fatal)
nvidia-smi || true

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
MODELS_DIR="${MODELS_DIR:-$COMFY_DIR/models}"
REPO="${REPO:-Paul17665/comfy-models}"
FOLDERS="${FOLDERS:-checkpoints vae loras text_encoders}"
PORT="${PORT:-8188}"

mkdir -p "$MODELS_DIR"

# Pull selected model packs from your private HF dataset if the token is present
if [ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]; then
python - <<'PY'
import os
from huggingface_hub import snapshot_download
repo   = os.environ.get("REPO")
token  = os.environ.get("HUGGINGFACE_HUB_TOKEN")
folds  = os.environ.get("FOLDERS","").split()
local  = os.environ.get("MODELS_DIR")
for sub in folds:
    print(f"[DL] models/{sub}/** -> {local}", flush=True)
    snapshot_download(
        repo_id=repo, repo_type="dataset",
        allow_patterns=[f"models/{sub}/**"],
        local_dir=local, local_dir_use_symlinks=False,
        token=token
    )
print("HF pulls complete.", flush=True)
PY
else
  echo "HUGGINGFACE_HUB_TOKEN not set — skipping model download."
fi

# Pick a free port (8188 -> 8190 fallback if busy)
if command -v ss >/dev/null 2>&1 && ss -ltn "sport = :$PORT" >/dev/null 2>&1; then
  PORT=8190
fi

echo "Starting ComfyUI on 0.0.0.0:$PORT"
python "$COMFY_DIR/main.py" --listen 0.0.0.0 --port "$PORT"
