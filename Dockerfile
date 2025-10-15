# Base with CUDA/cuDNN + fresh apt mirrors
FROM pytorch/pytorch:2.4.1-cuda12.4-cudnn9-devel

# --- OS deps (non-interactive, retries, cleanup) ---
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get update -o Acquire::Retries=5 || apt-get update -o Acquire::Retries=5 --allow-releaseinfo-change; \
    apt-get install -y --no-install-recommends \
        git git-lfs ffmpeg procps ca-certificates curl jq \
        libsndfile1 libgl1 libglib2.0-0 libsm6 libxext6 \
    ; git lfs install; \
    apt-get clean; rm -rf /var/lib/apt/lists/*

# --- Python deps (light) ---
RUN python -m pip install -U pip && \
    python -m pip install --no-cache-dir \
      huggingface_hub hf_transfer fastapi uvicorn \
      soundfile librosa ffmpeg-python

# --- ComfyUI core paths ---
ENV COMFY_DIR=/workspace/ComfyUI
ENV MODELS_DIR=${COMFY_DIR}/models
RUN mkdir -p ${MODELS_DIR}

# --- Robust clone of ComfyUI (retries) ---
RUN bash -lc 'set -euo pipefail; \
  for i in {1..5}; do \
    git clone --depth=1 --recurse-submodules --single-branch https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR" && break || { \
      echo "git clone failed (ComfyUI) try $i"; rm -rf "$COMFY_DIR"; sleep 5; \
    }; \
  done'

# --- Custom nodes you asked for (with retries) ---
WORKDIR ${COMFY_DIR}/custom_nodes
RUN bash -lc 'set -euo pipefail; \
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
    name=$(basename "$url" .git); \
    for i in {1..5}; do \
      git clone --depth=1 --single-branch "$url" "$name" && break || { \
        echo "git clone failed ($name) try $i"; rm -rf "$name"; sleep 5; \
      }; \
    done; \
  done'

# --- Install node requirements (best-effort) ---
RUN bash -lc 'set -e; fo
