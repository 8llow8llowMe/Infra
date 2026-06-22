# node_exporter 에이전트

각 서버의 호스트 CPU, RAM, DISK, 네트워크 메트릭을 Prometheus로 수집하려면 해당 서버마다 node_exporter가 실행되어야 합니다.

## 실행 위치

- backend 서버
- frontend 서버
- DB/Redis 서버
- monitoring 서버 외 추가로 관측할 모든 호스트

monitoring 서버 자신은 상위 `docker-compose-monitoring-core.yml`에 포함된 node_exporter를 사용합니다.

## 실행

```bash
cd monitoring/node-exporter
cp .env.agent.example .env.agent
vi .env.agent
sh install-node-exporter.sh
```

직접 실행하려면:

```bash
docker compose --env-file .env.agent -f docker-compose.agent.yml up -d
```

## Prometheus target 추가

node_exporter를 띄운 뒤 monitoring 서버의 `prometheus/prometheus.yml`에 target을 추가합니다.

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

## 점검

```bash
curl http://localhost:9100/metrics
```
