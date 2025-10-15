# Base (good apt mirrors + CUDA/cuDNN)
FROM pytorch/pytorch:2.4.1-cuda12.4-cudnn9-devel

# --- OS deps (robust, non-interactive, retries, cleanup) ---
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get update -o Acquire::Retries=5 || apt-get update -o Acquire::Retries=5 --allow-releaseinfo-change; \
    apt-get install -y --no-install-recommends \
        git ffmpeg procps ca-certificates curl jq libsndfile1 libgl1 libglib2.0-0 \
    ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- Python deps (light; nodes may add extras via requirements.txt) ---
RUN python -m pip install -U pip && \
    python -m pip install --no-cache-dir huggingface_hub hf_transfer fastapi uvicorn \
                                 soundfile librosa ffmpeg-python

# --- ComfyUI core ---
ENV COMFY_DIR=/workspace/ComfyUI
ENV MODELS_DIR=${COMFY_DIR}/models
RUN mkdir -p ${MODELS_DIR} && \
    git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR}

# --- Custom nodes you asked for (Manager, Crystools, and the ones in your screenshot) ---
WORKDIR ${COMFY_DIR}/custom_nodes
RUN git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    git clone --depth=1 https://github.com/crystian/ComfyUI-Crystools.git && \
    git clone --depth=1 https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth=1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth=1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone --depth=1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone --depth=1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth=1 https://github.com/christian-byrne/audio-separation-nodes-comfyui.git && \
    git clone --depth=1 https://github.com/wildminder/ComfyUI-VibeVoice.git && \
    git clone --depth=1 https://github.com/Enemyx-net/VibeVoice-ComfyUI.git

# Install each node’s requirements if present (don’t fail build if one is optional)
RUN set -e; for d in */; do \
      if [ -f "$d/requirements.txt" ]; then \
        python -m pip install --no-cache-dir -r "$d/requirements.txt" || true; \
      fi; \
    done

# --- Defaults (you can override in RunPod Template envs) ---
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV REPO=Paul17665/comfy-models
ENV FOLDERS="checkpoints vae loras text_encoders"
ENV PORT=8188

# --- Startup ---
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh
WORKDIR /workspace
CMD ["/opt/start.sh"]
