#!/bin/bash
set -e

DOMAIN="도메인명"
EMAIL="your-email@example.com"
LE_DIR="./letsencrypt"

# 추가 옵션: --strong-dh 주면 4096bit 사용
DH_BITS=2048
if [[ "$1" == "--strong-dh" ]]; then
  DH_BITS=4096
fi

# 필요한 SSL 설정 파일이 없으면 미리 생성
if [ ! -f "$LE_DIR/options-ssl-nginx.conf" ]; then
  echo "[init] options-ssl-nginx.conf 다운로드"
  curl -fSL https://raw.githubusercontent.com/certbot/certbot/main/certbot-nginx/src/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    -o "$LE_DIR/options-ssl-nginx.conf"
fi

if [ ! -f "$LE_DIR/ssl-dhparams.pem" ]; then
  echo "[init] ssl-dhparams.pem 생성 (${DH_BITS}bit)"
  openssl dhparam -out "$LE_DIR/ssl-dhparams.pem" $DH_BITS
fi

# certbot 컨테이너에서 최초 인증서 발급
echo "[init] 인증서 발급 시작"
docker compose -f docker-compose-certbot.yml run --rm \
  --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "$DOMAIN" -d "www.$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email

# 발급 완료 후 nginx reload
docker exec nginx nginx -s reload

echo "[$DOMAIN] SSL 인증서 발급 및 Nginx 리로드 완료"
