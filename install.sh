#!/usr/bin/env bash
#
# DocuSage — one-command installer for a self-hosted RAG over PDF user manuals.
# Linux only. Asks a few questions, then brings the whole stack up and pulls the models.
#
#   ./install.sh
#
set -euo pipefail

# Always operate from the directory this script lives in.
cd "$(dirname "$(readlink -f "$0")")"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
err()  { printf '\033[31mError:\033[0m %s\n' "$1" >&2; }
warn() { printf '\033[33mWarning:\033[0m %s\n' "$1" >&2; }

bold "=============================================="
bold " DocuSage — RAG over your PDF user manuals"
bold "=============================================="
echo

if [ "$(uname -s)" != "Linux" ]; then
  err "This installer supports Linux only. (Detected: $(uname -s))"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Setup questions (press Enter to accept the default).
# ---------------------------------------------------------------------------

# GPU — default the answer based on whether an NVIDIA GPU is detected. Also read the
# total VRAM so we can recommend a sensible default answer model below.
GPU_VRAM_MB=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  GPU_DEFAULT="y"
  # Sum VRAM across all GPUs (Ollama can split a model across them); nvidia-smi prints
  # one value per line, so awk totals them and prints 0 if there's no output.
  GPU_VRAM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | awk '{s+=$1} END{print s+0}')"
  [ -z "$GPU_VRAM_MB" ] && GPU_VRAM_MB=0
  info "An NVIDIA GPU was detected (${GPU_VRAM_MB} MiB VRAM total)."
else
  GPU_DEFAULT="n"
  info "No NVIDIA GPU detected (will run on CPU)."
fi
read -r -p "Use GPU acceleration? [${GPU_DEFAULT}] " USE_GPU
USE_GPU="${USE_GPU:-$GPU_DEFAULT}"
case "$USE_GPU" in [Yy]*) USE_GPU="y";; *) USE_GPU="n";; esac

# Answer model — both are Hebrew-specialized models from Dicta. Recommend DictaLM 3.0
# (24B) only when a big GPU is present; otherwise default to the light DictaLM 2.0 (7B).
if [ "$USE_GPU" = "y" ] && [ "${GPU_VRAM_MB:-0}" -ge 22000 ]; then
  MODEL_DEFAULT="2"
else
  MODEL_DEFAULT="1"
fi
echo
bold "Which Hebrew answer model? (both are Hebrew-specialized, by Dicta)"
info "  1) DictaLM 2.0  — 7B.  Min: ~8 GB RAM (CPU) or ~6 GB VRAM. Fast; runs on almost anything."
info "  2) DictaLM 3.0  — 24B. Min: a GPU with ~24 GB VRAM (e.g. RTX 3090/4090, A6000). Best quality."
read -r -p "Model [${MODEL_DEFAULT}] " MODEL_CHOICE
MODEL_CHOICE="${MODEL_CHOICE:-$MODEL_DEFAULT}"
case "$MODEL_CHOICE" in
  2) GENERATION_MODEL="dicta-il/DictaLM-3.0-24B-Thinking:q4_K_M"; MODEL_LABEL="DictaLM 3.0 (24B)";;
  *) GENERATION_MODEL="aminadaven/dictalm2.0-instruct:q4_K_M";    MODEL_LABEL="DictaLM 2.0 (7B)"; MODEL_CHOICE="1";;
esac

# Warn if DictaLM 3.0 was chosen on hardware that probably can't run it well.
if [ "$MODEL_CHOICE" = "2" ]; then
  WARN=""
  if [ "$USE_GPU" != "y" ]; then
    WARN="DictaLM 3.0 (24B) without GPU acceleration will be extremely slow."
  elif [ "${GPU_VRAM_MB:-0}" -gt 0 ] && [ "${GPU_VRAM_MB:-0}" -lt 22000 ]; then
    WARN="Detected only ${GPU_VRAM_MB} MiB VRAM total; DictaLM 3.0 (24B) typically needs ~24 GB and may not fit."
  fi
  if [ -n "$WARN" ]; then
    warn "${WARN}"
    read -r -p "Continue with DictaLM 3.0 anyway? [y/N] " CONFIRM
    case "$CONFIRM" in
      [Yy]*) ;;
      *) GENERATION_MODEL="aminadaven/dictalm2.0-instruct:q4_K_M"; MODEL_LABEL="DictaLM 2.0 (7B)"; MODEL_CHOICE="1"
         info "Using DictaLM 2.0 instead.";;
    esac
  fi
