#!/usr/bin/env sh
# Kafka 3노드(KRaft) 클러스터 + Kafka UI를 실행합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. KAFKA_EXTERNAL_HOST 값을 먼저 확인한 뒤 다시 실행하세요."
  exit 0
fi

set -a
. ./.env
set +a

if [ "${KAFKA_EXTERNAL_HOST:-localhost}" = "localhost" ]; then
  echo "KAFKA_EXTERNAL_HOST 가 아직 localhost 입니다."
  echo "원격 클라이언트나 다른 서버에서 접속할 계획이면 .env 에 Kafka 호스트 IP 또는 DNS 를 넣어주세요."
fi

mkdir -p "$KAFKA_1_DATA_DIR" "$KAFKA_2_DATA_DIR" "$KAFKA_3_DATA_DIR"

docker compose --env-file .env -f docker-compose-kafka.yml config >/dev/null

docker compose --env-file .env -f docker-compose-kafka.yml up -d

echo ""
echo "Kafka 3노드 클러스터가 시작되었습니다."
echo "내부 Docker 네트워크 bootstrap servers: kafka-1:9092,kafka-2:9092,kafka-3:9092"
echo "외부 bootstrap servers: ${KAFKA_EXTERNAL_HOST}:${KAFKA_1_EXTERNAL_PORT},${KAFKA_EXTERNAL_HOST}:${KAFKA_2_EXTERNAL_PORT},${KAFKA_EXTERNAL_HOST}:${KAFKA_3_EXTERNAL_PORT}"
echo "Kafka UI: http://localhost:${KAFKA_UI_PORT}"
echo ""
echo "상태 확인:"
echo "  docker compose --env-file .env -f docker-compose-kafka.yml ps"
echo "  docker logs -f kafka-1"
echo "  docker logs -f ${KAFKA_UI_CONTAINER_NAME}"
