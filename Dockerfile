FROM pytorch/pytorch:2.4.0-cuda12.1-cudnn9-devel

# OS tools
RUN apt-get update && apt-get install -y git ffmpeg procps && rm -rf /var/lib/apt/lists/*

# Python deps (small, no heavy compiles)
RUN python -m pip install -U pip && \
    python -m pip install --no-cache-dir huggingface_hub hf_transfer fastapi uvicorn

# ComfyUI
ENV COMFY_DIR=/workspace/ComfyUI
ENV MODELS_DIR=${COMFY_DIR}/models
RUN mkdir -p ${MODELS_DIR} && \
    git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR}

# Defaults (you can override via envs in RunPod)
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV REPO=Paul17665/comfy-models
ENV FOLDERS="checkpoints vae loras text_encoders"
ENV PORT=8188

# Startup script
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

WORKDIR /workspace
CMD ["/opt/start.sh"]
