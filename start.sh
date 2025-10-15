#!/usr/bin/env bash
set -euo pipefail

# optional: show GPU info quickly
nvidia-smi || true

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
MODELS_DIR="${MODELS_DIR:-$COMFY_DIR/models}"
REPO="${REPO:-Paul17665/comfy-models}"
FOLDERS="${FOLDERS:-checkpoints vae loras text_encoders}"
PORT="${PORT:-8188}"

mkdir -p "$MODELS_DIR"

# Pull models only if a token is present (provided as a Template Secret on RunPod)
if [ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]; then
  echo "Pulling model packs from https://huggingface.co/datasets/$REPO ..."
  for sub in $FOLDERS; do
    echo "[DL] $sub → $MODELS_DIR/$sub"
    huggingface-cli download "$REPO" \
      --repo-type dataset \
      --include "models/$sub/**" \
      --local-dir "$MODELS_DIR" \
      --local-dir-use-symlinks False \
      --token "$HUGGINGFACE_HUB_TOKEN" || true
  done
else
  echo "HUGGINGFACE_HUB_TOKEN not set — skipping model download."
fi

# Pick a free port (8188 else 8190)
if ss -ltn "sport = :$PORT" >/dev/null 2>&1; then PORT=8190; fi

echo "Starting ComfyUI on 0.0.0.0:$PORT"
python "$COMFY_DIR/main.py" --listen 0.0.0.0 --port "$PORT"
