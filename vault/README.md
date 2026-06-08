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
├── install-vault.sh
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

| 변수             | 설명                         | 예시                    |
| ---------------- | ---------------------------- | ----------------------- |
| `VAULT_IMAGE`    | Vault 컨테이너 이미지        | `hashicorp/vault:1.18`  |
| `VAULT_PORT`     | Vault API/UI 노출 포트       | `8200`                  |
| `TZ`             | 컨테이너 타임존              | `Asia/Seoul`            |
| `VAULT_ADDR`     | CLI와 client가 접근할 주소   | `http://10.0.0.10:8200` |
| `VAULT_API_ADDR` | Vault가 외부에 알릴 API 주소 | `http://10.0.0.10:8200` |

`.env`, `data/`, `logs/`는 `.gitignore`에 포함되어 있어야 합니다.

## 실행

스크립트 실행:

```bash
cd vault
sh install-vault.sh
```

직접 실행:

```bash
cd vault
docker compose --env-file .env -f docker-compose-vault.yml up -d
```

상태 확인:

```bash
docker compose --env-file .env -f docker-compose-vault.yml ps
docker logs -f vault
docker exec vault vault status
```

중지:

```bash
docker compose --env-file .env -f docker-compose-vault.yml down
```

Compose 문법 확인:

```bash
docker compose --env-file .env -f docker-compose-vault.yml config
```

## 초기화와 Unseal

Vault는 최초 1회 초기화가 필요합니다. 초기화를 하면 unseal key 5개와 initial root token 1개가 발급됩니다.

```bash
docker exec -it vault vault operator init
```

출력되는 unseal key와 initial root token은 오프라인 비밀 저장소에 보관합니다. Git, 메신저, 일반 노트에 남기지 않습니다.

초기화 후에는 Vault가 sealed 상태입니다. 5개 unseal key 중 3개를 입력해 잠금을 해제합니다.

```bash
docker exec -it vault vault operator unseal
docker exec -it vault vault operator unseal
docker exec -it vault vault operator unseal
```

상태 확인:

```bash
docker exec vault vault status
```

다음처럼 `Sealed`가 `false`이면 사용할 수 있습니다.

```text
Initialized     true
Sealed          false
```

root token으로 로그인합니다.

```bash
docker exec -it vault vault login
```

컨테이너 재시작, 재생성, 서버 재부팅 후에는 다시 unseal이 필요합니다. 자동 unseal은 이번 구성 범위에 포함하지 않았습니다.

주의:

- `vault operator init`은 최초 1회만 실행합니다.
- 이미 초기화된 Vault에서 다시 init을 실행하면 실패합니다.
- `data/`를 삭제하면 기존 Vault 데이터와 키가 사라지므로 운영 중에는 삭제하지 않습니다.

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

## Bootstrap

정책 파일:

- `policies/jenkins-bosspickseoul.hcl`: Jenkins가 배포용 backend secret을 읽는 권한
- `policies/backend-bosspickseoul.hcl`: backend-1 deploy/runtime 용 읽기 권한
- `policies/ui-bosspickseoul.hcl`: Web UI 사용자가 `kv/bosspickseoul/*` 시크릿을 관리하는 권한

실행 시점:

1. Vault 컨테이너 실행
2. `vault operator init`
3. `vault operator unseal`
4. `vault login`
5. 아래 bootstrap 스크립트 실행
6. AppRole `role_id`, `secret_id`를 Jenkins credential 또는 backend-1 deploy agent secret으로 등록

초기 bootstrap은 Vault 서버를 처음 구성할 때 1회 실행합니다. policy나 AppRole 설정을 바꾼 경우에는 다시 실행해 갱신할 수 있습니다.

