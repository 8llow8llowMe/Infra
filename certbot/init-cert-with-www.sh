#!/usr/bin/env bash
# 기본 도메인과 www 도메인 Let's Encrypt 인증서를 최초 발급합니다.

set -euo pipefail

DOMAIN="${1:-${CERTBOT_DOMAIN:-}}"
EMAIL="${CERTBOT_EMAIL:-}"
LE_DIR="./letsencrypt"
DH_BITS=2048

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. CERTBOT_EMAIL 값을 확인하세요."
fi

if [ -f ./.env ]; then
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
  DOMAIN="${1:-${CERTBOT_DOMAIN:-$DOMAIN}}"
  EMAIL="${CERTBOT_EMAIL:-$EMAIL}"
fi

if [ -z "$DOMAIN" ]; then
  echo "사용법: CERTBOT_EMAIL=me@example.com $0 example.com"
  echo "또는 .env에 CERTBOT_EMAIL을 설정한 뒤 $0 example.com"
  exit 1
fi

if [ -z "$EMAIL" ] || [ "$EMAIL" = "your-email@example.com" ]; then
  echo "CERTBOT_EMAIL을 실제 이메일로 설정하세요."
  exit 1
fi

if [ "${2:-}" = "--strong-dh" ]; then
  DH_BITS=4096
fi

mkdir -p "$LE_DIR" ./webroot ./logs

if [ ! -f "$LE_DIR/options-ssl-nginx.conf" ]; then
  echo "[init] options-ssl-nginx.conf 다운로드"
  curl -fSL https://raw.githubusercontent.com/certbot/certbot/main/certbot-nginx/src/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    -o "$LE_DIR/options-ssl-nginx.conf"
fi

if [ ! -f "$LE_DIR/ssl-dhparams.pem" ]; then
  echo "[init] ssl-dhparams.pem 생성 (${DH_BITS}bit)"
  openssl dhparam -out "$LE_DIR/ssl-dhparams.pem" "$DH_BITS"
fi

echo "[init] ${DOMAIN}, www.${DOMAIN} 인증서 발급 시작"
docker compose --env-file .env -f docker-compose-certbot.yml run --rm \
  --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "$DOMAIN" -d "www.$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email

docker exec "${NGINX_CONTAINER:-nginx}" nginx -s reload

echo "[${DOMAIN}, www.${DOMAIN}] SSL 인증서 발급 및 Nginx reload 완료"
