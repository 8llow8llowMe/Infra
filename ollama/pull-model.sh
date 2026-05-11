#!/usr/bin/env sh
# Pull a model into the Ollama container.

set -eu

if [ -f ./.env ]; then
  set -a
  . ./.env
  set +a
fi

MODEL="${1:-qwen2.5-coder:7b}"
OLLAMA_CONTAINER_NAME="${OLLAMA_CONTAINER_NAME:-ollama}"

docker exec -it "$OLLAMA_CONTAINER_NAME" ollama pull "$MODEL"

echo "Pulled model: $MODEL"
