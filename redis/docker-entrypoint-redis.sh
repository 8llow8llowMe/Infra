#!/bin/sh
# Entrypoint: redis.conf 템플릿 내 환경변수 치환 후 redis-server 실행
set -e

CONF_SOURCE="/usr/local/etc/redis/redis.conf"
CONF_RENDERED="/tmp/redis.conf"

if [ -f "$CONF_SOURCE" ]; then
  echo "[INFO] Rendering redis.conf with environment variables..."
  envsubst < "$CONF_SOURCE" > "$CONF_RENDERED"
else
  echo "[WARN] redis.conf not found, using default config"
  CONF_RENDERED="$CONF_SOURCE"
fi

echo "[INFO] Starting Redis Server..."
exec redis-server "$CONF_RENDERED"