fi

# Web UI port.
read -r -p "Port for the web interface? [3000] " WEBUI_PORT
WEBUI_PORT="${WEBUI_PORT:-3000}"

# Data location.
read -r -p "Where should data (models + manuals) be stored? [./data] " DATA_DIR
DATA_DIR="${DATA_DIR:-./data}"

echo
info "GPU acceleration : ${USE_GPU}"
info "Answer model     : ${MODEL_LABEL}  (${GENERATION_MODEL})"
info "Web UI port      : ${WEBUI_PORT}"
info "Data directory   : ${DATA_DIR}"
echo

# ---------------------------------------------------------------------------
# 2. Ensure Docker + Compose are available (auto-install on Linux if missing).
# ---------------------------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

if ! command -v docker >/dev/null 2>&1; then
  bold "Docker is not installed. Installing it now (requires sudo)..."
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker || true
fi

# Decide whether docker needs sudo (user not in the docker group).
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if $SUDO docker info >/dev/null 2>&1; then
    DOCKER="$SUDO docker"
  else
    err "Docker is installed but not running. Start it with: $SUDO systemctl start docker"
    exit 1
  fi
fi

# Compose: prefer the v2 plugin ('docker compose'), fall back to 'docker-compose'.
if $DOCKER compose version >/dev/null 2>&1; then
  COMPOSE="$DOCKER compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="${SUDO} docker-compose"
else
  err "Docker Compose not found. Install the Docker Compose plugin and re-run."
  exit 1
fi

# If the user asked for GPU, sanity-check the NVIDIA container runtime.
if [ "$USE_GPU" = "y" ]; then
  if ! $DOCKER info 2>/dev/null | grep -qi nvidia; then
    err "GPU was requested but the NVIDIA Container Toolkit doesn't appear to be set up."
    info "Install it (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)"
    info "or re-run and answer 'n' to use CPU."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 3. Write .env from the template + answers.
# ---------------------------------------------------------------------------
cp .env.example .env
# Substitute the answered values; everything else keeps its template default.
sed -i "s|^WEBUI_PORT=.*|WEBUI_PORT=${WEBUI_PORT}|" .env
sed -i "s|^DATA_DIR=.*|DATA_DIR=${DATA_DIR}|" .env
sed -i "s|^GENERATION_MODEL=.*|GENERATION_MODEL=${GENERATION_MODEL}|" .env

# Persist the GPU choice as the default compose file set, so plain `docker compose`
# commands (and re-runs of this script) keep using the GPU override.
if [ "$USE_GPU" = "y" ]; then
  echo "COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml" >> .env
else
  echo "COMPOSE_FILE=docker-compose.yml" >> .env
fi

# Create the data subdirectories up front so bind mounts aren't created as root-only.
mkdir -p "${DATA_DIR}/ollama" "${DATA_DIR}/open-webui" "${DATA_DIR}/docling"

# ---------------------------------------------------------------------------
# 4. Bring the stack up and wait for models to finish downloading.
# ---------------------------------------------------------------------------
bold "Starting the stack..."
$COMPOSE up -d

echo
bold "Downloading models (this can take several minutes on first run)..."
# model-init exits 0 once both models are pulled. docker wait blocks until then.
if EXIT_CODE="$($DOCKER wait docusage-model-init 2>/dev/null)"; then
  if [ "$EXIT_CODE" != "0" ]; then
    err "Model download failed. See logs:  $COMPOSE logs model-init"
    exit 1
  fi
else
  # Container may have already finished on a re-run; surface logs if anything's off.
  info "(model-init already finished; continuing)"
fi

# ---------------------------------------------------------------------------
# 5. Done — print where to go.
# ---------------------------------------------------------------------------
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
HOST_IP="${HOST_IP:-localhost}"

echo
bold "=============================================="
bold " DocuSage is ready."
bold "=============================================="
info "Open it in a browser:"
info "  On this machine : http://localhost:${WEBUI_PORT}"
info "  From the team   : http://${HOST_IP}:${WEBUI_PORT}"
echo
info "Next steps:"
info "  1. Open the URL and create the FIRST account — it becomes the admin."
info "  2. (Optional) Admin Panel -> Settings -> General: turn off new sign-ups,"
info "     then add team members under Admin Panel -> Users -> + Add User."
info "  3. Workspace -> Knowledge: create one collection per product and upload its PDFs."
info "  4. In a new chat, attach the relevant collection (#) and ask away — answers cite sources."
echo
