# Kafka 운영 가이드

이 디렉터리는 BossPickSeoul 인프라에 **Kafka 3노드 클러스터(KRaft) + Kafka UI** 를 Docker Compose 로 추가하기 위한 구성입니다.

현재 Infra 레포 패턴에 맞춰 `docker-compose-*.yml`, `.env.example`, `install-*.sh`, `README.md` 구조를 그대로 따릅니다.

## 구성 요약

- 브로커: `apache/kafka:4.3.1` × 3 (`kafka-1`, `kafka-2`, `kafka-3`)
- 모드: **KRaft combined** — 각 노드가 `broker,controller` 동시 역할
- controller quorum: `1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093`
- 복제: replication factor `3`, min ISR `2` (브로커 1대 장애까지 읽기/쓰기 지속)
- UI: `ghcr.io/kafbat/kafka-ui:v1.5.0` (provectuslabs/kafka-ui 는 개발 중단 — 유지보수 포크로 교체)
- UI 인증: 로그인 폼(`AUTH_TYPE=LOGIN_FORM`) 필수 — `.env` 의 계정/비밀번호를 사용
- 내부 접속 주소: `kafka-1:9092,kafka-2:9092,kafka-3:9092` (같은 호스트의 `8llow8llowme-net` 컨테이너 전용)
- 외부 접속 주소: `${KAFKA_EXTERNAL_HOST}:19092/29092/39092` (다른 서버의 클라이언트용)
- Docker 네트워크: `8llow8llowme-net`

공통 환경변수는 compose 상단의 `x-kafka-common-environment` 앵커 한 곳에서 관리하고,
노드별로 다른 값(`KAFKA_NODE_ID`, `KAFKA_ADVERTISED_LISTENERS`)만 각 서비스에서 덮어씁니다.
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

## 공식 이미지 이전 (bitnami → apache/kafka)

`bitnami/kafka` 공개 카탈로그는 2025년부터 갱신이 동결되어 보안 패치가 나오지 않습니다. 그래서 공식 `apache/kafka` 이미지로 이전했습니다. 이전 `.env` 를 그대로 쓰면 기동에 실패하므로 아래 차이를 확인해야 합니다.

### 무엇이 달라졌나

| 항목 | bitnami (이전) | apache/kafka (현재) |
| --- | --- | --- |
| 이미지 | `bitnami/kafka:3.9.0` | `apache/kafka:4.3.1` |
| 설정 환경변수 접두어 | `KAFKA_CFG_*` | `KAFKA_*` |
| 클러스터 ID 변수 | `KAFKA_KRAFT_CLUSTER_ID` | `CLUSTER_ID` (`.env` 는 `KAFKA_CLUSTER_ID`) |
| KRaft 활성화 플래그 | `KAFKA_ENABLE_KRAFT=yes` | 없음 (4.x 는 KRaft 전용) |
| PLAINTEXT 허용 플래그 | `ALLOW_PLAINTEXT_LISTENER=yes` | 없음 (bitnami 전용이었음) |
| 바이너리 경로 | `/opt/bitnami/kafka/bin` | `/opt/kafka/bin` |
| 데이터 경로 | `/bitnami/kafka` | `/var/lib/kafka/data` (`KAFKA_LOG_DIRS` 로 명시) |
| 실행 사용자 | root 계열 | UID/GID **1000** (`appuser`) |

환경변수 이름 규칙은 `server.properties` 키를 그대로 변환합니다. 점(`.`)은 밑줄, 밑줄은 밑줄 2개, 하이픈은 밑줄 3개로 바꾸고 `KAFKA_` 를 붙입니다. 예를 들어 `num.partitions` 는 `KAFKA_NUM_PARTITIONS` 입니다.

### 이전 시 반드시 확인할 2가지

**1. 데이터는 이어지지 않습니다.** 데이터 경로가 `/bitnami/kafka` → `/var/lib/kafka/data` 로 바뀌었고 내부 레이아웃도 다릅니다. 기존 클러스터의 토픽 데이터를 유지해야 한다면 이전이 아니라 새 클러스터 구축 + 재적재로 접근해야 합니다. 아직 운영 데이터가 없다면 데이터 디렉터리를 비우고 새로 올리는 것이 가장 간단합니다.

```bash
docker compose --env-file .env -f docker-compose-kafka.yml down
rm -rf kafka-1-data kafka-2-data kafka-3-data
sh install-kafka.sh
```

