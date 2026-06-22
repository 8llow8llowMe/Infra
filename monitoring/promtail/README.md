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
docker compose --env-file .env.agent -f docker-compose.agent.yml up -d
```

## 주요 환경변수

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `LOKI_PUSH_URL` | monitoring 서버 Loki push URL | `http://192.168.0.14:3100/loki/api/v1/push` |
| `PROMTAIL_HOSTNAME` | 로그가 발생한 서버명 | `backend-1` |
| `PROMTAIL_PROJECT` | Grafana/Loki에서 필터링할 프로젝트명 | `bosspickseoul` |

## Grafana Loki 쿼리 예시

```logql
{project="bosspickseoul", host="backend-1"}
```

```logql
{project="bosspickseoul", container=~".*auth-service.*"} |= "ERROR"
```
