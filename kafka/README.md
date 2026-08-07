# Kafka 운영 가이드

이 디렉터리는 BossPickSeoul 인프라에 **Kafka 3노드 클러스터(KRaft) + Kafka UI** 를 Docker Compose 로 추가하기 위한 구성입니다.

현재 Infra 레포 패턴에 맞춰 `docker-compose-*.yml`, `.env.example`, `install-*.sh`, `README.md` 구조를 그대로 따릅니다.

## 구성 요약

- 브로커: `bitnami/kafka:3.9.0` × 3 (`kafka-1`, `kafka-2`, `kafka-3`)
- 모드: **KRaft combined** — 각 노드가 `broker,controller` 동시 역할
- controller quorum: `1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093`
- 복제: replication factor `3`, min ISR `2` (브로커 1대 장애까지 읽기/쓰기 지속)
- UI: `ghcr.io/kafbat/kafka-ui:v1.2.0` (provectuslabs/kafka-ui 는 개발 중단 — 유지보수 포크로 교체)
- 내부 접속 주소: `kafka-1:9092,kafka-2:9092,kafka-3:9092` (같은 호스트의 `8llow8llowme-net` 컨테이너 전용)
- 외부 접속 주소: `${KAFKA_EXTERNAL_HOST}:19092/29092/39092` (다른 서버의 클라이언트용)
- Docker 네트워크: `8llow8llowme-net`

공통 환경변수는 compose 상단의 `x-kafka-common-environment` 앵커 한 곳에서 관리하고,
노드별로 다른 값(`KAFKA_CFG_NODE_ID`, `KAFKA_CFG_ADVERTISED_LISTENERS`)만 각 서비스에서 덮어씁니다.
healthcheck / 메모리 상한 / logging 도 같은 방식의 앵커(`x-kafka-healthcheck`, `x-kafka-deploy`, `x-logging`)를 공유합니다.

### 왜 홀수 노드인가

KRaft 의 controller quorum 은 Raft 합의라 **과반(majority) 투표**로 리더를 유지합니다.

- 3노드: 과반 = 2 → **1대 장애 허용**
- 2노드: 과반 = 2 → 1대만 죽어도 과반 붕괴 (단일 노드보다 가용성이 나쁨)
- 4노드: 과반 = 3 → 허용 장애 수는 3노드와 같은 1대 (노드만 낭비)

그래서 controller quorum 은 3, 5 같은 홀수로 구성합니다. 이 구성은 3노드가 기본입니다.

### 단일 호스트 3브로커의 한계 (정직한 주의)

이 compose 는 **한 호스트에 브로커 3개**를 띄웁니다. 얻는 것과 못 얻는 것이 분명합니다.

- 얻는 것: 브로커 프로세스 장애 격리, 롤링 재시작(무중단 설정 반영), 파티션 복제/리밸런스 등 **실제 클러스터 운영 경험**
- 못 얻는 것: **호스트 장애 내성** — 서버가 죽으면 3대가 같이 죽고, 디스크도 같은 물리 디스크를 공유합니다

호스트 수준 HA 가 필요해지면 브로커를 서버 3대로 분리하는 것이 다음 단계입니다.

### 이미지 유지보수 주의

- `bitnami/kafka` 공개 카탈로그는 2025년부터 갱신이 동결됐습니다. 고정 태그(3.9.0)는 계속
  동작하지만 보안 패치가 없으므로, 장기적으로는 공식 `apache/kafka` 이미지로의 이전을 권장합니다.
  (환경변수 접두어가 `KAFKA_CFG_*` → `KAFKA_*` 로 바뀌고 경로가 `/opt/kafka` 로 달라져
  compose 재작성이 필요 — 별도 작업으로 진행)

## 파일 구조

```text
kafka/
├── docker-compose-kafka.yml
├── install-kafka.sh
├── .env.example
├── .gitignore
└── README.md
```

실행 후 생성되는 로컬 데이터 (노드별 분리):

- `kafka-1-data/`, `kafka-2-data/`, `kafka-3-data/`

## 환경변수 준비

```bash
cd kafka
cp .env.example .env
```

