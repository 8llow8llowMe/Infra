#!/usr/bin/env sh
# Ollama와 Open WebUI 실행에 필요한 디렉터리를 준비하고 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. WEBUI_SECRET_KEY와 포트를 확인하세요."
fi

set -a
. ./.env
set +a

mkdir -p "$OLLAMA_DATA_DIR" "$OPEN_WEBUI_DATA_DIR"

docker compose --env-file .env -f docker-compose-ollama.yml up -d

echo "Ollama 스택이 시작되었습니다."
echo "Ollama API: http://<ai-host-ip>:${OLLAMA_PORT}"
echo "Open WebUI: http://<ai-host-ip>:${OPEN_WEBUI_PORT}"
