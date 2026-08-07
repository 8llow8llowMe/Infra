# Kafka 운영 가이드

이 디렉터리는 BossPickSeoul 인프라에 **Kafka 단일 브로커(KRaft) + Kafka UI** 를 Docker Compose 로 추가하기 위한 구성입니다.

현재 Infra 레포 패턴에 맞춰 `docker-compose-*.yml`, `.env.example`, `install-*.sh`, `README.md` 구조를 그대로 따릅니다.

## 구성 요약

- 브로커: `bitnami/kafka:3.9.0`
- 모드: **KRaft 단일 노드** (`broker,controller` 동시 역할)
- UI: `ghcr.io/kafbat/kafka-ui:v1.2.0` (provectuslabs/kafka-ui 는 개발 중단 — 유지보수 포크로 교체)
- 내부 접속 주소: `kafka:9092` (같은 호스트의 `8llow8llowme-net` 컨테이너 전용)
- 외부 접속 주소: `${KAFKA_EXTERNAL_HOST}:${KAFKA_EXTERNAL_PORT}` (다른 서버의 클라이언트용)
- Docker 네트워크: `8llow8llowme-net`

`8llow8llowme-net` 은 **호스트마다 별개인 bridge 네트워크**라서, `kafka:9092` 컨테이너명 DNS 는
Kafka 와 같은 호스트에 있는 컨테이너에서만 동작합니다. 다른 서버에서 붙는 클라이언트
(예: main-server 의 dev 백엔드)는 반드시 EXTERNAL 리스너(`서버IP:19092`)를 사용해야 합니다.

### 이미지 유지보수 주의

- `bitnami/kafka` 공개 카탈로그는 2025년부터 갱신이 동결됐습니다. 고정 태그(3.9.0)는 계속
  동작하지만 보안 패치가 없으므로, 장기적으로는 공식 `apache/kafka` 이미지로의 이전을 권장합니다.
  (환경변수 접두어가 `KAFKA_CFG_*` → `KAFKA_*` 로 바뀌고 경로가 `/opt/kafka` 로 달라져
  compose 재작성이 필요 — 별도 작업으로 진행)

## 이 구성이 맞는 이유

현재 BossPickSeoul 쪽은 Redis 기반 비동기 처리와 실시간성 요구가 이미 있고, 앞으로 아래 이벤트를 쌓기 좋습니다.

- 자치구 분석 요청/완료 이벤트
- 행정동 분석 요청/완료 이벤트
- 상권 분석 요청/완료 이벤트
- 결과 조회 이벤트
- 추천/검색 선택 이벤트
- 실시간 인기 순위 집계 이벤트

즉, **읽기 캐시는 Redis**, **이벤트 적재와 재처리는 Kafka** 로 분리하는 구조에 잘 맞습니다.

## 파일 구조

```text
kafka/
├── docker-compose-kafka.yml
├── install-kafka.sh
├── .env.example
├── .gitignore
└── README.md
```

실행 후 생성되는 로컬 데이터:

- `kafka-data/`: Kafka 로그 세그먼트와 메타데이터 저장소

## 환경변수 준비

```bash
cd kafka
cp .env.example .env
```

운영 전에 특히 아래 값은 확인합니다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `KAFKA_IMAGE` | Kafka 이미지 | `bitnami/kafka:3.9.0` |
| `KAFKA_CONTAINER_NAME` | Kafka 컨테이너 이름 | `kafka` |
| `KAFKA_KRAFT_CLUSTER_ID` | KRaft 클러스터 ID | `MkU3OEVBNTcwNTJENDM2Qk` |
| `KAFKA_EXTERNAL_PORT` | 외부 advertised listener 포트 | `19092` |
| `KAFKA_EXTERNAL_HOST` | 외부 클라이언트가 바라볼 호스트 IP 또는 DNS | `192.168.0.10` |
| `KAFKA_HEAP_OPTS` | JVM heap 설정 | `-Xms512m -Xmx512m` |
| `KAFKA_MEM_LIMIT` | Kafka 컨테이너 메모리 상한 (heap + page cache 여유) | `1g` |
| `KAFKA_UI_MEM_LIMIT` | Kafka UI 컨테이너 메모리 상한 | `512m` |
| `KAFKA_NUM_PARTITIONS` | 기본 파티션 수 | `3` |
| `KAFKA_AUTO_CREATE_TOPICS_ENABLE` | 토픽 자동 생성 허용 여부 | `false` |
| `KAFKA_DATA_DIR` | 호스트 데이터 경로 | `./kafka-data` |
| `KAFKA_UI_IMAGE` | Kafka UI 이미지 | `provectuslabs/kafka-ui:v0.7.2` |
| `KAFKA_UI_CONTAINER_NAME` | Kafka UI 컨테이너 이름 | `kafka-ui` |
| `KAFKA_UI_PORT` | Kafka UI 외부 포트 | `18080` |
| `TZ` | 타임존 | `Asia/Seoul` |

