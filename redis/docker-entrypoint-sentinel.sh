#!/bin/sh
# Entrypoint: sentinel.conf에서 환경변수 치환 후 redis-sentinel 실행
# - 템플릿 파일명을 sentinel.conf로 통일 (직접 덮어쓰기 방지 위해 임시 파일 사용)

set -e

CONF_SOURCE="/etc/redis/sentinel.conf"     # 원본 (환경변수 placeholder 포함)
CONF_RENDERED="/tmp/sentinel.conf"         # 실제 적용용 임시 파일

# sentinel.conf 파일이 존재하면 envsubst로 환경변수 치환하여 임시 파일 생성
if [ -f "$CONF_SOURCE" ]; then
  echo "[INFO] Rendering sentinel.conf with environment variables..."
  envsubst < "$CONF_SOURCE" > "$CONF_RENDERED"
else
  echo "[WARN] sentinel.conf not found, using default config"
  CONF_RENDERED="$CONF_SOURCE"
fi

# redis-sentinel 실행 (PID 1 유지)
echo "[INFO] Starting Redis Sentinel..."
exec redis-sentinel "$CONF_RENDERED"
