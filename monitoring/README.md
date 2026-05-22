# Monitoring 운영 가이드

이 디렉터리는 deploy 서버에서 Grafana, Prometheus, node_exporter를 Docker Compose로 운영하기 위한 IaC 구성입니다.

deploy 서버는 Jenkins deploy agent와 함께 가벼운 모니터링 허브 역할을 담당합니다. 미니PC, 백엔드 서버, 스토리지 서버가 장애가 나도 deploy 서버가 살아 있으면 기본 상태를 확인할 수 있게 하는 구성이 목표입니다.

## 구성 요약

- `prometheus`: 메트릭 수집 및 저장
- `grafana`: 대시보드 UI
- `node-exporter`: deploy 서버 자신의 CPU, 메모리, 디스크, 네트워크 메트릭 노출

다른 서버의 메트릭은 각 서버에 node_exporter를 추가로 설치한 뒤 `prometheus/prometheus.yml`에 target을 추가합니다.

## 파일 구조

```text
monitoring/
├── docker-compose-monitoring.yml
├── install-monitoring.sh
├── .env.example
├── .gitignore
├── prometheus/
│   └── prometheus.yml
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── prometheus.yml
└── README.md
```

실행 후 생성되는 로컬 데이터:

- `prometheus-data/`: Prometheus 시계열 데이터
- `grafana-data/`: Grafana 설정, 대시보드, 플러그인 데이터

## 환경변수

```bash
cd monitoring
cp .env.example .env
```

주요 값:

| 변수 | 설명 | 기본값 |
| --- | --- | --- |
| `PROMETHEUS_PORT` | Prometheus 외부 포트 | `9090` |
| `GRAFANA_PORT` | Grafana 외부 포트 | `3001` |
| `NODE_EXPORTER_PORT` | deploy 서버 node_exporter 외부 포트 | `9100` |
| `PROMETHEUS_RETENTION_TIME` | Prometheus 데이터 보관 기간 | `15d` |
| `PROMETHEUS_RETENTION_SIZE` | Prometheus 데이터 최대 크기 | `8GB` |
| `GRAFANA_ADMIN_USER` | Grafana 관리자 계정 | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana 관리자 비밀번호 | 변경 필요 |
| `GRAFANA_DOMAIN` | Nginx에서 사용할 Grafana 도메인 | `grafana.8llow8llowme.com` |
| `GRAFANA_ROOT_URL` | Grafana 외부 접속 URL | `https://grafana.8llow8llowme.com/` |
| `TZ` | 컨테이너 타임존 | `Asia/Seoul` |

`GRAFANA_ADMIN_PASSWORD`는 운영 전 반드시 변경합니다.

## 실행

```bash
cd monitoring
sh install-monitoring.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-monitoring.yml up -d
```

상태 확인:

```bash
docker compose --env-file .env -f docker-compose-monitoring.yml ps
docker logs -f prometheus
docker logs -f grafana
```

중지:

```bash
docker compose --env-file .env -f docker-compose-monitoring.yml down
```

## 접속

deploy 서버에서 직접:

```text
http://localhost:3001
```

내부망 다른 PC에서:

```text
http://<deploy-server-ip>:3001
```

Prometheus:

```text
http://<deploy-server-ip>:9090
```

Prometheus는 외부 공개망에 직접 노출하지 않는 것을 권장합니다.

## 다른 서버 메트릭 추가

각 서버에 node_exporter를 띄운 뒤 `prometheus/prometheus.yml`의 `node` job에 target을 추가합니다.

예시:

```yaml
- targets:
    - 192.168.0.10:9100
  labels:
    instance: ollama-01
    role: ai-ci
```

설정 반영:

```bash
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload
```

reload가 실패하면 컨테이너를 재시작합니다.

```bash
docker restart prometheus
```

## node_exporter만 다른 서버에 설치하는 예시

다른 서버에서 가볍게 node_exporter만 실행할 때:

```bash
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  -p 9100:9100 \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro,rslave \
  prom/node-exporter:v1.8.2 \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --path.rootfs=/rootfs \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc|run/docker/netns)($$|/)'
```

## 운영 기준

- deploy 서버 RAM이 2GB이므로 Prometheus retention은 짧게 시작합니다.
- 처음에는 `7d` 또는 `15d`를 권장합니다.
- 장기 보관, Loki 로그 수집, Alertmanager까지 필요해지면 N100급 미니PC 같은 전용 monitoring 서버로 분리하는 것을 권장합니다.
- Grafana와 Prometheus는 공개망에 직접 노출하지 말고 VPN, 내부망, 또는 Nginx 인증 뒤에 둡니다.

## 점검 명령어

Prometheus target 상태:

```bash
curl http://localhost:9090/api/v1/targets
```

node_exporter 확인:

```bash
curl http://localhost:9100/metrics
```

디스크 사용량:

```bash
du -sh prometheus-data grafana-data
```
