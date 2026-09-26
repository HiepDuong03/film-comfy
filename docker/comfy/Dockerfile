# Software-only image. Model weights are deliberately downloaded to a runtime volume.
# Official Linux/CUDA 12.8 runtime with a tested PyTorch wheel already installed.
# This avoids resolving a several-GB wheel dependency tree during every CI build.
FROM pytorch/pytorch:2.7.1-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/data/huggingface

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY vendor/ComfyUI /opt/ComfyUI

RUN python -m pip install --upgrade pip wheel
RUN python -m pip install -r /opt/ComfyUI/requirements.txt
RUN python -m pip install 'huggingface_hub[hf_xet]'

COPY docker/comfy/entrypoint.sh /usr/local/bin/film-comfy-entrypoint
RUN chmod 0755 /usr/local/bin/film-comfy-entrypoint \
    && mkdir -p /data/huggingface /opt/ComfyUI/models

WORKDIR /opt/ComfyUI
EXPOSE 8188
ENTRYPOINT ["film-comfy-entrypoint"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