운영 전에 특히 아래 값은 확인합니다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `KAFKA_IMAGE` | Kafka 이미지 | `bitnami/kafka:3.9.0` |
| `KAFKA_KRAFT_CLUSTER_ID` | KRaft 클러스터 ID (3노드 공통) | `MkU3OEVBNTcwNTJENDM2Qk` |
| `KAFKA_1/2/3_EXTERNAL_PORT` | 노드별 외부 advertised listener 포트 | `19092` / `29092` / `39092` |
| `KAFKA_EXTERNAL_HOST` | 외부 클라이언트가 바라볼 호스트 IP 또는 DNS | `192.168.0.10` |
| `KAFKA_1/2/3_DATA_DIR` | 노드별 호스트 데이터 경로 | `./kafka-1-data` 등 |
| `KAFKA_HEAP_OPTS` | 노드당 JVM heap 설정 | `-Xms512m -Xmx512m` |
| `KAFKA_MEM_LIMIT` | 노드당 컨테이너 메모리 상한 | `1g` |
| `KAFKA_UI_MEM_LIMIT` | Kafka UI 컨테이너 메모리 상한 | `512m` |
| `KAFKA_NUM_PARTITIONS` | 기본 파티션 수 | `3` |
| `KAFKA_DEFAULT_REPLICATION_FACTOR` | 기본 복제 계수 (3노드 기준 3) | `3` |
| `KAFKA_TRANSACTION_STATE_LOG_MIN_ISR` | 최소 ISR (3노드 기준 2) | `2` |
| `KAFKA_AUTO_CREATE_TOPICS_ENABLE` | 토픽 자동 생성 허용 여부 | `false` |
| `KAFKA_UI_IMAGE` | Kafka UI 이미지 | `ghcr.io/kafbat/kafka-ui:v1.2.0` |
| `KAFKA_UI_PORT` | Kafka UI 외부 포트 | `18080` |
| `TZ` | 타임존 | `Asia/Seoul` |

내부 리스너(9092)와 컨트롤러 포트(9093)는 컨테이너 내부 고정이라 변수로 두지 않습니다.

### `KAFKA_EXTERNAL_HOST` 중요

`8llow8llowme-net` 은 **호스트마다 별개인 bridge 네트워크**라서, `kafka-1:9092` 같은 컨테이너명 DNS 는
Kafka 와 같은 호스트에 있는 컨테이너에서만 동작합니다.

아래 경우에는 `.env` 의 `KAFKA_EXTERNAL_HOST` 를 **실제 서버 IP 또는 DNS** 로 바꿔야 합니다.

- 다른 서버의 백엔드가 붙는 경우 (예: main-server 의 dev 백엔드)
- 로컬 PC 에서 Kafka client 로 직접 붙는 경우
- Jenkins, kcat, IDE plugin 등 외부 클라이언트가 붙는 경우

예시:

```env
KAFKA_EXTERNAL_HOST=192.168.0.10
```

## 배치 호스트 권장

현재 서버 상황 기준 권장 배치입니다 (브로커 3 × 1g + UI 512m + exporter 128m = **합산 약 3.6GB**).

| 서버 | 권장 여부 | 이유 |
| --- | --- | --- |
| `ollama-01` (192.168.0.10, x86 32GB) | **권장** | 가용 메모리가 가장 크고(~13GB) Jenkins/Vault 와 동거 부담이 적다 |
| 추후 백엔드 미니PC | 권장 (이전 대상) | 백엔드 전용 서버 구성 시 함께 이전 |
| `main-server` (192.168.0.11, Pi 8GB) | 비권장 | prod DB(MySQL) + Redis node1 + dev 백엔드 동거 호스트 |
| `backend-1` (192.168.0.13, Pi 8GB) | 비권장 | dev 이전 후 여유가 생겼지만 bosspickseoul prod(9xxx) 배포 예정분으로 예약 |
| `storage` (Pi 2GB) | 불가 | nginx/minio/redis node3 로 이미 메모리 한계 |

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
docker logs -f kafka-1
docker logs -f kafka-ui
```

quorum 상태 확인 (리더/보터 확인):

```bash
docker exec -it kafka-1 /opt/bitnami/kafka/bin/kafka-metadata-quorum.sh \
  --bootstrap-server localhost:9092 describe --status
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

내부 Docker 네트워크에서 Kafka bootstrap servers:

```text
kafka-1:9092,kafka-2:9092,kafka-3:9092
```

외부 클라이언트 bootstrap servers:

```text
<host-ip-or-dns>:19092,<host-ip-or-dns>:29092,<host-ip-or-dns>:39092
```

bootstrap 은 클러스터 발견용 진입점이라 하나만 적어도 동작하지만,
그 노드가 죽어 있으면 최초 연결이 실패하므로 **3개를 모두 나열**하는 것을 권장합니다.

## 토픽 생성 예시

자동 토픽 생성은 기본값으로 꺼두었습니다. 운영 중 실수로 토픽이 생기는 걸 줄이기 위함입니다.

예시 토픽:

