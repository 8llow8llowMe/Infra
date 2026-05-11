#!/usr/bin/env sh
# Ollama 컨테이너에 모델을 다운로드합니다.

set -eu

if [ -f ./.env ]; then
  set -a
  . ./.env
  set +a
fi

MODEL="${1:-qwen2.5-coder:7b}"
OLLAMA_CONTAINER_NAME="${OLLAMA_CONTAINER_NAME:-ollama}"

docker exec -it "$OLLAMA_CONTAINER_NAME" ollama pull "$MODEL"

echo "모델 다운로드 완료: $MODEL"
