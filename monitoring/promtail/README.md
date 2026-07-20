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

Promtail은 Docker Compose 서비스명이 `auth-service-dev`, `api-gateway-prod`처럼 끝나는 컨테이너에 대해 `service`, `env` 라벨을 자동으로 붙입니다. 그래서 Grafana Loki에서 BosspickSeoul 로그를 메트릭 라벨과 비슷한 축으로 바로 조회할 수 있습니다.

## Grafana Loki 쿼리 예시

```logql
{project="bosspickseoul", host="backend-1"}
```

```logql
{project="bosspickseoul", service="auth-service", env="dev"} |= "ERROR"
```
