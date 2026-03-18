#!/bin/sh
# Nginx 컨테이너 엔트리포인트
# - Nginx는 포그라운드 옵션으로 실행합니다.
# - access.log는 stdout으로 전달해 docker logs에서도 확인할 수 있게 합니다.

set -eu

NGINX_PID=""
TAIL_PID=""

# 1. 종료 신호를 받으면 관련 프로세스를 함께 정리합니다.
cleanup() {
    if [ -n "${TAIL_PID}" ] && kill -0 "${TAIL_PID}" 2>/dev/null; then
        kill "${TAIL_PID}" 2>/dev/null || true
    fi

    if [ -n "${NGINX_PID}" ] && kill -0 "${NGINX_PID}" 2>/dev/null; then
        kill "${NGINX_PID}" 2>/dev/null || true
    fi
}

trap cleanup INT TERM

# 2. Nginx를 실행하고 PID를 저장합니다.
nginx -g 'daemon off;' &
NGINX_PID=$!

# 3. access.log를 stdout으로 스트리밍합니다.
tail -F /var/log/nginx/access.log &
TAIL_PID=$!

# 4. 메인 Nginx 프로세스가 종료될 때까지 대기합니다.
wait "${NGINX_PID}"

# 5. Nginx 종료 후 tail 프로세스도 정리합니다.
cleanup
wait "${TAIL_PID}" 2>/dev/null || true
