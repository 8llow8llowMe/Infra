# 모니터링 운영 가이드

BossPickSeoul과 홈서버 인프라를 관측하기 위한 Grafana, Prometheus, node_exporter, Loki, Promtail IaC 구성입니다.

## 서버별 역할 요약

모니터링은 중앙 서버가 모든 것을 직접 알아서 수집하는 구조가 아닙니다. 중앙 모니터링 서버에는 저장소와 대시보드가 있고, 각 애플리케이션 서버에는 메트릭/로그를 노출하거나 전달하는 에이전트가 필요합니다.

| 서버 역할 | 반드시 필요한 구성 | 선택 구성 | 설명 |
| --- | --- | --- | --- |
| monitoring 서버 | Grafana, Prometheus, node_exporter | Loki, Promtail | 메트릭 저장/조회와 대시보드 제공 |
| backend 서버 | node_exporter, Spring Actuator endpoint | Promtail | 호스트 메트릭과 백엔드 앱 메트릭 제공 |
| frontend 서버 | node_exporter | Promtail | 호스트 메트릭과 Next.js/Nginx 로그 제공 |
| DB/Redis 서버 | node_exporter | Promtail | DB/Redis 서버 리소스 관측, 로그 중앙화는 선택 |

## 구성요소 설명

### monitoring 서버에 있어야 하는 것

| 구성요소 | 필수 여부 | 역할 |
| --- | --- | --- |
| Grafana | 필수 | Prometheus/Loki 데이터를 시각화하는 대시보드 UI |
| Prometheus | 필수 | Spring Actuator와 node_exporter 메트릭을 주기적으로 scrape하고 저장 |
| node_exporter | 필수 | monitoring 서버 자신의 CPU/RAM/DISK/네트워크 메트릭 노출 |
| Loki | 선택 | 여러 서버의 Docker 로그를 중앙 저장 |
| Promtail | 선택 | monitoring 서버에서 발생한 Docker 로그를 Loki로 전송 |

### 각 애플리케이션 서버에 있어야 하는 것

| 목적 | 필요한 구성 | 이유 |
| --- | --- | --- |
| 호스트 CPU/RAM/DISK 수집 | node_exporter | Prometheus가 `서버IP:9100/metrics`를 scrape |
| Spring Boot 앱 메트릭 수집 | Actuator `/actuator/prometheus` | Prometheus가 앱 포트의 prometheus endpoint를 scrape |
| Docker 로그 수집 | Promtail | Docker 로그를 Loki push API로 전송 |

즉, **모든 서버의 CPU/RAM/DISK를 보고 싶으면 모든 서버에 node_exporter를 실행해야 합니다.**

## 권장 배치

```text
backend/frontend/db host
  node_exporter ────────────────┐
  promtail ────────────────┐    │
                             │    │
deploy monitoring server     │    │
  grafana <──────────────────┘    │
  prometheus <────────────────────┘
  loki
  node_exporter
  promtail
```

deploy 서버가 Raspberry Pi 5 2GB라면 `Grafana + Prometheus + node_exporter`를 기본으로 켜고, `Loki + Promtail`은 로그 대시보드가 필요할 때부터 켜는 것을 권장합니다.

## 파일/폴더 구조

```text
monitoring/
├── docker-compose-monitoring-core.yml
├── docker-compose-monitoring-logs.yml
├── docker-compose-host-agent.yml
├── .env.example
├── .env.host-agent.example
├── install-monitoring.sh
├── install-monitoring-logs.sh
├── prometheus/
│   └── prometheus.yml
├── grafana/
│   └── provisioning/datasources/
│       ├── prometheus.yml
│       └── loki.yml
├── loki/
│   └── loki.yml
├── node-exporter/
│   ├── docker-compose.agent.yml
│   ├── .env.agent.example
│   └── README.md
└── promtail/
    ├── docker-compose.agent.yml
    ├── .env.agent.example
    ├── promtail.yml
    └── README.md
```

## Docker Compose 파일 기준

| 파일 | 실행 위치 | 역할 |
| --- | --- | --- |
| `docker-compose-monitoring-core.yml` | monitoring 서버 | Grafana, Prometheus, monitoring 서버 node_exporter |
| `docker-compose-monitoring-logs.yml` | monitoring 서버 | Loki, monitoring 서버 Promtail |
| `docker-compose-host-agent.yml` | 애플리케이션 서버 | node_exporter + Promtail 통합 실행 |
| `node-exporter/docker-compose.agent.yml` | 애플리케이션 서버 | node_exporter만 실행 |
| `promtail/docker-compose.agent.yml` | 애플리케이션 서버 | Promtail만 실행 |

## monitoring 서버 실행 순서

### 1. 환경변수 준비

```bash
cd monitoring
cp .env.example .env
vi .env
```

최소 변경이 필요한 값:

| 변수 | 설명 |
| --- | --- |
| `GRAFANA_ADMIN_USER` | Grafana 관리자 계정 |
| `GRAFANA_ADMIN_PASSWORD` | Grafana 관리자 비밀번호 |
| `PROMETHEUS_RETENTION_TIME` | Prometheus 데이터 보관 기간 |
| `PROMETHEUS_RETENTION_SIZE` | Prometheus 데이터 최대 크기 |
| `LOKI_RETENTION_PERIOD` | Loki 로그 보관 기간 |

### 2. 기본 스택 실행

```bash
sh install-monitoring.sh
```

직접 실행하려면:

```bash
docker compose --env-file .env -f docker-compose-monitoring-core.yml up -d
```

기본 스택에 포함되는 서비스:

