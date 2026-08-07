# Promtail 에이전트

Promtail은 각 서버의 Docker 컨테이너 로그를 Loki로 전송하는 로그 수집 agent입니다.

## 왜 로그는 서버마다 agent가 필요한가

Grafana 서버와 애플리케이션 서버가 분리되어 있을 때 가장 자주 나오는 질문입니다. 메트릭과 로그는 데이터가 흐르는 **방향이 반대**입니다.

| 대상 | 방향 | agent 필요 여부 |
| --- | --- | --- |
| Loki (로그) | **push** — agent가 Loki로 밀어넣음 | **필요.** Loki는 원격 서버의 로그 파일을 스스로 읽어올 수 없음 |
| Prometheus (메트릭) | **pull** — Prometheus가 `/actuator/prometheus`를 scrape | 불필요. monitoring 서버에서 앱 포트로 도달만 되면 됨 |

즉 **백엔드 서버의 로그를 Grafana에서 보려면 그 백엔드 서버에 Promtail을 띄워야 합니다.** 백엔드 앱 메트릭은 Prometheus가 가져가므로 agent가 필요 없고, 호스트 CPU/RAM/DISK만 `node_exporter`가 추가로 필요합니다(이것도 pull).

```text
backend 서버                          monitoring 서버
  컨테이너 stdout
    └─ promtail ──── push ──────────▶ loki ────┐
  /actuator/prometheus ◀── pull ──── prometheus┤
  node_exporter:9100   ◀── pull ─────────────  │
                                      grafana ◀┘
```

## 실행 위치

로그를 보고 싶은 서버마다 Promtail을 실행합니다.

- backend 서버
- frontend 서버
- batch/worker 서버
- DB/Redis 서버는 로그까지 중앙화할 때만 선택

monitoring 서버 자신의 로그를 수집하는 Promtail은 `docker-compose-promtail.yml`(로그 스택에 포함)이고, 애플리케이션 서버용은 `docker-compose-agent.yml`입니다. 두 파일을 섞어 쓰지 않습니다.

## 실행

```bash
# 백엔드 서버에서
cd monitoring/promtail
cp .env.agent.example .env.agent
vi .env.agent
sh install-promtail.sh
```

채울 값은 3개입니다.

```env
LOKI_PUSH_URL=http://<모니터링서버IP>:3100/loki/api/v1/push
PROMTAIL_HOSTNAME=backend-1
PROMTAIL_PROJECT=bosspickseoul
```

## 주요 환경변수

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `LOKI_PUSH_URL` | monitoring 서버 Loki push URL | `http://192.168.0.14:3100/loki/api/v1/push` |
| `PROMTAIL_HOSTNAME` | 로그가 발생한 서버명. 서버마다 다른 값을 넣어야 구분됨 | `backend-1`, `main-server` |
| `PROMTAIL_PROJECT` | Grafana/Loki에서 필터링할 프로젝트명 | `bosspickseoul` |

## 서버가 분리되어 있을 때 선행 조건

1. **3100 포트 도달성** — 백엔드 서버에서 monitoring 서버 3100으로 나가는 통신이 열려 있어야 합니다. 방화벽/보안그룹을 확인합니다.

   ```bash
   # 백엔드 서버에서 실행
   curl http://<모니터링서버IP>:3100/ready
   ```

2. **Loki를 공개망에 노출하지 않습니다** — Loki push API에는 인증이 없습니다. 사설망 통신으로 두거나, 불가피하면 Nginx에서 basic auth + HTTPS로 감쌉니다. `.env.agent.example`이 사설 IP를 쓰는 이유입니다.

3. **시간 동기화** — 두 서버의 시각이 어긋나면 Loki가 로그를 미래/과거로 저장해 Grafana 시간 범위에서 사라집니다. 두 서버 모두 NTP와 `TZ=Asia/Seoul`을 맞춥니다.

## 라벨 구성 방식

Promtail은 Docker socket을 읽어 컨테이너를 자동 탐색합니다(`docker_sd_configs`, 10초 주기). 따라서 서비스를 새로 띄워도 설정을 고칠 필요가 없습니다.

