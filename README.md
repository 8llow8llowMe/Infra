# Infra

홈서버 인프라를 IaC로 관리하는 레포입니다. 각 디렉터리가 하나의 컴포넌트이고, 컴포넌트별 상세 설정은 해당 디렉터리의 `README.md`를 따릅니다.

이 문서는 **어떤 컴포넌트를 어느 호스트에 두는가**의 정본입니다. 배치를 바꾸면 여기부터 갱신합니다.

---

## 1. 호스트 인벤토리

`2026-08-14` 실측값입니다. 메모리는 `free -h` 의 `available` 기준입니다 (버퍼/캐시 포함 가용량).

| 호스트 | IP | CPU | 총 메모리 | available | swap | 성격 |
| --- | --- | --- | --- | --- | --- | --- |
| `ollama-01` | `192.168.0.10` | x86_64 / Ryzen 7 8845HS | 30Gi | 13Gi | 8Gi | AI · 빌드 · 시크릿 · 메시징 |
| `main-server` (hostname `raspberrypi`) | `192.168.0.11` | aarch64 / Cortex-A76 | 7.8Gi | 4.7Gi | **31Gi** | dev 애플리케이션 · dev DB |
| `storage` | `192.168.0.12` | aarch64 / Cortex-A76 | **1.9Gi** | 1.1Gi | **0** | 인그레스 · 오브젝트 스토리지 |
| `backend-1` | `192.168.0.13` | aarch64 | 7.7Gi | **6.4Gi** | 2.0Gi | prod 애플리케이션 |
| `deploy` (모니터링) | `192.168.0.14` | 미실측 | 미실측 | 미실측 | 미실측 | Grafana · Prometheus |

> **아키텍처**: `ollama-01` 만 x86_64 이고 나머지 라즈베리파이 계열은 aarch64 입니다. Jenkins 빌더가 `ollama-01` 에 있으므로 **네이티브 바이너리가 포함되는 산출물은 그대로 배포하면 안 됩니다.** JAR 은 무관하지만 Node/Python 산출물은 영향을 받습니다.

---

## 2. 컴포넌트 배치 현황

| 호스트 | 올라가 있는 것 |
| --- | --- |
| `192.168.0.10` ollama-01 | ollama, open-webui, kafka-1/2/3, kafka-exporter, kafka-ui, vault, jenkins-controller, jenkins-builder-agent, searxng |
| `192.168.0.11` main-server | BossPickSeoul **dev 백엔드**, mysql, redis-node1 + sentinel1, backend-dev-agent |
| `192.168.0.12` storage | nginx, certbot, fail2ban, logrotate, minio, redis-node3 + sentinel3, web-ssr(tripmarble) |
| `192.168.0.13` backend-1 | TripMarble **prod 백엔드 5종**, redis-node2 + sentinel2 |
| `192.168.0.14` deploy | grafana, prometheus, node-exporter |

Redis 는 3노드 센티널이라 `.11` / `.13` / `.12` 에 한 대씩 나눠 두고 quorum 2 로 운영합니다. Kafka 는 3브로커지만 노드당 1GB 라 나눌 여유가 있는 호스트가 없어 `ollama-01` 단일 호스트에 묶여 있습니다.

---

## 3. BossPickSeoul 운영 백엔드는 어디에 두는가

### 결론 — `backend-1` (`192.168.0.13`)

8종(`api-gateway`, `service-discovery`, `auth`, `commercial`, `district`, `community`, `ai`, `batch`)을 전부 `192.168.0.13` 에 둡니다. 운영 프론트도 같은 호스트입니다.

이미 이 전제로 배선되어 있습니다.

- `nginx/conf.d/api.bosspickseoul.conf` 가 `192.168.0.13:9000`(게이트웨이), `192.168.0.13:9081`(auth) 을 봅니다
- 백엔드 파이프라인의 `deployAgentLabels.prod` 가 `deploy-backend-prod` 입니다
- Prometheus `targets/nodes.yml` 에 `backend-1` 이 `role: backend` 로 등록되어 있습니다

### 근거

