# Software-only image. Model weights are deliberately downloaded to a runtime volume.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ARG COMFY_REV=b5cc8830279eae909a59de030af1e50761c36751
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/data/huggingface

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl ffmpeg git python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/Comfy-Org/ComfyUI.git /opt/ComfyUI \
    && git -C /opt/ComfyUI checkout --detach "${COMFY_REV}"

RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install --index-url https://download.pytorch.org/whl/cu128 \
         torch torchvision torchaudio \
    && python3 -m pip install -r /opt/ComfyUI/requirements.txt 'huggingface_hub[hf_xet]'

COPY docker/comfy/entrypoint.sh /usr/local/bin/film-comfy-entrypoint
RUN chmod 0755 /usr/local/bin/film-comfy-entrypoint \
    && mkdir -p /data/huggingface /opt/ComfyUI/models

WORKDIR /opt/ComfyUI
EXPOSE 8188
ENTRYPOINT ["film-comfy-entrypoint"]
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
