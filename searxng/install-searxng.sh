#!/usr/bin/env sh
# SearXNG 실행에 필요한 디렉터리를 준비하고 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. 외부 공개 전 SEARXNG_BASE_URL을 확인하세요."
fi

set -a
. ./.env
set +a

mkdir -p ./cache

docker compose --env-file .env -f docker-compose-searxng.yml up -d

echo "SearXNG가 시작되었습니다."
echo "UI: http://<ai-host-ip>:${SEARXNG_PORT}"
echo "Open WebUI query URL: http://searxng:${SEARXNG_CONTAINER_PORT}/search?q=<query>&format=json"
