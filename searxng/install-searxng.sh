#!/usr/bin/env sh
# Prepare local directories and start SearXNG.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo "Created .env from .env.example. Review SEARXNG_BASE_URL before public exposure."
fi

set -a
. ./.env
set +a

mkdir -p ./cache

docker compose --env-file .env -f docker-compose-searxng.yml up -d

echo "SearXNG started."
echo "UI: http://<ai-host-ip>:${SEARXNG_PORT}"
echo "Open WebUI query URL: http://searxng:${SEARXNG_CONTAINER_PORT}/search?q=<query>&format=json"