**2. 데이터 디렉터리 소유자가 1000:1000 이어야 합니다.** 공식 이미지는 비루트(`appuser`, UID 1000)로 실행되므로 root 소유 디렉터리에는 로그를 쓸 수 없어 기동 직후 죽습니다. `install-kafka.sh` 가 자동으로 `chown` 을 시도하고, 권한이 없으면 안내를 출력합니다.

```bash
sudo chown -R 1000:1000 kafka-1-data kafka-2-data kafka-3-data
```

### 함께 개선한 설정

- `min.insync.replicas=2` 를 명시했습니다(`KAFKA_MIN_INSYNC_REPLICAS`). 기존 구성은 트랜잭션 로그의 min ISR 만 지정하고 일반 토픽은 지정하지 않아, Kafka 기본값 `1` 이 적용되고 있었습니다. 그러면 RF=3 이어도 복제본 1개만 살아 있을 때 `acks=all` 쓰기가 성공해 그 노드가 죽으면 유실됩니다.
- `KAFKA_LOG_DIRS` 를 명시했습니다. 공식 이미지 기본값은 `/tmp` 아래라 명시하지 않으면 컨테이너 재생성 시 데이터가 사라집니다.
- Kafka UI 를 `v1.5.0` 으로 올렸습니다.

### 왜 controller quorum 은 아직 정적(static)인가

Kafka 4.1 부터 KRaft version 1 이 `controller.quorum.voters`(정적)를 **deprecated** 로 표시하고 `controller.quorum.bootstrap.servers`(동적, KIP-853)를 권장합니다. 동적 quorum 은 컨트롤러를 재시작 없이 추가/제거할 수 있는 장점이 있습니다.

그런데 동적 quorum 으로 클러스터를 만들려면 스토리지 포맷 시 `--initial-controllers "id@host:port:directoryUuid,..."` 또는 `--standalone` 을 넘겨야 합니다. **공식 이미지의 자동 포맷은 `--cluster-id` 와 `--ignore-formatted` 만 사용해 이 옵션을 지원하지 않습니다.** `docker compose up` 한 번으로 기동되는 지금 구조를 유지하려면 정적 voters 가 맞습니다.

정적 voters 는 deprecated 이지만 여전히 동작하며, 3노드 고정 구성에서는 실질적 손해가 없습니다. 브로커를 서버 3대로 분리하거나 컨트롤러를 무중단으로 늘려야 할 때 아래 순서로 전환합니다.

1. 컨트롤러 1대를 `kafka-storage.sh format --standalone` 으로 포맷해 단독 기동
2. 나머지 컨트롤러는 `--no-initial-controllers` 로 포맷 후 기동
3. `kafka-metadata-quorum.sh add-controller` 로 quorum 에 편입
4. 전체 노드 설정을 `controller.quorum.bootstrap.servers` 로 교체

이 절차는 compose 자동 기동으로는 표현할 수 없어, 초기화 스크립트를 분리하는 별도 작업이 필요합니다.

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

`.env.example` 의 `KAFKA_CLUSTER_ID` 는 **비어 있습니다.** 직접 채우지 않아도 되고, `install-kafka.sh` 가 최초 실행 때 임의값을 생성해 `.env` 에 기록합니다. 예시값을 그대로 쓰지 않는 이유는, 서로 다른 클러스터가 같은 ID 를 가지면 툴에서 구분이 안 되고 실수로 섞였을 때 알아채기 어렵기 때문입니다.

```text
KAFKA_CLUSTER_ID 가 비어 있어 새로 생성합니다.
생성한 KAFKA_CLUSTER_ID: R_NkW4-V6CaCQb3kZYsoWg
.env 에 기록했습니다. 이 값은 최초 포맷 때 디스크에 새겨지므로 이후 바꾸지 마세요.
```

생성 방식은 2단계입니다.

1. `docker run --rm $KAFKA_IMAGE /opt/kafka/bin/kafka-storage.sh random-uuid` — Kafka 공식 도구라 형식이 보장됩니다
2. docker 실행이 안 되면 `openssl rand 16` 을 패딩 없는 base64url 로 변환합니다 (Kafka `Uuid` 와 같은 표기: 22자, 16바이트)

두 방법 모두 실패하면 직접 넣으라는 안내와 함께 종료합니다.

### 클러스터 ID 관련 주의

