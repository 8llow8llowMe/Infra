# Redis + Sentinel 공용 Dockerfile
FROM redis:8.0.5-alpine

# envsubst 제공용 gettext 설치
RUN apk add --no-cache gettext

WORKDIR /usr/local/etc/redis

# entrypoint는 compose에서 override (redis or sentinel용 스크립트)
ENTRYPOINT ["sh"]
