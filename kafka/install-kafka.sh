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

# bitnami -> 공식 apache/kafka 이전 과정에서 변수명이 바뀌었다. 이전 .env 를 쓰면 조용히 실패하므로 먼저 막는다.
if [ -z "${KAFKA_CLUSTER_ID:-}" ]; then
  echo "KAFKA_CLUSTER_ID 가 없습니다."
  echo "공식 apache/kafka 이미지로 이전하면서 KAFKA_KRAFT_CLUSTER_ID -> KAFKA_CLUSTER_ID 로 이름이 바뀌었습니다."
  echo ".env 를 .env.example 기준으로 갱신해주세요. (README '공식 이미지 이전' 참고)"
  exit 1
fi

if [ "${KAFKA_EXTERNAL_HOST:-localhost}" = "localhost" ]; then
  echo "KAFKA_EXTERNAL_HOST 가 아직 localhost 입니다."
  echo "원격 클라이언트나 다른 서버에서 접속할 계획이면 .env 에 Kafka 호스트 IP 또는 DNS 를 넣어주세요."
fi

mkdir -p "$KAFKA_1_DATA_DIR" "$KAFKA_2_DATA_DIR" "$KAFKA_3_DATA_DIR"

# 공식 이미지는 UID/GID 1000(appuser)으로 실행되므로 데이터 디렉터리 소유자를 맞춘다.
# 소유자가 다르면 브로커가 로그 디렉터리를 만들지 못해 기동 직후 죽는다.
for dir in "$KAFKA_1_DATA_DIR" "$KAFKA_2_DATA_DIR" "$KAFKA_3_DATA_DIR"; do
  if [ "$(stat -c '%u:%g' "$dir" 2>/dev/null || echo unknown)" != "1000:1000" ]; then
    if ! chown 1000:1000 "$dir" 2>/dev/null; then
      echo "경고: $dir 소유자를 1000:1000 으로 바꾸지 못했습니다. 아래를 직접 실행해주세요."
      echo "  sudo chown -R 1000:1000 $KAFKA_1_DATA_DIR $KAFKA_2_DATA_DIR $KAFKA_3_DATA_DIR"
    fi
  fi
done

docker compose --env-file .env -f docker-compose-kafka.yml config >/dev/null

docker compose --env-file .env -f docker-compose-kafka.yml up -d

echo ""
echo "Kafka 3노드 클러스터가 시작되었습니다. (${KAFKA_IMAGE})"
echo "내부 Docker 네트워크 bootstrap servers: kafka-1:9092,kafka-2:9092,kafka-3:9092"
echo "외부 bootstrap servers: ${KAFKA_EXTERNAL_HOST}:${KAFKA_1_EXTERNAL_PORT},${KAFKA_EXTERNAL_HOST}:${KAFKA_2_EXTERNAL_PORT},${KAFKA_EXTERNAL_HOST}:${KAFKA_3_EXTERNAL_PORT}"
echo "Kafka UI: http://localhost:${KAFKA_UI_PORT}"
echo ""
echo "상태 확인:"
echo "  docker compose --env-file .env -f docker-compose-kafka.yml ps"
echo "  docker logs -f kafka-1"
echo "  docker logs -f ${KAFKA_UI_CONTAINER_NAME}"
echo ""
echo "quorum 확인:"
echo "  docker exec -it kafka-1 /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status"
