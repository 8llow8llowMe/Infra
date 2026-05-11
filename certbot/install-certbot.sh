#!/usr/bin/env sh
# Certbot 갱신 컨테이너 실행에 필요한 디렉터리를 준비하고 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. CERTBOT_EMAIL 값을 확인하세요."
fi

mkdir -p ./letsencrypt ./logs ./webroot

docker compose --env-file .env -f docker-compose-certbot.yml up -d --force-recreate --remove-orphans

echo "Certbot 갱신 컨테이너가 시작되었습니다."
echo "로그 확인: docker logs -f certbot"