라벨은 Docker Compose의 `observability.*` 라벨을 **우선** 사용합니다.

| Loki 라벨 | 출처 | fallback |
| --- | --- | --- |
| `project` | `observability.project` | `.env.agent`의 `PROMTAIL_PROJECT` |
| `service_group` | `observability.group` | Compose 서비스명 기준. `service-discovery`/`api-gateway`는 `cloud`, 그 외는 `service` |
| `service` | `observability.service` | Compose 서비스명에서 `-dev`/`-prod` 접미사를 제거한 값 |
| `env` | `observability.env` | Compose 서비스명의 `-dev`/`-prod` 접미사 |
| `application` | `observability.application` | `service` 값 |
| `deployment` | `observability.deployment` | 컨테이너명 |
| `host` | — | `.env.agent`의 `PROMTAIL_HOSTNAME` |
| `container` | 컨테이너명 | — |
| `compose_project` | Compose 프로젝트명 | — |
| `compose_service` | Compose 서비스명(접미사 포함) | — |
| `job` | `<project>-<service_group>` 조합 | — |

`job`이 `<project>-<service_group>`이므로 auth-service 로그는 `bosspickseoul-service`, api-gateway 로그는 `bosspickseoul-cloud`입니다. Prometheus의 job 이름과 같은 규칙이라 대시보드에서 메트릭과 로그를 같은 변수로 묶을 수 있습니다.

## Grafana Loki 쿼리 예시

특정 서버의 전체 로그:

```logql
{project="bosspickseoul", host="backend-1"}
```

특정 서비스의 dev 환경 ERROR만:

```logql
{project="bosspickseoul", service="auth-service", env="dev"} |= "ERROR"
```

cloud 그룹(service-discovery, api-gateway) prod 로그:

```logql
{project="bosspickseoul", job="bosspickseoul-cloud", env="prod"}
```

## 로그가 Grafana에 보이지 않을 때

순서대로 확인합니다.

1. **Promtail이 살아 있는지**

   ```bash
   docker logs promtail --tail 50
   ```

   `connection refused`나 `context deadline exceeded`가 보이면 `LOKI_PUSH_URL` 또는 방화벽 문제입니다.

2. **Promtail이 컨테이너를 찾았는지** — 기동 로그에 탐색한 대상이 남습니다.

   ```bash
   docker logs promtail 2>&1 | grep -i "target"
   ```

   Promtail 자체 메트릭(`:9080/metrics`)은 compose에서 포트를 공개하지 않으므로 호스트에서 바로 `curl` 할 수 없습니다. 필요하면 `docker-compose-agent.yml`에 아래를 임시로 추가하고 재기동합니다.

   ```yaml
   ports:
     - '9080:9080'
   ```

3. **Loki에 라벨이 도착했는지** — monitoring 서버에서 확인합니다. 값 목록에 해당 서비스가 없으면 아직 로그가 도착하지 않은 것입니다.

   ```bash
   curl -s "http://localhost:3100/loki/api/v1/label/service/values"
   curl -s "http://localhost:3100/loki/api/v1/label/host/values"
   ```

4. **컨테이너가 실제로 로그를 출력하는지** — 요청이 없는 API 서비스는 로그가 없을 수 있습니다. Prometheus `up=1`(프로세스 살아 있음)과 로그 존재는 다른 사실입니다. 자세한 진단은 `../grafana/README.md`를 참고합니다.

## Promtail 지원 종료 관련

**Promtail은 2026년 2월 28일로 지원이 종료되었습니다.** 현재 구성은 정상 동작하지만 보안 패치가 더 나오지 않습니다. Grafana의 후속 에이전트는 **Grafana Alloy**이며 기존 설정을 변환하는 도구를 제공합니다.

```bash
alloy convert --source-format=promtail --output=config.alloy promtail.yml
```

Alloy로 옮길 때도 위 라벨 계약(`project`/`service_group`/`service`/`env`, `job=<project>-<service_group>`)을 유지하면 대시보드 쿼리를 그대로 쓸 수 있습니다.
