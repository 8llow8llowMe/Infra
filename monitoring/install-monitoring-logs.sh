#!/usr/bin/env sh
# monitoring 서버에서 Loki와 Promtail 로그 중앙화 스택을 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. 필요한 값을 확인한 뒤 다시 실행하세요."
fi

mkdir -p \
  ./loki-data \
  ./promtail-data \
  ./loki \
  ./promtail

# Loki는 컨테이너 내부에서 UID 10001로 실행되므로 쓰기 권한을 맞춥니다.
if [ "$(id -u)" -eq 0 ]; then
  chown -R 10001:10001 ./loki-data
elif command -v sudo >/dev/null 2>&1; then
  sudo chown -R 10001:10001 ./loki-data
else
  echo "sudo가 없어 loki-data 소유권을 자동으로 변경하지 못했습니다."
  echo "권한 오류가 나면 다음 명령을 직접 실행하세요."
  echo "  sudo chown -R 10001:10001 loki-data"
fi

docker compose --project-directory . --env-file .env \
  -f loki/docker-compose-loki.yml \
  -f promtail/docker-compose-promtail.yml \
  up -d loki promtail

echo ""
echo "로그 중앙화 스택이 시작되었습니다."
echo "Loki:     http://localhost:3100"
echo "Promtail: monitoring 서버 Docker 로그를 Loki로 전송합니다."
echo ""
echo "상태 확인:"
echo "  docker logs -f loki"
echo "  docker logs -f promtail"
echo "  curl http://localhost:3100/ready"
