# Software-only image. Model weights are deliberately downloaded to a runtime volume.
# Official Linux/CUDA 12.8 runtime with a tested PyTorch wheel already installed.
# This avoids resolving a several-GB wheel dependency tree during every CI build.
FROM pytorch/pytorch:2.7.1-cuda12.8-cudnn9-runtime@sha256:c16f4c749e2d9e96878875cdf6cc45cddda1d1a36fddd371dd6f2360f1b6e2a2

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/data/huggingface

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY vendor/ComfyUI /opt/ComfyUI

RUN python -m pip install --no-cache-dir --upgrade pip wheel \
    && python -m pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt \
    && python -m pip install --no-cache-dir 'huggingface_hub[hf_xet]'

COPY docker/comfy/entrypoint.sh /usr/local/bin/film-comfy-entrypoint
RUN chmod 0755 /usr/local/bin/film-comfy-entrypoint \
    && mkdir -p /data/huggingface /opt/ComfyUI/models

WORKDIR /opt/ComfyUI
EXPOSE 8188
ENTRYPOINT ["film-comfy-entrypoint"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
