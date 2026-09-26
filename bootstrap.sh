#!/usr/bin/env bash
set -Eeuo pipefail

# Verified upstream revisions, 2026-09-23. Update only after a smoke test.
readonly COMFY_REV='b5cc8830279eae909a59de030af1e50761c36751'
readonly STUDIO_REV='eb52643b62429ee1a3f94e94ef06f38fc13dfcbb'
readonly MODEL_REPO='Comfy-Org/MiniMax-H3'
readonly MODEL_REV='1c41cfca8ebba91d0af792a05c5761fb2c3a7975'
readonly MODEL_FILES=(
  'diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors:20958205608'
  'text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors:15687142551'
  'vae/minimax_h3_video_vae_fp16.safetensors:5207808496'
  'vae/minimax_h3_audio_vae_fp32.safetensors:605254808'
)

log() { printf '\n[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

DOCTOR=0
if [[ "${1:-}" == '--doctor' ]]; then DOCTOR=1; shift; fi
CONFIG_FILE="${1:-}"
[[ -f "$CONFIG_FILE" ]] || die 'Usage: bash bootstrap.sh [--doctor] /path/to/ckey-film.env'
# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${FILM_ROOT:?FILM_ROOT required}"
: "${COMFY_PORT:?COMFY_PORT required}"
SKIP_STUDIO="${SKIP_STUDIO:-0}"

if [[ "$DOCTOR" == 1 ]]; then
  log 'Ckey host readiness'
  if has nvidia-smi; then nvidia-smi --query-gpu=name,memory.total --format=csv,noheader; else echo 'NVIDIA driver missing'; fi
  df -h "$FILM_ROOT" 2>/dev/null || df -h /
  for tool in python3 git docker curl; do
    if has "$tool"; then echo "$tool: present"; else echo "$tool: missing"; fi
  done
  if has docker; then docker compose version || true; fi
  printf 'init: '; ps -p 1 -o comm= || true
  exit 0
fi

[[ $EUID -eq 0 ]] || die 'Run installation with sudo.'
has nvidia-smi || die 'NVIDIA driver missing.'
has apt-get || die 'This installer supports Debian/Ubuntu Ckey hosts.'
has systemctl || die 'This host has no systemd. Use a Ckey VM/host image with systemd.'

log 'Install system tools'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl git python3 python3-venv python3-pip ffmpeg
mkdir -p "$FILM_ROOT"

clone_pinned() {
  local repo="$1" dest="$2" rev="$3"
  if [[ ! -d "$dest/.git" ]]; then git clone --filter=blob:none --no-checkout "$repo" "$dest"; fi
  if [[ "$(git -C "$dest" rev-parse HEAD 2>/dev/null || true)" == "$rev" ]]; then return; fi
  if ! git -C "$dest" diff --quiet || ! git -C "$dest" diff --cached --quiet; then
    die "Local changes in $dest; preserve them before re-running."
  fi
  git -C "$dest" fetch --depth 1 origin "$rev"
  git -C "$dest" checkout --detach "$rev"
}

log 'Fetch pinned ComfyUI'
clone_pinned 'https://github.com/Comfy-Org/ComfyUI.git' "$FILM_ROOT/ComfyUI" "$COMFY_REV"

log 'Prepare CUDA Python environment'
if [[ ! -x "$FILM_ROOT/venv/bin/python" ]]; then python3 -m venv "$FILM_ROOT/venv"; fi
"$FILM_ROOT/venv/bin/python" -m pip install -U pip wheel
"$FILM_ROOT/venv/bin/python" -m pip install -r "$FILM_ROOT/ComfyUI/requirements.txt" 'huggingface_hub[hf_xet]'
if ! "$FILM_ROOT/venv/bin/python" -c 'import torch; assert torch.cuda.is_available()' 2>/dev/null; then
  log 'Install CUDA-enabled PyTorch from the official cu128 wheel index'
  "$FILM_ROOT/venv/bin/python" -m pip install --upgrade torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128
fi
"$FILM_ROOT/venv/bin/python" - <<'PY'
import torch
assert torch.cuda.is_available(), 'PyTorch cannot see CUDA; install a CUDA wheel matching this host driver.'
print('CUDA:', torch.version.cuda, 'GPU:', torch.cuda.get_device_name(0))
PY

log 'Download exactly four H3 Ref2VA files with Xet; downloads resume through the Hugging Face cache'
mkdir -p "$FILM_ROOT/ComfyUI/models"
if [[ -n "${HF_TOKEN:-}" ]]; then export HF_TOKEN; fi
model_paths=()
for entry in "${MODEL_FILES[@]}"; do
  model_paths+=("${entry%%:*}")
done
"$FILM_ROOT/venv/bin/hf" download "$MODEL_REPO" "${model_paths[@]}" \
  --revision "$MODEL_REV" --local-dir "$FILM_ROOT/ComfyUI/models"
for entry in "${MODEL_FILES[@]}"; do
  rel="${entry%%:*}"; expected="${entry##*:}"
  target="$FILM_ROOT/ComfyUI/models/$rel"
  [[ -f "$target" && "$(stat -c %s "$target")" == "$expected" ]] || die "Unexpected size for $rel"
done

if [[ "$SKIP_STUDIO" != 1 ]] && { ! has docker || ! docker compose version >/dev/null 2>&1; }; then
  log 'Install Docker Engine and Compose from the Ubuntu/Debian packages'
  apt-get install -y -qq docker.io docker-compose-v2
  systemctl enable --now docker.service
fi

COMFY_BIND='127.0.0.1'
if [[ "$SKIP_STUDIO" != 1 ]] && has docker; then
  gateway="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
  if [[ -n "$gateway" ]]; then COMFY_BIND="$gateway"; fi
fi

log 'Start ComfyUI service'
cat > /etc/systemd/system/ckey-film-comfyui.service <<EOF
[Unit]
Description=Ckey Film ComfyUI
After=network-online.target docker.service
Wants=network-online.target

[Service]
WorkingDirectory=$FILM_ROOT/ComfyUI
ExecStart=$FILM_ROOT/venv/bin/python main.py --listen $COMFY_BIND --port $COMFY_PORT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ckey-film-comfyui.service
systemctl restart ckey-film-comfyui.service
for _ in $(seq 1 60); do
  if curl --fail --silent "http://$COMFY_BIND:$COMFY_PORT/system_stats" >/dev/null; then break; fi
  sleep 2
done
curl --fail --silent "http://$COMFY_BIND:$COMFY_PORT/system_stats" >/dev/null || \
  die 'ComfyUI did not start. Inspect: journalctl -u ckey-film-comfyui.service -n 100'
curl --fail --silent "http://$COMFY_BIND:$COMFY_PORT/object_info/MiniMaxH3ReferenceToVideo" >/dev/null || \
  die 'This ComfyUI revision lacks the native H3 Ref2VA node.'

if [[ "$SKIP_STUDIO" != 1 ]]; then
  has docker || die 'Docker missing. ComfyUI/H3 is prepared; install Docker Compose, then rerun.'
  docker compose version >/dev/null || die 'Docker Compose plugin missing. ComfyUI/H3 is prepared; install Compose, then rerun.'
  [[ "$COMFY_BIND" != '127.0.0.1' ]] || die 'Docker host gateway unavailable; ComfyUI cannot be reached from the studio container.'
  log 'Fetch and start AI Movie Studio 2'
  clone_pinned 'https://github.com/Heroesjouney/AIMovieStudiov2.git' "$FILM_ROOT/AIMovieStudiov2" "$STUDIO_REV"
  "$FILM_ROOT/venv/bin/python" - "$FILM_ROOT/AIMovieStudiov2/backend/core/workflows/minimax_h3_r2v.json" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = 'minimax_h3_ref2va_pruned_int8_convrot.safetensors'
new = 'minimax_h3_ref2va_pruned_fp8_scaled.safetensors'
text = path.read_text(encoding='utf-8')
if old not in text and new not in text:
    raise SystemExit('H3 Ref2VA workflow model name changed upstream; inspect before continuing.')
path.write_text(text.replace(old, new), encoding='utf-8')
PY
  printf 'COMFY_URL=http://host.docker.internal:%s\n' "$COMFY_PORT" > "$FILM_ROOT/AIMovieStudiov2/backend/.env"
  (cd "$FILM_ROOT/AIMovieStudiov2" && docker compose up -d --build)
  (cd "$FILM_ROOT/AIMovieStudiov2" && docker compose ps)
fi

log 'Ready for an H3 Ref2VA smoke test'
echo "ComfyUI bind: $COMFY_BIND:$COMFY_PORT"
echo 'AI Movie Studio 2: SSH-tunnel remote port 3000 to local port 3000.'
