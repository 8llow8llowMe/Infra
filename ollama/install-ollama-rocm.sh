#!/usr/bin/env sh
# AMD ROCm 이미지로 Ollama와 Open WebUI를 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. WEBUI_SECRET_KEY와 포트를 확인하세요."
fi

set -a
. ./.env
set +a

mkdir -p "$OLLAMA_DATA_DIR" "$OPEN_WEBUI_DATA_DIR"

docker compose --env-file .env \
  -f docker-compose-ollama.yml \
  -f docker-compose-ollama-rocm.yml \
  up -d

echo "Ollama ROCm 스택이 시작되었습니다."
echo "GPU 인식 여부 확인: docker logs -f ${OLLAMA_CONTAINER_NAME}"
