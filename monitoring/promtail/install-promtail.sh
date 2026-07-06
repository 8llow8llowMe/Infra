#!/usr/bin/env sh
# 애플리케이션 서버에서 Promtail만 시작합니다.

set -eu

if [ ! -f ./.env.agent ]; then
  cp ./.env.agent.example ./.env.agent
  echo ".env.agent.example을 복사해 .env.agent를 생성했습니다."
  echo "LOKI_PUSH_URL, PROMTAIL_HOSTNAME, PROMTAIL_PROJECT 값을 확인한 뒤 다시 실행하세요."
  exit 1
fi

docker compose --env-file .env.agent -f docker-compose-agent.yml up -d

echo ""
echo "Promtail 에이전트가 시작되었습니다."
echo "로그 전송 대상:"
echo "  $(grep -E '^LOKI_PUSH_URL=' ./.env.agent | tail -n 1 | cut -d= -f2-)"
echo ""
echo "상태 확인:"
echo "  docker logs -f promtail"
