#!/usr/bin/env sh
# Prepare local volumes and start Ollama with Open WebUI.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo "Created .env from .env.example. Review WEBUI_SECRET_KEY and exposed ports."
fi

set -a
. ./.env
set +a

mkdir -p "$OLLAMA_DATA_DIR" "$OPEN_WEBUI_DATA_DIR"

docker compose --env-file .env -f docker-compose-ollama.yml up -d

echo "Ollama stack started."
echo "Ollama API: http://<ai-host-ip>:${OLLAMA_PORT}"
echo "Open WebUI: http://<ai-host-ip>:${OPEN_WEBUI_PORT}"
