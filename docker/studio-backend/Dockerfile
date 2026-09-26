FROM python:3.11-slim

ARG STUDIO_REV=eb52643b62429ee1a3f94e94ef06f38fc13dfcbb
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    COMFY_URL=http://comfy:8188 \
    HOST=0.0.0.0 \
    PORT=8001

RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg curl git build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/Heroesjouney/AIMovieStudiov2.git /src/studio \
    && git -C /src/studio checkout --detach "${STUDIO_REV}"

WORKDIR /src/studio/backend
RUN pip install --upgrade pip && pip install -r requirements.txt \
    && sed -i 's/minimax_h3_ref2va_pruned_int8_convrot\.safetensors/minimax_h3_ref2va_pruned_fp8_scaled.safetensors/g' core/workflows/minimax_h3_r2v.json

EXPOSE 8001
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1
CMD ["sh", "-c", "python main.py serve --host \"$HOST\" --port \"$PORT\""]
