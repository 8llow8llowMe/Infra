#!/usr/bin/env sh
# deploy 서버에서 Grafana, Prometheus, node_exporter 모니터링 기본 스택을 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. Grafana 관리자 비밀번호를 변경한 뒤 다시 실행하세요."
fi

get_env_value() {
  grep -E "^$1=" ./.env | tail -n 1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

GRAFANA_ADMIN_PASSWORD="$(get_env_value GRAFANA_ADMIN_PASSWORD)"

if [ "$GRAFANA_ADMIN_PASSWORD" = "change-me-to-a-long-random-password" ] || [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
  echo "GRAFANA_ADMIN_PASSWORD가 아직 기본값입니다."
  echo ".env에서 긴 임의 문자열로 변경한 뒤 다시 실행하세요."
  exit 1
fi

mkdir -p \
  ./prometheus-data \
  ./grafana-data \
  ./loki-data \
  ./promtail-data \
  ./prometheus \
  ./loki \
  ./promtail \
  ./grafana/provisioning/datasources

# Grafana는 UID 472, Prometheus는 UID 65534, Loki는 UID 10001로 쓰기 권한이 필요합니다.
if [ "$(id -u)" -eq 0 ]; then
  chown -R 472:472 ./grafana-data
  chown -R 65534:65534 ./prometheus-data
  chown -R 10001:10001 ./loki-data
elif command -v sudo >/dev/null 2>&1; then
  sudo chown -R 472:472 ./grafana-data
  sudo chown -R 65534:65534 ./prometheus-data
  sudo chown -R 10001:10001 ./loki-data
else
  echo "sudo가 없어 데이터 디렉터리 소유권을 자동으로 변경하지 못했습니다."
  echo "권한 오류가 나면 다음 명령을 직접 실행하세요."
  echo "  sudo chown -R 472:472 grafana-data"
  echo "  sudo chown -R 65534:65534 prometheus-data"
  echo "  sudo chown -R 10001:10001 loki-data"
fi

docker compose --env-file .env -f docker-compose-monitoring-core.yml up -d

echo ""
echo "모니터링 기본 스택이 시작되었습니다."
echo "Grafana:    http://localhost:$(get_env_value GRAFANA_PORT)"
echo "Prometheus: http://localhost:$(get_env_value PROMETHEUS_PORT)"
echo ""
echo "Loki/Promtail까지 켜려면 다음 명령을 사용하세요."
echo "  docker compose --env-file .env -f docker-compose-monitoring-core.yml -f docker-compose-monitoring-logs.yml up -d"
echo ""
echo "로그 확인:"
echo "  docker logs -f grafana"
echo "  docker logs -f prometheus"