**1) prod 는 dev 와 물리적으로 분리해야 합니다.**
dev 백엔드가 `.11` 에 있습니다. prod 를 같은 호스트에 올리면 dev 배포 한 번의 OOM 이 운영을 죽입니다. `.11` 은 이 이유만으로 탈락입니다.

**2) 실여유 메모리가 가장 큽니다.**
`.13` 은 available 6.4Gi 로 4개 호스트 중 최대입니다. 들어갈 양을 실측 기반으로 계산하면 이렇습니다.

`.11` 에서 dev 백엔드 + MySQL + Redis 2종 + Jenkins agent 가 총 3.0Gi 를 씁니다. MySQL(~400MB) · Redis(~100MB) · agent(~150MB) 를 빼면 **서비스당 약 335MB** 입니다. compose 의 `768m` 은 limit 이지 예약이 아닙니다.

| 항목 | 예상 |
| --- | --- |
| 현재 사용 (tripmarble prod 5종 + redis) | 1.4Gi (실측) |
| BossPickSeoul prod 백엔드 8종 | ~3.0Gi (추정, 335MB × 8 + 부하 여유) |
| BossPickSeoul prod 프론트 1종 | ~0.35Gi (추정) |
| **합계** | **~4.8Gi / 7.7Gi** |

여유 약 2.7Gi 가 남습니다. 빠듯하지 않습니다.

**3) 서비스 간 호출이 호스트 안에서 끝납니다.**
nginx 가 `.12` 에 있어 외부 진입은 어차피 1홉이지만, 게이트웨이-서비스 간 내부 호출과 Eureka 등록은 전부 같은 호스트 안에서 처리됩니다. 8종을 여러 호스트로 흩으면 서비스 간 호출마다 LAN 을 탑니다.

### 검토했다가 뺀 선택지

| 후보 | 뺀 이유 |
| --- | --- |
| `storage` (`.12`) | 총 1.9Gi / **swap 0** 에 nginx·MinIO·redis-node3 가 함께 있습니다. OOM killer 가 발동하면 nginx 가 죽고 **전 도메인이 같이 내려갑니다.** 여기 남은 여유는 "쓸 수 있는 여유"가 아니라 인그레스가 살아 있기 위한 여유입니다. |
| `main-server` (`.11`) | dev 백엔드가 이미 있습니다. dev 사고가 prod 로 번집니다. |
| `ollama-01` (`.10`) | available 13Gi 로 가장 넉넉하지만, ollama 가 모델 로드에 따라 메모리를 탄력적으로 먹습니다(현재 17Gi 사용). 여기에 Vault·Jenkins 컨트롤러·Kafka 3브로커까지 있어 이미 빌드·시크릿·메시징의 단일 장애점입니다. 운영 앱 계층까지 얹으면 이 호스트 하나가 죽을 때 복구 수단까지 함께 잃습니다. |
| `.13` + `.10` 분산 (ai-service 만 ollama 옆으로) | 메모리는 ~450MB 벌지만 prod 배포 대상이 둘로 늘고 장애 도메인이 쪼개집니다. LLM 호출은 응답이 수 초 단위라 LAN 1홉이 유의미하지 않습니다. **`.13` 이 빠듯해지면 그때 꺼낼 카드**로 남겨둡니다. |

### 배포 전 필요한 것

1. **`backend-prod-agent` 기동** — `.13` 에 Jenkins 배포 에이전트가 없습니다(`docker ps` 확인). 이게 없으면 prod 파이프라인이 실행 자체를 못 합니다. `jenkins/docker-compose-jenkins-deploy-agent.yml` 로 띄우고 라벨 `deploy-backend-prod` 를 붙입니다.
2. **Vault `kv/bosspickseoul/backend/prod/env` 에 `SPRING_PROFILES_ACTIVE=prod`** — 이 값이 `dev` 로 남아 있으면 운영이 dev 프로파일로 떠서 `ddl-auto: update` 로 배포 때마다 운영 스키마가 자동 변경됩니다.
3. **`.13` swap 확대 검토** — 현재 prod 호스트가 2.0Gi, dev 호스트가 31Gi 입니다. 뒤집혀 있습니다. prod 쪽을 늘리는 편이 맞습니다.