### `KAFKA_EXTERNAL_HOST` 중요

같은 Docker 네트워크 안에서만 쓸 거면 내부 서비스는 `kafka:9092` 를 사용합니다. 이 내부 포트는 호스트에 직접 공개하지 않습니다.

하지만 아래 경우에는 `.env` 의 `KAFKA_EXTERNAL_HOST` 를 **실제 서버 IP 또는 DNS** 로 바꿔야 합니다.

- 로컬 PC 에서 Kafka client 로 직접 붙는 경우
- 다른 서버의 배치/운영 도구가 Kafka 에 붙는 경우
- Jenkins, kcat, IDE plugin 등 외부 클라이언트가 붙는 경우

예시:

```env
KAFKA_EXTERNAL_HOST=192.168.0.10
```

## 배치 호스트 권장

현재 서버 상황 기준 권장 배치입니다 (Kafka + UI 합산 약 1.5GB).

| 서버 | 권장 여부 | 이유 |
| --- | --- | --- |
| `ollama-01` (192.168.0.10, x86 32GB) | **권장** | 메모리 여유가 가장 크고 Jenkins/Vault 와 동거 부담이 적다 |
| 추후 백엔드 미니PC | 권장 (이전 대상) | 백엔드 전용 서버 구성 시 함께 이전 |
| `main-server` (192.168.0.11, Pi 8GB) | 비권장 | MySQL + Redis master + dev 백엔드가 이미 동거 중 |
| `backend-1` (192.168.0.13, Pi 8GB) | 비권장 | 메모리 포화 상태 |

Kafka UI(18080)는 인증이 없으므로 사설망에서만 접근하고 공개망/포트포워딩에 노출하지 않습니다.

## 실행

스크립트 사용:

```bash
cd kafka
sh install-kafka.sh
```

직접 실행:

```bash
cd kafka
docker compose --env-file .env -f docker-compose-kafka.yml up -d
```

상태 확인:

```bash
docker compose --env-file .env -f docker-compose-kafka.yml ps
docker logs -f kafka
docker logs -f kafka-ui
```

중지:

```bash
docker compose --env-file .env -f docker-compose-kafka.yml down
```

Compose 문법 확인:

```bash
docker compose --env-file .env -f docker-compose-kafka.yml config
```

## 접속 주소

Kafka UI:

```text
http://<host-ip>:18080
```

내부 Docker 네트워크에서 Kafka bootstrap server:

```text
kafka:9092
```

외부 클라이언트 bootstrap server:

```text
<host-ip-or-dns>:19092
```

## 토픽 생성 예시

자동 토픽 생성은 기본값으로 꺼두었습니다. 운영 중 실수로 토픽이 생기는 걸 줄이기 위함입니다.

예시 토픽:

- `bosspick.analysis-events`
- `bosspick.analysis-ranking`
- `bosspick.search-events`
- `bosspick.recommendation-events`

생성 예시:

```bash
docker exec -it kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
  --create \
  --topic bosspick.analysis-events \
  --partitions 3 \
  --replication-factor 1 \
  --bootstrap-server localhost:9092
```

목록 확인:

```bash
docker exec -it kafka /opt/bitnami/kafka/bin/kafka-topics.sh \
  --list \
  --bootstrap-server localhost:9092
```

## BossPickSeoul 백엔드 연동 예시

bootstrap server 값은 **백엔드와 Kafka 가 같은 호스트인지**에 따라 달라집니다.

