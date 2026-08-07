#!/usr/bin/env sh
# Kafka 3노드(KRaft) 클러스터 + Kafka UI + kafka-exporter 를 실행합니다.
#
# KAFKA_CLUSTER_ID 가 비어 있으면 새로 생성해 .env 에 기록합니다.
# 클러스터 ID 는 최초 스토리지 포맷 때 디스크에 새겨지므로, 한 번 정하면 바꿀 수 없습니다.

set -eu

ENV_FILE=./.env

if [ ! -f "$ENV_FILE" ]; then
  cp ./.env.example "$ENV_FILE"
  echo ".env.example을 복사해 .env를 생성했습니다."
  echo "KAFKA_EXTERNAL_HOST 값을 확인한 뒤 다시 실행하세요. (KAFKA_CLUSTER_ID 는 자동 생성됩니다)"
  exit 0
fi

# .env 를 셸로 source 하지 않고 필요한 KEY=VALUE 만 읽는다.
#
# source 하면 KAFKA_HEAP_OPTS=-Xms512m -Xmx512m 처럼 값에 공백이 있는 항목을
# 셸이 "환경변수 접두어 + 명령" 으로 해석해 `-Xmx512m: not found` 로 죽는다.
# Windows 에서 편집해 CRLF 가 섞인 경우도 있어 캐리지 리턴을 함께 제거한다.
# docker compose 는 --env-file 로 .env 를 직접 읽으므로 export 할 필요가 없다.
read_env() {
  value=$(sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1 | tr -d '\r')
  # docker compose 의 env-file 파서와 같게 감싼 따옴표를 제거한다.
  case "$value" in
    \"*\") value=${value#\"}; value=${value%\"} ;;
    \'*\') value=${value#\'}; value=${value%\'} ;;
  esac
  printf '%s' "$value"
}

KAFKA_IMAGE=$(read_env KAFKA_IMAGE)
KAFKA_CLUSTER_ID=$(read_env KAFKA_CLUSTER_ID)
KAFKA_EXTERNAL_HOST=$(read_env KAFKA_EXTERNAL_HOST)
KAFKA_1_DATA_DIR=$(read_env KAFKA_1_DATA_DIR)
KAFKA_2_DATA_DIR=$(read_env KAFKA_2_DATA_DIR)
KAFKA_3_DATA_DIR=$(read_env KAFKA_3_DATA_DIR)
KAFKA_1_EXTERNAL_PORT=$(read_env KAFKA_1_EXTERNAL_PORT)
KAFKA_2_EXTERNAL_PORT=$(read_env KAFKA_2_EXTERNAL_PORT)
KAFKA_3_EXTERNAL_PORT=$(read_env KAFKA_3_EXTERNAL_PORT)
KAFKA_UI_PORT=$(read_env KAFKA_UI_PORT)
KAFKA_UI_CONTAINER_NAME=$(read_env KAFKA_UI_CONTAINER_NAME)

# bitnami -> 공식 apache/kafka 이전 과정에서 변수명이 바뀌었다. 이전 .env 를 쓰면 조용히 실패하므로 먼저 막는다.
if ! grep -q '^KAFKA_CLUSTER_ID=' "$ENV_FILE"; then
  echo "오류: .env 에 KAFKA_CLUSTER_ID 항목이 없습니다."
  echo "공식 apache/kafka 이미지로 이전하면서 KAFKA_KRAFT_CLUSTER_ID -> KAFKA_CLUSTER_ID 로 이름이 바뀌었습니다."
  echo ".env.example 기준으로 .env 를 갱신해주세요. (README '공식 이미지 이전' 참고)"
  exit 1
fi

for required in KAFKA_IMAGE KAFKA_1_DATA_DIR KAFKA_2_DATA_DIR KAFKA_3_DATA_DIR; do
  eval "required_value=\${$required}"
  if [ -z "$required_value" ]; then
    echo "오류: .env 의 $required 값이 비어 있습니다. .env.example 을 참고해 채워주세요."
    exit 1
  fi
done

# KRaft 클러스터 ID 를 생성한다.
# 1순위: Kafka 공식 도구. base64url 16바이트라는 형식이 보장된다.
# 2순위: openssl 난수. Kafka 의 Uuid 표기와 같은 형식(패딩 없는 base64url)으로 변환한다.
generate_cluster_id() {
  generated=''

  if generated=$(docker run --rm "$KAFKA_IMAGE" /opt/kafka/bin/kafka-storage.sh random-uuid 2>/dev/null); then
    generated=$(printf '%s' "$generated" | tr -d '\r\n')
    if [ -n "$generated" ]; then
      printf '%s' "$generated"
      return 0
    fi
  fi

  if command -v openssl >/dev/null 2>&1; then
    openssl rand 16 | base64 | tr '+/' '-_' | tr -d '=\r\n'
    return 0
  fi

  return 1
}

