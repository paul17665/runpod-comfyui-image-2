FROM pytorch/pytorch:2.4.1-cuda12.4-cudnn9-devel

# Use bash for all RUNs (avoids quoting issues)
SHELL ["/bin/bash", "-lc"]

# --- OS deps (non-interactive, retries, cleanup) ---
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get update -o Acquire::Retries=5 || apt-get update -o Acquire::Retries=5 --allow-releaseinfo-change; \
    apt-get install -y --no-install-recommends \
      git git-lfs ffmpeg procps ca-certificates curl jq \
      libsndfile1 libgl1 libglib2.0-0 libsm6 libxext6 \
    ; \
    git lfs install; \
    apt-get clean; rm -rf /var/lib/apt/lists/*

# --- Python deps ---
RUN python -m pip install -U pip && \
    python -m pip install --no-cache-dir \
      huggingface_hub hf_transfer fastapi uvicorn \
      soundfile librosa ffmpeg-python

# --- Paths ---
ENV COMFY_DIR=/workspace/ComfyUI
ENV MODELS_DIR=${COMFY_DIR}/models
RUN mkdir -p "${MODELS_DIR}"

# --- Tiny helper: robust git clone with retries ---
RUN cat >/usr/local/bin/clone_retry.sh <<'EOS' && chmod +x /usr/local/bin/clone_retry.sh
#!/usr/bin/env bash
set -euo pipefail
url="$1"; dest="$2"; tries="${3:-5}"
for ((i=1;i<=tries;i++)); do
  if git clone --depth=1 --recurse-submodules --single-branch "$url" "$dest"; then
    exit 0
  fi
  echo "git clone failed ($url) try $i/$tries" >&2
  rm -rf "$dest" || true
  sleep 5
done
echo "git clone ultimately failed: $url" >&2
exit 1
EOS

# --- ComfyUI core (with retries) ---
RUN clone_retry.sh https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"

# --- Custom nodes (your list) ---
WORKDIR "${COMFY_DIR}/custom_nodes"
RUN set -euo pipefail; \
  repos=( \
    https://github.com/Comfy-Org/ComfyUI-Manager.git \
    https://github.com/crystian/ComfyUI-Crystools.git \
    https://github.com/city96/ComfyUI-GGUF.git \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    https://github.com/kijai/ComfyUI-WanVideoWrapper.git \
    https://github.com/rgthree/rgthree-comfy.git \
    https://github.com/christian-byrne/audio-separation-nodes-comfyui.git \
    https://github.com/wildminder/ComfyUI-VibeVoice.git \
    https://github.com/Enemyx-net/VibeVoice-ComfyUI.git \
  ); \
  for url in "${repos[@]}"; do \
    name="$(basename "$url" .git)"; \
    clone_retry.sh "$url" "$name" 5; \
  done

# --- Install node requirements (best-effort) ---
RUN set -euo pipefail; shopt -s nullglob; \
  for d in ${COMFY_DIR}/custom_nodes/*; do \
    if [[ -f "$d/requirements.txt" ]]; then \
      python -m pip install --no-cache-dir -r "$d/requirements.txt" || true; \
    fi; \
  done

# --- Defaults (override in RunPod Template if desired) ---
ENV HF_HUB_ENABLE_HF_TRANSFER=1 \
    REPO=Paul17665/comfy-models \
    FOLDERS="checkpoints vae loras text_encoders" \
    PORT=8188

# --- Startup ---
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh
WORKDIR /workspace
EXPOSE 8188
CMD ["/opt/start.sh"]
