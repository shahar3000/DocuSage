#!/usr/bin/env bash
#
# DocuSage — clean uninstaller. Removes the containers, network, pulled images, and all
# stored data (models, accounts, manuals), leaving the machine as it was before install.
# Docker itself is left installed.
#
#   ./uninstall.sh           # asks for confirmation
#   ./uninstall.sh --yes     # no prompt (for scripts)
#
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }

ASSUME_YES="no"
case "${1:-}" in -y|--yes) ASSUME_YES="yes";; esac

# Find the data directory the install used (default ./data).
DATA_DIR="./data"
if [ -f .env ]; then
  ENV_DATA="$(grep -E '^DATA_DIR=' .env | head -n1 | cut -d= -f2-)"
  [ -n "${ENV_DATA:-}" ] && DATA_DIR="$ENV_DATA"
fi

# Decide whether docker needs sudo.
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then DOCKER="$SUDO docker"; fi
fi
COMPOSE="$DOCKER compose"
$COMPOSE version >/dev/null 2>&1 || COMPOSE="${SUDO} docker-compose"

bold "This will permanently remove DocuSage:"
info "- containers + network"
info "- pulled images (Ollama, Open WebUI, Docling)"
info "- ALL data in '${DATA_DIR}' (models, user accounts, uploaded manuals)"
echo
if [ "$ASSUME_YES" != "yes" ]; then
  printf "Type 'yes' to proceed: "
  read -r REPLY
  if [ "$REPLY" != "yes" ]; then echo "Aborted."; exit 0; fi
fi

bold "Stopping containers and removing images..."
# Reads COMPOSE_FILE from .env (so the GPU override, if any, is included).
$COMPOSE down --rmi all --remove-orphans || true

# Wipe the data directory. Container-written files are root-owned, so delete them from
# inside a throwaway root container — this avoids needing host 'sudo'. Nested root-owned
# subdirectories (e.g. Open WebUI's vector store) can't be removed by the host user otherwise.
if [ -d "$DATA_DIR" ]; then
  ABS_DATA="$(cd "$DATA_DIR" && pwd)"
  bold "Removing data in ${ABS_DATA}..."
  $DOCKER run --rm -v "${ABS_DATA}:/d" alpine sh -c 'rm -rf /d/* /d/.[!.]* /d/..?* 2>/dev/null || true'
  rmdir "$ABS_DATA" 2>/dev/null || info "(left '${ABS_DATA}' in place — not empty)"
fi

# Remove generated config (keep the template .env.example).
rm -f .env

echo
bold "DocuSage removed. Docker itself was left installed."
