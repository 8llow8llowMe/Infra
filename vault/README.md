# Vault 운영 가이드

이 디렉터리는 미니PC `ai-host`에서 HashiCorp Vault를 Docker 컨테이너로 운영하기 위한 IaC 구성입니다.

Vault는 BossPickSeoul 배포 시크릿의 원본 저장소입니다. Jenkins controller는 Vault에서 서비스별 `.env` 계약을 읽고, `backend-1` deploy agent는 배포 실행 책임만 갖도록 구성합니다. 실제 secret 값은 Git에 커밋하지 않습니다.

## 컨테이너로 운영해도 되나?

현재 규모에서는 Docker Compose로 운영하는 것을 권장합니다.

- 미니PC에 Vault, Jenkins, 관제를 함께 올리는 구조와 잘 맞습니다.
- 파일 스토리지 단일 노드 운영이 단순하고 백업 경로가 명확합니다.
- Jenkins와 같은 Docker 네트워크를 공유할 수 있어 내부 연동이 쉽습니다.
- 나중에 고가용성이 필요해지면 Raft storage 또는 별도 Vault 노드로 분리할 수 있습니다.

주의할 점은 있습니다. 운영 Vault는 dev 모드로 띄우면 안 되고, `vault.hcl` 기반 server 모드로 실행해야 합니다. 외부 공개망에 직접 노출하지 말고 사설망 또는 TLS reverse proxy 뒤에 두는 편이 안전합니다.

## 파일 구조

```text
vault/
├── docker-compose-vault.yml
├── vault.hcl
├── docker-entrypoint-vault.sh
├── .env.example
├── policies/
│   ├── jenkins-bosspickseoul.hcl
│   └── backend-bosspickseoul.hcl
├── scripts/
│   └── bootstrap-bosspickseoul.sh
└── README.md
```

실행 후 생성되는 로컬 데이터:

- `data/`: Vault file storage 데이터
- `logs/`: Vault 로그 디렉터리

## 환경변수

```bash
cd vault
cp .env.example .env
```

미니PC 사설 IP 또는 내부 DNS 이름으로 주소를 바꿉니다.

```env
VAULT_ADDR=http://<ai-host-private-ip>:8200
VAULT_API_ADDR=http://<ai-host-private-ip>:8200
```

필수 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `VAULT_IMAGE` | Vault 컨테이너 이미지 | `hashicorp/vault:1.18` |
| `VAULT_PORT` | Vault API/UI 노출 포트 | `8200` |
| `TZ` | 컨테이너 타임존 | `Asia/Seoul` |
| `VAULT_ADDR` | CLI와 client가 접근할 주소 | `http://10.0.0.10:8200` |
| `VAULT_API_ADDR` | Vault가 외부에 알릴 API 주소 | `http://10.0.0.10:8200` |

`.env`, `data/`, `logs/`는 `.gitignore`에 포함되어 있어야 합니다.

## 실행

```bash
cd vault
docker compose -f docker-compose-vault.yml up -d
```

상태 확인:

```bash
docker compose -f docker-compose-vault.yml ps
docker logs -f vault
docker exec vault vault status
```

중지:

```bash
docker compose -f docker-compose-vault.yml down
```

Compose 문법 확인:

```bash
docker compose -f docker-compose-vault.yml config
```

## 초기화와 Unseal

최초 1회 초기화합니다.

```bash
docker exec -it vault vault operator init
```

출력되는 unseal key와 initial root token은 오프라인 비밀 저장소에 보관합니다. Git, 메신저, 일반 노트에 남기지 않습니다.

unseal:

```bash
docker exec -it vault vault operator unseal
docker exec -it vault vault operator unseal
docker exec -it vault vault operator unseal
```

로그인:

```bash
docker exec -it vault vault login
```

컨테이너 재시작 후에는 다시 unseal이 필요합니다. 자동 unseal은 이번 구성 범위에 포함하지 않았습니다.

## BossPickSeoul Secret Path

KV v2 mount는 `kv`를 사용합니다.

권장 path:

