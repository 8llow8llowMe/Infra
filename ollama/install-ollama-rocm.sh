#!/usr/bin/env sh
# Start Ollama with the optional AMD ROCm Docker image.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo "Created .env from .env.example. Review WEBUI_SECRET_KEY and exposed ports."
fi

set -a
. ./.env
set +a

mkdir -p "$OLLAMA_DATA_DIR" "$OPEN_WEBUI_DATA_DIR"

docker compose --env-file .env \
  -f docker-compose-ollama.yml \
  -f docker-compose-ollama-rocm.yml \
  up -d

echo "Ollama ROCm stack started."
echo "Check GPU detection with: docker logs -f ${OLLAMA_CONTAINER_NAME}"