### 향후 이전

백엔드 전용 서버(미니 PC)를 도입하면 prod 백엔드 8종을 통째로 옮깁니다. 그때 손봐야 할 곳은 아래 세 군데뿐입니다.

- `nginx/conf.d/api.bosspickseoul.conf` 의 `upstream` 2줄
- Jenkins `backend-prod-agent` 를 새 호스트로 이동 (라벨은 그대로)
- `monitoring/prometheus/targets/` 의 대상 IP

---

## 4. 배치 원칙

새 컴포넌트를 어디 둘지 정할 때 적용하는 규칙입니다.

1. **`storage`(`.12`) 에는 더 얹지 않습니다.** 총 1.9Gi / swap 0 이고 전 도메인의 단일 인그레스입니다. 여기서 나는 OOM 은 그 컴포넌트만의 문제로 끝나지 않습니다.
2. **dev 와 prod 는 호스트를 공유하지 않습니다.** dev 는 `.11`, prod 는 `.13`.
3. **`ollama-01`(`.10`) 은 인프라 계층 전용입니다.** 빌드·시크릿·메시징·AI. 사용자 트래픽을 받는 애플리케이션은 두지 않습니다.
4. **호스트 간 통신은 컨테이너명이 아니라 사설 IP** 를 씁니다. `8llow8llowme-net` 은 호스트별 브리지라 다른 호스트의 컨테이너명이 해석되지 않습니다. 과거 `web-ssr:3000` 으로 프록시했다가 같은 호스트의 tripmarble 컨테이너가 BossPickSeoul 요청에 응답한 사고가 있었습니다.
5. **포트 대역을 지킵니다.** dev `6xxx`, BossPickSeoul prod `9xxx`, TripMarble prod `8xxx`, 인프라 도구는 `1xxxx~5xxxx`.
6. **네이티브 바이너리가 섞이는 산출물은 빌더에서 그대로 내보내지 않습니다.** 빌더는 x86_64, 배포 대상은 aarch64 입니다.

---

## 5. BossPickSeoul 배치 요약

| 대상 | 환경 | 호스트 | 호스트 포트 | 도메인 |
| --- | --- | --- | --- | --- |
| 백엔드 게이트웨이 | dev | `192.168.0.11` | 6000 | `api-dev.bosspickseoul.com` |
| 백엔드 게이트웨이 | prod | `192.168.0.13` | 9000 | `api.bosspickseoul.com` |
| 백엔드 auth (단독) | dev | `192.168.0.11` | 6081 | `api-dev.bosspickseoul.com` |
| 백엔드 auth (단독) | prod | `192.168.0.13` | 9081 | `api.bosspickseoul.com` |
| 프론트 웹 | dev | `192.168.0.11` | 6300 | `dev.bosspickseoul.com` |
| 프론트 웹 | prod | `192.168.0.13` | 9300 | `www.bosspickseoul.com` |

프론트 배포 절차는 애플리케이션 레포의 `frontend/docs/runbook/deployment.md` 를 참고합니다.

---

## 6. 컴포넌트 문서

| 디렉터리 | 내용 |
| --- | --- |
| `nginx/` | 리버스 프록시, 도메인 라우팅 |
| `certbot/` | Let's Encrypt 인증서 발급/갱신 |
| `jenkins/` | controller, builder agent, deploy agent |
| `vault/` | 시크릿 관리 (KV v2, AppRole) |
| `kafka/` | KRaft 3브로커 + kafka-ui + exporter |
| `redis/` | 3노드 센티널 |
| `MySQL/` | dev DB |
| `MinIO/` | 오브젝트 스토리지 |
| `monitoring/` | Grafana, Prometheus, node-exporter |
| `ollama/` | LLM 추론 + open-webui |
| `elasticsearch/`, `filebeat/` | 로그 수집 |
| `fail2ban/`, `logrotate/` | 보안·로그 관리 |
| `searxng/` | 메타 검색 |
| `docker/` | Docker Engine 설치 스크립트 (arch 자동 분기) |