```text
kv/bosspickseoul/backend/{env}/{group}/{service}
```

예시:

```text
kv/bosspickseoul/backend/prod/core/api
kv/bosspickseoul/backend/prod/batch/scheduler
kv/bosspickseoul/backend/dev/core/api
```

secret 저장 예시:

```bash
docker exec -it vault vault kv put kv/bosspickseoul/backend/prod/core/api \
  SPRING_PROFILES_ACTIVE=prod \
  DB_HOST=raspberrypi \
  DB_PORT=3306 \
  DB_USERNAME=bosspick \
  DB_PASSWORD=change-me
```

조회:

```bash
docker exec -it vault vault kv get kv/bosspickseoul/backend/prod/core/api
```

## Policy와 AppRole

정책 파일:

- `policies/jenkins-bosspickseoul.hcl`: Jenkins가 배포용 backend secret을 읽는 권한
- `policies/backend-bosspickseoul.hcl`: backend-1 deploy/runtime 용 읽기 권한

초기 bootstrap:

```bash
docker exec -it vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

이 스크립트는 다음 작업을 수행합니다.

- `kv` KV v2 secret engine 활성화
- `approle` auth method 활성화
- Jenkins/backend policy 등록
- `jenkins-bosspickseoul`, `backend-bosspickseoul` AppRole 생성

Jenkins credential에 등록할 값 발급:

```bash
docker exec -it vault vault read auth/approle/role/jenkins-bosspickseoul/role-id
docker exec -it vault vault write -f auth/approle/role/jenkins-bosspickseoul/secret-id
```

backend-1 deploy agent용 값 발급:

```bash
docker exec -it vault vault read auth/approle/role/backend-bosspickseoul/role-id
docker exec -it vault vault write -f auth/approle/role/backend-bosspickseoul/secret-id
```

## Jenkins 배포 흐름

권장 흐름:

1. Jenkins controller가 AppRole로 Vault 로그인
2. Jenkins가 `kv/bosspickseoul/backend/{env}/{group}/{service}`를 읽음
3. Jenkins가 `.env.runtime`을 생성하거나 deploy agent 작업 공간에 전달
4. `backend-1` deploy agent가 `$HOME/deploy/bosspickseoul/backend/...`에 파일 배치
5. `docker compose --env-file .env.runtime up -d --build` 실행
6. 배포 후 `.env.runtime`은 필요 최소 기간만 유지하고 권한을 제한

원칙:

- Vault 원본은 미니PC에 둡니다.
- backend-1에는 secret 원본을 오래 저장하지 않습니다.
- Jenkins는 서비스별 전체 `.env` 계약을 Vault에서 읽습니다.
- deploy agent는 배포만 하고 secret 관리 책임을 최소화합니다.

## 백업과 복구

백업 대상:

- `data/`
- `.env`
- 별도로 보관 중인 unseal key와 root token

백업 예시:

```bash
cd vault
tar czf vault-backup-$(date +%Y%m%d).tar.gz data .env
```

복구 예시:

```bash
cd vault
tar xzf vault-backup-YYYYMMDD.tar.gz
docker compose -f docker-compose-vault.yml up -d
docker exec -it vault vault operator unseal
```

## 운영 주의사항

- root token은 초기 설정과 긴급 복구에만 사용합니다.
- Jenkins와 backend-1은 root token 대신 AppRole을 사용합니다.
- 서비스 또는 환경이 분리되면 policy도 분리합니다.
- 운영 중 `vault.hcl`을 바꾸면 컨테이너 재시작이 필요합니다.
- 공개망 노출이 필요하면 Nginx TLS proxy, IP allowlist, 방화벽 정책을 먼저 적용합니다.

## 문제 해결

상태 확인:

```bash
docker exec vault vault status
```

로그 확인:

```bash
docker logs -f vault
```

권한과 마운트 확인:

```bash
docker exec vault ls -la /vault/file /vault/logs /vault/policies /vault/scripts
```

`Initialized`가 `false`면 `vault operator init`을 먼저 실행합니다. `Sealed`가 `true`면 unseal key로 해제합니다.