```bash
docker exec -it vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

이 스크립트는 다음 작업을 수행합니다.

- `kv` KV v2 secret engine 활성화
- `approle` auth method 활성화
- `userpass` auth method 활성화
- Jenkins/backend policy 등록
- Web UI policy 등록
- `jenkins-bosspickseoul`, `backend-bosspickseoul` AppRole 생성
- `VAULT_UI_USERNAME`, `VAULT_UI_PASSWORD`가 전달된 경우 Web UI 사용자 생성 또는 갱신

성공하면 다음 메시지가 출력됩니다.

```text
Success! Enabled the kv-v2 secrets engine at: kv/
Success! Enabled approle auth method at: approle/
Success! Enabled userpass auth method at: userpass/
Success! Uploaded policy: jenkins-bosspickseoul
Success! Uploaded policy: backend-bosspickseoul
Success! Uploaded policy: ui-bosspickseoul
```

이미 한 번 실행한 뒤 다시 실행하면 `kv`, `approle`, `userpass` 활성화 메시지는 생략될 수 있습니다. policy와 AppRole은 다시 등록되어 갱신됩니다.

## Web UI username/password 로그인

Vault Web UI에서 username/password로 로그인하려면 `userpass` auth method와 UI 사용자가 필요합니다. Vault를 다시 초기화할 필요는 없고, unseal과 root token 로그인 이후 bootstrap을 다시 실행하면 됩니다.

비밀번호는 Git에 커밋하지 않고 실행 시점에만 환경변수로 전달합니다.

```bash
docker exec -it \
  -e VAULT_UI_USERNAME='username' \
  -e VAULT_UI_PASSWORD='password' \
  vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

Web UI 로그인 화면에서는 Method를 `Username` 또는 `userpass`로 선택하고 위 username/password를 입력합니다.

비밀번호 변경:

```bash
docker exec -it vault vault write auth/userpass/users/admin/password password='<새-비밀번호>'
```

사용자 삭제:

```bash
docker exec -it vault vault delete auth/userpass/users/admin
```

## AppRole 발급

Bootstrap 이후 Jenkins와 backend-1 deploy agent가 사용할 AppRole 값을 발급합니다.

Jenkins credential에 등록할 값:

```bash
docker exec -it vault vault read auth/approle/role/jenkins-bosspickseoul/role-id
docker exec -it vault vault write -f auth/approle/role/jenkins-bosspickseoul/secret-id
```

backend-1 deploy agent용 값:

```bash
docker exec -it vault vault read auth/approle/role/backend-bosspickseoul/role-id
docker exec -it vault vault write -f auth/approle/role/backend-bosspickseoul/secret-id
```

발급된 값은 다음처럼 관리합니다.

| 값                  | 저장 위치                     | 용도                   |
| ------------------- | ----------------------------- | ---------------------- |
| Jenkins `role_id`   | Jenkins Credential            | Vault 로그인용         |
| Jenkins `secret_id` | Jenkins Credential            | Vault 로그인용         |
| backend `role_id`   | backend-1 deploy agent secret | 필요 시 Vault 로그인용 |
| backend `secret_id` | backend-1 deploy agent secret | 필요 시 Vault 로그인용 |

`secret_id`는 비밀번호처럼 취급합니다. Git에 커밋하지 않습니다.

## AppRole 로그인 테스트

Jenkins용 AppRole이 실제로 Vault에 로그인할 수 있는지 테스트할 수 있습니다.

먼저 `role_id`, `secret_id`를 변수로 준비합니다.

```bash
JENKINS_ROLE_ID='<발급받은-role-id>'
JENKINS_SECRET_ID='<발급받은-secret-id>'
```

로그인 테스트:

```bash
docker exec -e JENKINS_ROLE_ID="$JENKINS_ROLE_ID" -e JENKINS_SECRET_ID="$JENKINS_SECRET_ID" vault \
  vault write auth/approle/login role_id="$JENKINS_ROLE_ID" secret_id="$JENKINS_SECRET_ID"
```

응답에 `token`이 나오면 AppRole 로그인은 정상입니다.

## Secret 저장 테스트

Bootstrap 후에는 `kv` 경로에 secret을 저장할 수 있습니다.

예시:

```bash
docker exec -it vault vault kv put kv/bosspickseoul/backend/dev/core/api \
  SPRING_PROFILES_ACTIVE=dev \
  DB_HOST=raspberrypi \
  DB_PORT=3306 \
  DB_USERNAME=bosspick \
  DB_PASSWORD=change-me
```

조회:

```bash
docker exec -it vault vault kv get kv/bosspickseoul/backend/dev/core/api
```

Jenkins pipeline에서는 이 경로를 환경별로 바꿔 읽습니다.

```text
kv/bosspickseoul/backend/{env}/{group}/{service}
```

## AppRole 읽기 권한 테스트

발급된 AppRole token으로 secret 읽기 권한까지 확인할 수 있습니다.

```bash
JENKINS_VAULT_TOKEN='<approle-login-token>'

docker exec -e VAULT_TOKEN="$JENKINS_VAULT_TOKEN" vault \
  vault kv get kv/bosspickseoul/backend/dev/core/api
```

secret이 조회되면 Jenkins용 policy와 AppRole 권한이 정상입니다.

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
