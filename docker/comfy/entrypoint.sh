#!/usr/bin/env bash
set -Eeuo pipefail

readonly MODEL_REPO='Comfy-Org/MiniMax-H3'
readonly MODEL_REV='1c41cfca8ebba91d0af792a05c5761fb2c3a7975'
readonly MODEL_DIR='/opt/ComfyUI/models'
readonly MODEL_FILES=(
  'diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors:20958205608'
  'text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors:15687142551'
  'vae/minimax_h3_video_vae_fp16.safetensors:5207808496'
  'vae/minimax_h3_audio_vae_fp32.safetensors:605254808'
)

log() { printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }

if [[ "${DOWNLOAD_MODELS:-1}" == '1' ]]; then
  # Suitable for the 64 GB RAM / NVMe Ckey host selected for this kit.
  export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"
  paths=()
  missing=0
  for entry in "${MODEL_FILES[@]}"; do
    rel="${entry%%:*}"; expected="${entry##*:}"
    paths+=("$rel")
    [[ -f "$MODEL_DIR/$rel" && "$(stat -c %s "$MODEL_DIR/$rel")" == "$expected" ]] || missing=1
  done
  if [[ "$missing" == 1 ]]; then
    log 'Downloading missing H3 Ref2VA model files with Hugging Face Xet (resumable).'
    hf download "$MODEL_REPO" "${paths[@]}" --revision "$MODEL_REV" --local-dir "$MODEL_DIR"
  else
    log 'H3 model files already present in the mounted model volume.'
  fi
fi

for entry in "${MODEL_FILES[@]}"; do
  rel="${entry%%:*}"; expected="${entry##*:}"
  [[ -f "$MODEL_DIR/$rel" && "$(stat -c %s "$MODEL_DIR/$rel")" == "$expected" ]] || {
    echo "Missing or incomplete model: $rel" >&2
    exit 1
  }
done

exec "$@"
