# Redis 운영 가이드

Redis master 1 + replica 2 + Sentinel 3노드 구성입니다.

## 실제 배치 토폴로지

| 노드 | 서버 | compose 파일 |
| --- | --- | --- |
| `redis-node1` + `redis-sentinel-node1` (master) | main-server (192.168.0.11) | `docker-compose-redis-master.yml` |
| `redis-node2` + `redis-sentinel-node2` (replica) | backend-1 (192.168.0.13) | `docker-compose-redis-slave.yml` |
| `redis-node3` + `redis-sentinel-node3` (replica) | storage | `docker-compose-redis-slave2.yml` |

- Sentinel quorum 은 `2` (`sentinel.conf`) — 3노드 중 2노드 합의로 failover 가 성립합니다.
- master/replica 주소는 `redis-slave.conf` 의 `replicaof` 와 `sentinel.conf` 의 `sentinel monitor` 가 기준입니다.
  **서버 IP 를 바꾸면 이 두 파일을 함께 수정해야 합니다.**

## 파일 구조

```text
redis/
├── docker-compose-redis-master.yml   # node1 + sentinel1 (master 호스트)
├── docker-compose-redis-slave.yml    # node2 + sentinel2
├── docker-compose-redis-slave2.yml   # node3 + sentinel3
├── redis.Dockerfile
├── redis-master.conf / redis-slave.conf / sentinel.conf
├── docker-entrypoint-redis.sh / docker-entrypoint-sentinel.sh
├── .env.example                      # 비밀번호 템플릿 (.env 는 커밋 금지)
└── .gitignore
```

## 실행

각 서버에서 자기 역할의 compose 만 실행합니다.

```bash
cd redis
cp .env.example .env   # REDIS_MASTER_PASSWORD 실제 값 입력
docker compose -f docker-compose-redis-master.yml up -d --build   # master 호스트
docker compose -f docker-compose-redis-slave.yml up -d --build    # replica 호스트 (backend-1)
docker compose -f docker-compose-redis-slave2.yml up -d --build   # replica 호스트 (storage)
```

## 상태 확인

```bash
# 복제 상태 (master 에서)
docker exec -it redis-node1 redis-cli -a "$REDIS_MASTER_PASSWORD" info replication

# Sentinel 이 보는 master
docker exec -it redis-sentinel-node1 redis-cli -p 26379 sentinel get-master-addr-by-name master-redis
```

## 비밀번호 관리 주의

- `.env` 는 커밋하지 않습니다 (`.gitignore` 처리됨).
- 과거에 `.env` 가 저장소에 커밋된 이력이 있으므로, **비밀번호를 교체(rotate)하는 것을 권장**합니다.
  git 이력에서 완전히 지우려면 history rewrite 가 필요하지만, 사설망 전용이므로 교체가 현실적입니다.
