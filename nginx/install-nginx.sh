#!/usr/bin/env sh
# Nginx 실행에 필요한 디렉터리를 준비하고 컨테이너를 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. TZ 값을 확인하세요."
fi

mkdir -p ./logs ../certbot/webroot ../certbot/letsencrypt

docker compose --env-file .env -f docker-compose-nginx.yml up -d --build

echo "Nginx가 시작되었습니다."
echo "설정 검증: docker exec nginx nginx -t"
echo "로그 확인: docker logs -f nginx"