| 서비스 | 포트 | 설명 |
| --- | --- | --- |
| Grafana | `3001 -> 3000` | 대시보드 UI |
| Prometheus | `9090 -> 9090` | 메트릭 수집/저장 |
| node_exporter | `9100 -> 9100` | monitoring 서버 host metric |

### 3. Loki/Promtail 로그 스택 실행

로그까지 중앙화할 때만 실행합니다.

```bash
sh install-monitoring-logs.sh
```

직접 실행하려면:

```bash
docker compose --env-file .env \
  -f docker-compose-monitoring-core.yml \
  -f docker-compose-monitoring-logs.yml \
  up -d
```

로그 스택에 포함되는 서비스:

| 서비스 | 포트 | 설명 |
| --- | --- | --- |
| Loki | `3100 -> 3100` | 로그 저장소 |
| Promtail | 내부 전송 | monitoring 서버의 Docker 로그를 Loki로 전송 |

Loki/Promtail만 중지:

```bash
docker compose --env-file .env \
  -f docker-compose-monitoring-core.yml \
  -f docker-compose-monitoring-logs.yml \
  stop loki promtail
```

## 애플리케이션 서버에서 node_exporter만 실행

host CPU/RAM/DISK를 수집하려면 해당 서버에서 실행합니다.

```bash
cd monitoring/node-exporter
cp .env.agent.example .env.agent
vi .env.agent
sh install-node-exporter.sh
```

이후 monitoring 서버의 `prometheus/prometheus.yml`에 해당 서버 target을 추가합니다.

```yaml
- targets:
    - 192.168.0.11:9100
  labels:
    instance: backend-1
    role: backend
    project: bosspickseoul
```

설정 반영:

```bash
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload
```

## 애플리케이션 서버에서 Promtail만 실행

Docker 컨테이너 로그를 Loki로 보내고 싶은 서버에서 실행합니다.

```bash
cd monitoring/promtail
cp .env.agent.example .env.agent
vi .env.agent
docker compose --env-file .env.agent -f docker-compose.agent.yml up -d
```

중요 환경변수:

```env
LOKI_PUSH_URL=http://192.168.0.14:3100/loki/api/v1/push
PROMTAIL_HOSTNAME=backend-1
PROMTAIL_PROJECT=bosspickseoul
```

| 변수 | 설명 |
| --- | --- |
| `LOKI_PUSH_URL` | monitoring 서버의 Loki push API |
| `PROMTAIL_HOSTNAME` | 로그가 발생한 서버명 |
| `PROMTAIL_PROJECT` | Loki/Grafana에서 필터링할 프로젝트명 |

## 애플리케이션 서버에서 node_exporter + Promtail 같이 실행

두 agent를 한 번에 관리하고 싶으면 root의 host-agent compose를 사용합니다.

```bash
cd monitoring
cp .env.host-agent.example .env.host-agent
vi .env.host-agent
docker compose --env-file .env.host-agent -f docker-compose-host-agent.yml --profile logs up -d
```

Promtail 없이 node_exporter만 기본 실행하려면 `--profile logs`를 빼면 됩니다.

```bash
docker compose --env-file .env.host-agent -f docker-compose-host-agent.yml up -d
```

## BossPickSeoul 백엔드 메트릭 수집

백엔드 서비스는 Spring Actuator의 `/actuator/prometheus` 엔드포인트를 Prometheus가 scrape합니다.

현재 `prometheus/prometheus.yml`에는 backend-1 IP를 `192.168.0.11`로 가정해 dev 컨테이너 포트를 등록했습니다.

| 서비스 | scrape target |
| --- | --- |
| service-discovery | `192.168.0.11:6761/actuator/prometheus` |
| api-gateway | `192.168.0.11:6000/actuator/prometheus` |
| auth-service | `192.168.0.11:6081/actuator/prometheus` |
| district-service | `192.168.0.11:6082/actuator/prometheus` |
| commercial-service | `192.168.0.11:6083/actuator/prometheus` |
| ai-service | `192.168.0.11:6085/actuator/prometheus` |
| community-service | `192.168.0.11:6086/actuator/prometheus` |

## Grafana 대시보드 추천

| 대시보드 | 데이터소스 | 핵심 패널 |
| --- | --- | --- |
| BossPickSeoul Infra Overview | Prometheus | CPU, RAM, disk, network, node 상태 |
| Backend Service Metrics | Prometheus | 서비스별 up/down, JVM heap, GC, HTTP latency, error rate |
| API Gateway Overview | Prometheus | route별 요청량, 4xx/5xx, latency |
| AI Service Jobs | Prometheus | job 상태, timeout, worker queue, token usage |
| Service Logs | Loki | 서비스별 ERROR/WARN, 배포 직후 로그, 재시작 로그 |

## 운영 기준

- 모든 서버의 host metric을 보려면 모든 서버에 node_exporter를 둡니다.
- 모든 서버의 Docker 로그를 보려면 모든 서버에 Promtail을 둡니다.
- Prometheus scrape interval은 30초로 시작합니다.
- Prometheus retention은 `15d`, `8GB`로 시작하되 라즈베리파이 메모리/디스크 상태를 보고 줄입니다.
- Loki retention은 `72h`로 시작합니다.
- Grafana와 Prometheus는 공개망에 직접 노출하지 말고 Nginx 인증, VPN, 내부망으로 보호합니다.

## 빠른 점검

Prometheus target:

```bash
curl http://localhost:9090/api/v1/targets
```

node_exporter:

```bash
curl http://localhost:9100/metrics
```

Spring Actuator:

```bash
curl http://192.168.0.11:6081/actuator/prometheus
```

Loki:

```bash
curl http://localhost:3100/ready
```

디스크 사용량:

```bash
du -sh prometheus-data grafana-data loki-data promtail-data promtail/data
```
