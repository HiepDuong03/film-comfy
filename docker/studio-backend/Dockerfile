FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    COMFY_URL=http://comfy:8188 \
    HOST=0.0.0.0 \
    PORT=8001

RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg curl build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/studio/backend
COPY vendor/AIMovieStudiov2/backend/requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt
COPY vendor/AIMovieStudiov2/backend ./
COPY docker/studio-backend/patch_comfy_public_url.py /tmp/patch_comfy_public_url.py
RUN python /tmp/patch_comfy_public_url.py core/drivers/comfy_video.py
RUN sed -i 's/minimax_h3_ref2va_pruned_int8_convrot\.safetensors/minimax_h3_ref2va_pruned_fp8_scaled.safetensors/g' core/workflows/minimax_h3_r2v.json

EXPOSE 8001
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1
CMD ["sh", "-c", "python main.py serve --host \"$HOST\" --port \"$PORT\""]