```env
# Kafka 와 같은 호스트에서 도는 컨테이너 (컨테이너명 DNS)
SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092

# 다른 호스트의 백엔드 (예: main-server 의 dev 백엔드 -> ollama-01 의 Kafka)
SPRING_KAFKA_BOOTSTRAP_SERVERS=192.168.0.10:19092

APP_ANALYSIS_EVENTS_TOPIC=bosspick.analysis-events
APP_ANALYSIS_RANKING_TOPIC=bosspick.analysis-ranking
```

현재 토폴로지(dev 백엔드 = main-server)에서는 Kafka 를 ollama-01 에 올리는 경우
dev 백엔드의 Vault 시크릿에 `192.168.0.10:19092` 를 넣어야 합니다.
이때 `.env` 의 `KAFKA_EXTERNAL_HOST=192.168.0.10` 설정이 선행되어야 합니다.

추천 이벤트 흐름은 아래처럼 가져가면 됩니다.

```text
사용자 분석 요청/조회
-> application event publish
-> Kafka topic 적재
-> ranking consumer 집계
-> Redis sorted set 반영
-> 인기 순위 API 조회
```

즉, 실시간 인기 순위는 다음 구조가 안정적입니다.

```text
Kafka: 이벤트 수집, 재처리, consumer 확장
Redis: 실시간 랭킹 조회 캐시
MySQL: 필요 시 집계 스냅샷 또는 배치 보관
```

## 운영 제한사항

이 구성은 **단일 브로커** 입니다.

따라서 아래 특성이 있습니다.

- replication factor 는 `1` 이어야 합니다.
- 브로커 장애 시 Kafka 자체 고가용성은 없습니다.
- 홈랩/단일 호스트 운영 또는 초기 서비스 단계에는 적합합니다.
- production 급 내결함성이 필요하면 3 broker 이상으로 확장해야 합니다.

나중에 확장하려면 다음 순서가 자연스럽습니다.

1. Kafka 브로커 3대 이상 분리
2. controller quorum 분리
3. 토픽 replication factor 상향
4. consumer group scale-out
5. 모니터링(exporter + Grafana) 추가

## 문제 해결

### 1. Kafka UI 에서 브로커가 안 보임

확인:

```bash
docker logs -f kafka-ui
docker logs -f kafka
```

보통은 아래를 확인하면 됩니다.

- `kafka` 컨테이너가 healthy 인지
- `8llow8llowme-net` 네트워크가 존재하는지
- `KAFKA_CFG_ADVERTISED_LISTENERS` 의 외부 호스트 값이 잘못되지 않았는지

네트워크 확인:

```bash
docker network inspect 8llow8llowme-net
```

### 2. 외부 클라이언트 접속이 안 됨

주로 `KAFKA_EXTERNAL_HOST` 값 문제입니다.

- `localhost` 로 두면 원격 PC 는 접속할 수 없습니다.
- 실제 서버 IP 또는 DNS 로 수정 후 재기동합니다.

```bash
docker compose --env-file .env -f docker-compose-kafka.yml down
docker compose --env-file .env -f docker-compose-kafka.yml up -d
```

### 3. 토픽 생성은 되는데 producer/consumer 가 메타데이터 에러를 냄

대부분 advertised listener 문제입니다.

점검 포인트:

- 내부 서비스 -> `kafka:9092` 사용
- 외부 툴 -> `${KAFKA_EXTERNAL_HOST}:${KAFKA_EXTERNAL_PORT}` 사용
- `.env` 의 host/port 와 실제 방화벽/NAT 설정 일치 여부 확인

### 4. 데이터 초기화

모든 Kafka 데이터를 비우려면 컨테이너를 내리고 `kafka-data/` 를 삭제한 뒤 다시 올립니다.

```bash
docker compose --env-file .env -f docker-compose-kafka.yml down
rm -rf kafka-data
sh install-kafka.sh
```

운영 중에는 토픽 데이터가 전부 사라지므로 신중하게 사용합니다.

## 권장 다음 단계

Kafka 만 띄우는 것으로 끝내지 말고, BossPickSeoul 쪽에는 아래를 이어서 붙이는 걸 권장합니다.

1. `analysis-events` 토픽 정의
2. Spring producer 공통 모듈 추가
3. ranking consumer 추가
4. Redis Sorted Set 인기순위 캐시 구성
5. 인기 자치구/행정동/상권 조회 API 추가
6. Grafana/Prometheus 로 Kafka 지표 연동

