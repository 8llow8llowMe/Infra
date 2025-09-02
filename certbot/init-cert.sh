#!/bin/bash
set -e

DOMAIN="도메인명"
EMAIL="your-email@example.com"

# certbot 컨테이너에서 인증서 발급 (docker-compose-certbot.yml에 있는 entrypoint 무시하고 certbot 실행)
docker compose -f docker-compose-certbot.yml run --rm \
  --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d $DOMAIN -d www.$DOMAIN \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email

# 발급 완료 후 Host에서 nginx reload
docker exec nginx nginx -s reload

echo "[$DOMAIN] SSL 인증서 발급 및 Nginx 리로드 완료"