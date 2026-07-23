# Promtail 에이전트

Promtail은 각 서버의 Docker 컨테이너 로그를 Loki로 전송하는 로그 수집 agent입니다.

## 실행 위치

로그를 보고 싶은 서버마다 Promtail을 실행합니다.

- backend 서버
- frontend 서버
- batch/worker 서버
- DB/Redis 서버는 로그까지 중앙화할 때만 선택

## 실행

```bash
cd monitoring/promtail
cp .env.agent.example .env.agent
vi .env.agent
sh install-promtail.sh
```

## 주요 환경변수

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `LOKI_PUSH_URL` | monitoring 서버 Loki push URL | `http://192.168.0.14:3100/loki/api/v1/push` |
| `PROMTAIL_HOSTNAME` | 로그가 발생한 서버명 | `backend-1` |
| `PROMTAIL_PROJECT` | Grafana/Loki에서 필터링할 프로젝트명 | `bosspickseoul` |

Promtail은 Docker Compose의 `observability.*` 라벨을 우선 사용해 `project`, `service_group`, `service`, `env`, `application`, `deployment`를 구성합니다. 라벨이 없는 기존 컨테이너는 Compose 서비스명의 `-dev`, `-prod` 접미사를 fallback으로 사용합니다.

`job`은 `<project>-<service_group>` 형식입니다. 예를 들어 auth-service 로그는 `bosspickseoul-service`, api-gateway 로그는 `bosspickseoul-cloud`입니다.

## Grafana Loki 쿼리 예시

```logql
{project="bosspickseoul", host="backend-1"}
```

```logql
{project="bosspickseoul", service="auth-service", env="dev"} |= "ERROR"
```

```logql
{project="bosspickseoul", job="bosspickseoul-cloud", env="prod"}
```
