#!/usr/bin/env sh
# 애플리케이션 서버에서 node_exporter만 시작합니다.

set -eu

if [ ! -f ./.env.agent ]; then
  cp ./.env.agent.example ./.env.agent
  echo ".env.agent.example을 복사해 .env.agent를 생성했습니다."
fi

docker compose --env-file .env.agent -f docker-compose.agent.yml up -d

echo ""
echo "node_exporter 에이전트가 시작되었습니다."
echo "메트릭 확인:"
echo "  curl http://localhost:9100/metrics"
echo ""
echo "Prometheus target에는 이 서버의 IP와 9100 포트를 추가하세요."