# .env 의 KAFKA_CLUSTER_ID 값을 교체한다.
# sed -i 는 GNU/BSD 문법이 달라 awk + 임시 파일로 처리하고, 원본 파일 권한을 유지하려고 덮어쓴다.
persist_cluster_id() {
  awk -v id="$1" '
    /^KAFKA_CLUSTER_ID=/ { print "KAFKA_CLUSTER_ID=" id; next }
    { print }
  ' "$ENV_FILE" > "$ENV_FILE.tmp"
  cat "$ENV_FILE.tmp" > "$ENV_FILE"
  rm -f "$ENV_FILE.tmp"
}

if [ -z "$KAFKA_CLUSTER_ID" ]; then
  # 이미 포맷된 데이터가 있는데 ID 를 새로 만들면 디스크에 새겨진 ID 와 달라 브로커가 기동하지 못한다.
  for data_dir in "$KAFKA_1_DATA_DIR" "$KAFKA_2_DATA_DIR" "$KAFKA_3_DATA_DIR"; do
    if [ -n "$(ls -A "$data_dir" 2>/dev/null || true)" ]; then
      echo "오류: $data_dir 에 이미 데이터가 있는데 KAFKA_CLUSTER_ID 가 비어 있습니다."
      echo "포맷된 클러스터의 ID 는 meta.properties 에서 확인해 .env 에 직접 넣어주세요."
      echo "  grep cluster.id $data_dir/meta.properties"
      echo "데이터를 버려도 된다면 데이터 디렉터리를 삭제한 뒤 다시 실행하세요."
      exit 1
    fi
  done

  echo "KAFKA_CLUSTER_ID 가 비어 있어 새로 생성합니다."
  if ! new_cluster_id=$(generate_cluster_id) || [ -z "$new_cluster_id" ]; then
    echo "오류: 클러스터 ID 생성에 실패했습니다. (docker 실행과 openssl 모두 불가)"
    echo "아래 명령으로 직접 만들어 .env 의 KAFKA_CLUSTER_ID 에 넣어주세요."
    echo "  docker run --rm $KAFKA_IMAGE /opt/kafka/bin/kafka-storage.sh random-uuid"
    exit 1
  fi

  persist_cluster_id "$new_cluster_id"
  KAFKA_CLUSTER_ID="$new_cluster_id"

  echo "생성한 KAFKA_CLUSTER_ID: $KAFKA_CLUSTER_ID"
  echo ".env 에 기록했습니다. 이 값은 최초 포맷 때 디스크에 새겨지므로 이후 바꾸지 마세요."
fi

if [ "${KAFKA_EXTERNAL_HOST:-localhost}" = "localhost" ] || [ -z "$KAFKA_EXTERNAL_HOST" ]; then
  echo "KAFKA_EXTERNAL_HOST 가 아직 localhost 입니다."
  echo "원격 클라이언트나 다른 서버에서 접속할 계획이면 .env 에 Kafka 호스트 IP 또는 DNS 를 넣어주세요."
fi

mkdir -p "$KAFKA_1_DATA_DIR" "$KAFKA_2_DATA_DIR" "$KAFKA_3_DATA_DIR"

# 공식 이미지는 UID/GID 1000(appuser)으로 실행되므로 데이터 디렉터리 소유자를 맞춘다.
# 소유자가 다르면 브로커가 로그 디렉터리를 만들지 못해 기동 직후 죽는다.
for data_dir in "$KAFKA_1_DATA_DIR" "$KAFKA_2_DATA_DIR" "$KAFKA_3_DATA_DIR"; do
  if [ "$(stat -c '%u:%g' "$data_dir" 2>/dev/null || echo unknown)" != "1000:1000" ]; then
    if ! chown 1000:1000 "$data_dir" 2>/dev/null; then
      echo "경고: $data_dir 소유자를 1000:1000 으로 바꾸지 못했습니다. 아래를 직접 실행해주세요."
      echo "  sudo chown -R 1000:1000 $KAFKA_1_DATA_DIR $KAFKA_2_DATA_DIR $KAFKA_3_DATA_DIR"
    fi
  fi
done

docker compose --env-file .env -f docker-compose-kafka.yml config >/dev/null

docker compose --env-file .env -f docker-compose-kafka.yml up -d

echo ""
echo "Kafka 3노드 클러스터가 시작되었습니다. (${KAFKA_IMAGE})"
echo "클러스터 ID: ${KAFKA_CLUSTER_ID}"
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