- **한 번 기동한 뒤에는 바꾸지 않습니다.** 이 값은 최초 스토리지 포맷 때 각 노드의 `meta.properties` 에 새겨집니다. 나중에 바꾸면 브로커가 ID 불일치로 기동에 실패합니다.
- 이미 포맷된 클러스터의 ID 를 잊었다면 디스크에서 확인합니다.

  ```bash
  grep cluster.id kafka-1-data/meta.properties
  ```

- 데이터가 이미 있는데 `.env` 의 ID 가 비어 있으면 스크립트가 **생성하지 않고 중단**합니다. 새 ID 를 만들면 디스크에 새겨진 ID 와 달라져 기동할 수 없기 때문입니다. 위 명령으로 확인해 `.env` 에 넣거나, 데이터를 버려도 되면 데이터 디렉터리를 삭제한 뒤 다시 실행합니다.

운영 전에 특히 아래 값은 확인합니다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `KAFKA_IMAGE` | Kafka 이미지 | `apache/kafka:4.3.1` |
| `KAFKA_CLUSTER_ID` | KRaft 클러스터 ID (3노드 공통) | **비워둠 — 자동 생성** |
| `KAFKA_1/2/3_EXTERNAL_PORT` | 노드별 외부 advertised listener 포트 | `19092` / `29092` / `39092` |
| `KAFKA_EXTERNAL_HOST` | 외부 클라이언트가 바라볼 호스트 IP 또는 DNS | `192.168.0.10` |
| `KAFKA_1/2/3_DATA_DIR` | 노드별 호스트 데이터 경로 | `./kafka-1-data` 등 |
| `KAFKA_HEAP_OPTS` | 노드당 JVM heap 설정 | `-Xms512m -Xmx512m` |
| `KAFKA_MEM_LIMIT` | 노드당 컨테이너 메모리 상한 | `1g` |
| `KAFKA_UI_MEM_LIMIT` | Kafka UI 컨테이너 메모리 상한 | `512m` |
| `KAFKA_NUM_PARTITIONS` | 기본 파티션 수 | `3` |
| `KAFKA_DEFAULT_REPLICATION_FACTOR` | 기본 복제 계수 (3노드 기준 3) | `3` |
| `KAFKA_MIN_INSYNC_REPLICAS` | acks=all 쓰기에 필요한 최소 복제본 (3노드 기준 2) | `2` |
| `KAFKA_TRANSACTION_STATE_LOG_MIN_ISR` | 트랜잭션 로그 최소 ISR (3노드 기준 2) | `2` |
| `KAFKA_AUTO_CREATE_TOPICS_ENABLE` | 토픽 자동 생성 허용 여부 | `false` |
| `KAFKA_UI_IMAGE` | Kafka UI 이미지 | `ghcr.io/kafbat/kafka-ui:v1.5.0` |
| `KAFKA_UI_PORT` | Kafka UI 외부 포트 | `18080` |
| `KAFKA_UI_AUTH_USERNAME` | Kafka UI 로그인 계정 | `admin` |
| `KAFKA_UI_AUTH_PASSWORD` | Kafka UI 로그인 비밀번호 (**필수**) | 직접 지정 |
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

Kafka UI(18080)에는 로그인 폼 인증(`AUTH_TYPE=LOGIN_FORM`)이 걸려 있습니다. `.env` 의
`KAFKA_UI_AUTH_USERNAME` / `KAFKA_UI_AUTH_PASSWORD` 가 비어 있으면 `install-kafka.sh` 가 기동을 막고, compose 도 `${VAR:?}` 문법으로 같은 검사를 하므로 `docker compose up` 을 직접 실행해도 빈 계정으로 뜨지 않습니다.
인증은 애플리케이션 계층이라 nginx 를 우회해 호스트 포트로 직접 붙어도 적용됩니다.
kafbat UI 의 로그인 폼 인증은 로컬 사용자 1명만 지원하므로, 계정을 여러 개 두려면 OAuth/LDAP 연동이 필요합니다.
도메인 노출은 `nginx/conf.d/kafka-ui.conf` 를 참고하세요.

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
docker exec -it kafka-1 /opt/kafka/bin/kafka-metadata-quorum.sh \
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
docker exec -it kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --create \
  --topic bosspick.analysis-events \
  --partitions 3 \
  --replication-factor 3 \
  --bootstrap-server localhost:9092
```

목록/상세 확인:

```bash
docker exec -it kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --list --bootstrap-server localhost:9092

docker exec -it kafka-1 /opt/kafka/bin/kafka-topics.sh \
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
- `KAFKA_ADVERTISED_LISTENERS` 의 외부 호스트 값이 잘못되지 않았는지

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