- `bosspick.analysis-events`
- `bosspick.analysis-ranking`
- `bosspick.search-events`
- `bosspick.recommendation-events`

생성 예시 (3노드 기준 replication factor 3):

```bash
docker exec -it kafka-1 /opt/bitnami/kafka/bin/kafka-topics.sh \
  --create \
  --topic bosspick.analysis-events \
  --partitions 3 \
  --replication-factor 3 \
  --bootstrap-server localhost:9092
```

목록/상세 확인:

```bash
docker exec -it kafka-1 /opt/bitnami/kafka/bin/kafka-topics.sh \
  --list --bootstrap-server localhost:9092

docker exec -it kafka-1 /opt/bitnami/kafka/bin/kafka-topics.sh \
  --describe --topic bosspick.analysis-events --bootstrap-server localhost:9092
```

## BossPickSeoul 백엔드 연동 예시

bootstrap servers 값은 **백엔드와 Kafka 가 같은 호스트인지**에 따라 달라집니다.

```env
# Kafka 와 같은 호스트에서 도는 컨테이너 (컨테이너명 DNS)
SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka-1:9092,kafka-2:9092,kafka-3:9092

# 다른 호스트의 백엔드 (예: main-server 의 dev 백엔드 -> ollama-01 의 Kafka)
SPRING_KAFKA_BOOTSTRAP_SERVERS=192.168.0.10:19092,192.168.0.10:29092,192.168.0.10:39092

APP_ANALYSIS_EVENTS_TOPIC=bosspick.analysis-events
APP_ANALYSIS_RANKING_TOPIC=bosspick.analysis-ranking
```

현재 토폴로지(dev 백엔드 = main-server)에서는 Kafka 를 ollama-01 에 올리는 경우
dev 백엔드의 Vault 시크릿에 외부 주소 3개를 넣어야 합니다.
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

## 문제 해결

### 1. Kafka UI 에서 브로커가 안 보임

확인:

```bash
docker logs -f kafka-ui
docker logs -f kafka-1
```

보통은 아래를 확인하면 됩니다.

- `kafka-1/2/3` 컨테이너가 healthy 인지
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

- 내부 서비스 -> `kafka-1:9092,kafka-2:9092,kafka-3:9092` 사용
- 외부 툴 -> `${KAFKA_EXTERNAL_HOST}:19092/29092/39092` 사용
- `.env` 의 host/port 와 실제 방화벽/NAT 설정 일치 여부 확인

### 4. 브로커 2대 이상이 동시에 죽음

controller quorum 과반(2/3)이 무너지면 클러스터 전체가 읽기/쓰기 불능이 됩니다.
남은 1대를 억지로 쓰려 하지 말고, 죽은 노드를 먼저 복구해 과반을 되살립니다.

```bash
docker compose --env-file .env -f docker-compose-kafka.yml up -d kafka-2 kafka-3
```

### 5. 데이터 초기화

모든 Kafka 데이터를 비우려면 컨테이너를 내리고 노드별 데이터 디렉터리를 삭제한 뒤 다시 올립니다.

```bash
docker compose --env-file .env -f docker-compose-kafka.yml down
rm -rf kafka-1-data kafka-2-data kafka-3-data
sh install-kafka.sh
```

운영 중에는 토픽 데이터가 전부 사라지므로 신중하게 사용합니다.

## 모니터링 (kafka-exporter)

compose 에 `kafka-exporter`(danielqsj/kafka-exporter)가 포함되어 있습니다.

- 지표 endpoint: `http://<host-ip>:9308/metrics` (토픽/파티션 오프셋, consumer group lag 등)
- Prometheus 는 `monitoring/prometheus/targets/kafka.yml` 로 스크레이프합니다
  (job: `kafka`, Kafka 호스트 IP 변경 시 이 파일도 수정).
- 반영: `curl -X POST http://192.168.0.14:9090/-/reload`

## 확장 로드맵

1. 브로커를 서버 3대로 분리 (호스트 장애 내성 확보)
2. controller 전용 노드 분리 (`process.roles` 분할)
3. Grafana Kafka 대시보드 추가 (exporter 지표 기반)
4. consumer group scale-out

## 권장 다음 단계

Kafka 만 띄우는 것으로 끝내지 말고, BossPickSeoul 쪽에는 아래를 이어서 붙이는 걸 권장합니다.

1. `analysis-events` 토픽 정의
2. Spring producer 공통 모듈 추가
3. ranking consumer 추가
4. Redis Sorted Set 인기순위 캐시 구성
5. 인기 자치구/행정동/상권 조회 API 추가
6. Grafana/Prometheus 로 Kafka 지표 연동
