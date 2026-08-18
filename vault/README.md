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
│   ├── bootstrap-bosspickseoul.sh
│   ├── reset-kv-bosspickseoul.sh
│   └── rotate-approle-secret.sh
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

여기서 앞의 `kv`는 secret engine mount 이름입니다. 실제 secret path에는 `kv/`를 한 번 더 넣지 않습니다.

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

Jenkins 경로는 다음처럼 단순하게 유지합니다.

```text
kv/bosspickseoul/backend/dev/env
kv/bosspickseoul/backend/prod/env
kv/bosspickseoul/frontend/dev/env
kv/bosspickseoul/frontend/prod/env
```

파이프라인은 `{root}/{env}/env` 규칙으로 경로를 조립합니다. root 기본값은 backend 잡이 `kv/bosspickseoul/backend`, frontend 잡이 `kv/bosspickseoul/frontend` 입니다. 잡 파라미터 `VAULT_SECRET_ROOT` / `VAULT_SECRET_PATH` 로 덮어쓸 수 있지만 평소에는 건드리지 않습니다.

frontend 경로는 `policies/jenkins-bosspickseoul.hcl` 에 backend 와 함께 들어 있습니다. **Jenkins credential 을 따로 만들 필요는 없습니다** — 두 파이프라인이 같은 AppRole 을 씁니다. 자세한 내용과 정책 반영 절차는 `Bootstrap` 절을 참고합니다.

### 프론트 secret 에 넣을 key

주입 시점이 둘로 나뉩니다. `NEXT_PUBLIC_*` 는 **빌드 시점에 코드로 인라인**되므로 컨테이너 환경변수로 넣어도 무시됩니다. 그래서 dev 와 prod 를 각각 빌드합니다.

key 목록의 기준은 애플리케이션 레포의 `frontend/.env.example` 이고, 배포 절차는 `frontend/docs/runbook/deployment.md` 를 따릅니다.

#### 필수 — 없으면 파이프라인이 실패합니다

| key | 시점 | dev 값 | prod 값 |
| --- | --- | --- | --- |
| `NEXT_PUBLIC_SITE_URL` | 빌드 | `https://dev.bosspickseoul.com` | `https://www.bosspickseoul.com` |
| `NEXT_PUBLIC_WS_URL` | 빌드 | `wss://api-dev.bosspickseoul.com/ws` | `wss://api.bosspickseoul.com/ws` |
| `NEXT_PUBLIC_KAKAO_JAVASCRIPT_KEY` | 빌드 | 카카오 콘솔의 JavaScript 키 (dev/prod 동일) | 〃 |
| `AUTH_SESSION_SECRET` | 런타임 | `openssl rand -base64 48` | dev 와 **다른** 값 |
| `BACKEND_API_URL` | 런타임 | `https://api-dev.bosspickseoul.com` | `https://api.bosspickseoul.com` |
| `TIME_ZONE` | 런타임 | `Asia/Seoul` | `Asia/Seoul` |
| `FRONTEND_WEB_PORT` | 런타임 | `6300` | `9300` |
| `FRONTEND_WEB_MEM_LIMIT` | 런타임 | `512m` | `768m` |

포트와 메모리 상한에 **환경 접미사가 없습니다.** 환경별로 `.env.runtime` 이 따로 만들어지므로 각 secret 에 값 하나만 넣으면 됩니다. compose 파일 하나에 dev/prod 서비스가 같이 정의되어 있지만 두 서비스가 같은 변수명을 참조하므로, 배포하지 않는 쪽 값을 따로 넣을 필요가 없습니다.

프론트 compose 에는 **환경변수 기본값(`:-`)을 두지 않습니다.** 값이 비면 조용히 다른 포트로 뜨는 대신 파이프라인의 `Runtime env key check` 에서 배포가 중단됩니다.

#### 선택 — 비워두거나 아예 넣지 않아도 됩니다

| key | 시점 | 비었을 때 |
| --- | --- | --- |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | 빌드 | FCM 웹 푸시(채팅 알림)가 자동 비활성화됩니다. 앱 나머지는 정상 동작합니다. |
| `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID` | 빌드 | 〃 |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | 빌드 | 〃 |
| `NEXT_PUBLIC_FIREBASE_VAPID_KEY` | 빌드 | 〃 |
| `NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID` | 빌드 | Analytics 용. 없어도 푸시는 동작합니다. |

Firebase 4종은 **넷이 모두 있어야** 푸시가 켜집니다. 하나라도 비면 코드가 스스로 비활성화하므로, 푸시를 쓰기로 정하기 전에는 Vault 에 넣지 않아도 됩니다.

#### 넣지 않는 key

| key | 이유 |
| --- | --- |
| `NEXT_PUBLIC_API_URL` | 브라우저 REST 호출은 same-origin `/api/bff` 로 나가고 백엔드 주소는 서버 쪽 `BACKEND_API_URL` 만 압니다. 번들에 넣을 이유가 없습니다. |
| `NEXT_PUBLIC_KAKAOMAP_API_KEY` | 카카오는 지도 SDK 와 공유 SDK 가 **같은 JavaScript 키** 하나를 씁니다. `NEXT_PUBLIC_KAKAO_JAVASCRIPT_KEY` 로 통합했습니다. |
| `BOSSPICK_API_DOCS_URL` | 로컬에서 OpenAPI 문서를 내려받는 스크립트 전용입니다. |

#### 주의

- **`AUTH_SESSION_SECRET` 은 환경당 한 번만 만들고 고정합니다.** 배포마다 새로 만들면 안 됩니다. 이 값은 세션 쿠키의 A256GCM 암호화 키(SHA-256 해시)라, 바뀌는 순간 기존 쿠키를 복호화할 수 없어 **로그인한 사용자가 전원 로그아웃**됩니다. 유출됐을 때만 의도적으로 교체하고, 그때도 전원 로그아웃을 감수하는 작업으로 다룹니다. dev 와 prod 는 서로 다른 값을 씁니다.
- **`NEXT_PUBLIC_*` 에는 비밀값을 넣지 않습니다.** 브라우저 번들에 문자열로 그대로 박힙니다. 위 목록의 카카오·Firebase 키는 원래 클라이언트 공개용이라 괜찮습니다.
- **`BACKEND_API_URL` 은 사설 IP 가 아니라 공개 도메인**을 씁니다. dev 프론트와 dev 게이트웨이가 같은 호스트에 있어 `http://192.168.0.11:6000` 으로 질러도 될 것 같지만, auth API(`/api/v1/auth`, `/api/v1/members`)는 게이트웨이를 거치지 않고 auth-service 로 직결되며 그 분기를 nginx 가 합니다.

### kv 경로 초기화

경로가 `kv/kv/...`처럼 꼬였고 Vault를 다시 구성하는 시점이라면 kv mount를 삭제 후 다시 만드는 편이 가장 깔끔합니다.

주의: 아래 작업은 `kv` secret engine 아래의 모든 secret을 삭제합니다.

```bash
docker exec -it \
  -e CONFIRM_RESET_KV=bosspickseoul \
  vault sh /vault/scripts/reset-kv-bosspickseoul.sh
```

그 다음 bootstrap으로 policy와 AppRole을 다시 반영합니다.

```bash
docker exec -it vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

Web UI 사용자를 같이 만들거나 갱신하려면 다음처럼 실행합니다.

```bash
docker exec -it \
  -e VAULT_UI_USERNAME='username' \
  -e VAULT_UI_PASSWORD='password' \
  vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

정리 후 secret은 반드시 mount `kv` 아래의 `bosspickseoul/...` 경로에 저장합니다.

```bash
docker exec -i vault vault kv put -mount="kv" bosspickseoul/backend/dev/env env_file=@/dev/stdin < .env
```

조회:

```bash
docker exec -it vault vault kv get -mount="kv" bosspickseoul/backend/dev/env
```

## Bootstrap

정책 파일:

- `policies/jenkins-bosspickseoul.hcl`: Jenkins가 배포용 secret을 읽는 권한 (**backend + frontend 공용**)
- `policies/backend-bosspickseoul.hcl`: backend-1 deploy/runtime 용 읽기 권한
- `policies/ui-bosspickseoul.hcl`: Web UI 사용자가 `kv/bosspickseoul/*` 시크릿을 관리하는 권한

### AppRole 은 파이프라인별로 나누지 않습니다

backend 파이프라인과 frontend 파이프라인이 **같은 AppRole(`jenkins-bosspickseoul`) 하나**를 씁니다. 그래서 `jenkins-frontend-...` 같은 role 이나 Jenkins credential 을 따로 만들 필요가 없습니다.

| AppRole | 쓰는 곳 | Jenkins credential | 읽는 경로 |
| --- | --- | --- | --- |
| `jenkins-bosspickseoul` | backend 잡, **frontend 잡** | `bosspickseoul-vault-role-id`, `bosspickseoul-vault-secret-id` | `kv/bosspickseoul/backend/*`, `kv/bosspickseoul/frontend/*` |
| `backend-bosspickseoul` | backend-1 deploy/runtime | (deploy agent secret) | `kv/bosspickseoul/backend/*` |

두 파이프라인의 `VAULT_ROLE_ID_CREDENTIAL_ID` / `VAULT_SECRET_ID_CREDENTIAL_ID` 기본값이 같기 때문에, 새 애플리케이션 그룹이 생기면 **credential 을 추가하는 게 아니라 `jenkins-bosspickseoul.hcl` 에 경로 블록을 추가**하고 bootstrap 을 다시 돌립니다. 실제로 frontend 도 그렇게 붙였습니다.

role 을 파이프라인별로 쪼개면 권한은 더 좁아지지만 credential 쌍과 회전 절차가 그만큼 늘어납니다. 지금 규모에서는 통합 쪽이 맞습니다.

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

### 정책(`.hcl`)만 고쳤을 때 — bootstrap 재실행이 전부입니다

`policies/` 는 컨테이너에 bind mount(`./policies:/vault/policies:ro`) 되어 있어, 호스트에서 `.hcl` 을 고치면 컨테이너 안에서 **이미 보입니다.** 이미지 재빌드도 컨테이너 재시작도 필요 없습니다.

다만 **Vault 는 그 파일을 읽어서 정책을 적용하지 않습니다.** 정책은 Vault 내부 스토리지에 저장되므로 `vault policy write` 로 밀어넣어야 반영됩니다. 그게 bootstrap 이 하는 일입니다.

```bash
cd ~/infra && git pull                         # .hcl 파일이 서버에 있어야 합니다
docker exec -it vault vault status             # Sealed: false 확인
docker exec -it -e VAULT_TOKEN='<root-token>' vault sh /vault/scripts/bootstrap-bosspickseoul.sh
docker exec -it vault vault policy read jenkins-bosspickseoul   # 반영 확인
```

> ⚠️ **`install-vault.sh` 를 쓰지 마십시오.** 그건 컨테이너를 띄우는 스크립트입니다. `vault.hcl` 이 `storage "file"` 에 auto-unseal 설정이 없어서, 컨테이너가 재생성되면 **Vault 가 sealed 상태로 떠서 수동 unseal 이 필요**합니다. 정책 변경에는 컨테이너를 건드릴 이유가 없습니다.

재실행해도 안전한 이유:

| bootstrap 동작 | 재실행 시 |
| --- | --- |
| `secrets enable kv` / `auth enable approle,userpass` | 이미 활성화되어 있으면 실패를 무시하고 넘어감 |
| `vault policy write` × 3 | 덮어쓰기. 내용이 그대로면 실질 변화 없음 |
| `vault write auth/approle/role/...` | **`role_id` 와 기존 `secret_id` 는 그대로 유지됩니다.** role 설정(TTL 등)만 갱신되고 자격증명은 별도 엔드포인트로 관리됩니다 |
| Web UI 사용자 생성 | `VAULT_UI_USERNAME` / `VAULT_UI_PASSWORD` 를 넘기지 않으면 건너뜀 |

따라서 **Jenkins credential 을 재발급할 필요가 없고**, 진행 중인 배포에도 영향이 없습니다.

`require_admin_token` 검사가 있어 **Web UI userpass 계정 토큰으로는 실행되지 않습니다.** root token 또는 policy 갱신 권한이 있는 token 이 필요합니다.

## Web UI username/password 로그인

Vault Web UI에서 username/password로 로그인하려면 `userpass` auth method와 UI 사용자가 필요합니다. Vault를 다시 초기화할 필요는 없고, unseal과 root token 로그인 이후 bootstrap을 다시 실행하면 됩니다.

비밀번호는 Git에 커밋하지 않고 실행 시점에만 환경변수로 전달합니다.

bootstrap은 policy와 AppRole도 함께 갱신하므로 root token 또는 관리자 권한 token으로 실행해야 합니다. Web UI userpass 계정으로 로그인한 token은 보통 권한이 부족합니다.

컨테이너 안에 root token으로 먼저 로그인:

```bash
docker exec -it vault vault login
```

또는 실행 시점에 token 전달:

```bash
docker exec -it \
  -e VAULT_TOKEN='<root-token>' \
  -e VAULT_UI_USERNAME='username' \
  -e VAULT_UI_PASSWORD='password' \
  vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

root token 로그인 후 실행:

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

## AppRole 발급과 회전

Bootstrap 이후 Jenkins와 backend-1 deploy agent가 사용할 AppRole 값을 발급합니다. `role_id`는 role을 식별하는 값이고, `secret_id`는 비밀번호처럼 동작하는 값입니다. `secret_id` 원문은 Git, README, 이슈, 메신저에 남기지 않습니다.

이 repo에서 IaC로 관리하는 범위:

| 대상 | 관리 방식 |
| --- | --- |
| Vault policy | `policies/*.hcl` |
| AppRole role 설정 | `scripts/bootstrap-bosspickseoul.sh` |
| `role_id`, `secret_id` 발급 절차 | `scripts/rotate-approle-secret.sh` |
| `secret_id` 원문 | Jenkins Credential 또는 별도 비밀 저장소 |

### 1. bootstrap으로 role 설정 반영

policy나 AppRole TTL, policy 매핑을 바꾼 경우 먼저 bootstrap을 다시 실행합니다. 이 작업은 root token 또는 관리자 권한 token이 필요합니다.

```bash
docker exec -it vault vault login
docker exec -it vault sh /vault/scripts/bootstrap-bosspickseoul.sh
```

현재 bootstrap은 아래 AppRole을 생성하거나 갱신합니다.

| role | policy | token TTL | max TTL | secret_id TTL | secret_id 사용 횟수 |
| --- | --- | --- | --- | --- | --- |
| `jenkins-bosspickseoul` | `jenkins-bosspickseoul` | `1h` | `4h` | `만료 없음 (0)` | 무제한 |
| `backend-bosspickseoul` | `backend-bosspickseoul` | `30m` | `2h` | `720h` | 무제한 |

### 2. Jenkins용 role_id/secret_id 발급

Jenkins controller가 Vault에 로그인할 때 사용할 값을 발급합니다.

```bash
docker exec -it vault sh /vault/scripts/rotate-approle-secret.sh jenkins-bosspickseoul
```

옵션 없이 실행해도 기본값은 Jenkins용 role입니다.

```bash
docker exec -it vault sh /vault/scripts/rotate-approle-secret.sh
```

출력 예시:

```text
role_name:
jenkins-bosspickseoul

role_id:
...

new_secret_id:
...
```

Jenkins에는 아래처럼 등록합니다.

| Jenkins Credential ID | 종류 | 값 |
| --- | --- | --- |
| `bosspickseoul-vault-role-id` | Secret text | 출력된 `role_id` |
| `bosspickseoul-vault-secret-id` | Secret text | 출력된 `new_secret_id` |

### 3. backend deploy/runtime용 값 발급

backend deploy agent 또는 runtime 쪽에서 직접 Vault 로그인이 필요한 경우에만 발급합니다. Jenkins가 Vault를 읽고 deploy agent에 `.env.runtime`만 전달하는 구조라면 backend AppRole은 사용하지 않아도 됩니다.

```bash
docker exec -it vault sh /vault/scripts/rotate-approle-secret.sh backend-bosspickseoul
```

발급한 값은 backend-1 deploy agent의 비밀 저장소에 넣고, Git에는 저장하지 않습니다.

### 4. secret_id 회전 절차

Jenkins용 `secret_id`는 기본 IaC 기준으로 만료 없이 운영합니다. 따라서 30일 같은 주기 만료로 빌드가 깨지지는 않아야 합니다. 다만 값이 노출됐거나 보안 점검 차원에서 직접 회전하려는 경우에는 새 값을 발급하고 Jenkins Credential만 갱신합니다.

1. 새 secret 발급:

```bash
docker exec -it vault sh /vault/scripts/rotate-approle-secret.sh jenkins-bosspickseoul
```

2. Jenkins에서 `bosspickseoul-vault-secret-id` 값을 새 `new_secret_id`로 교체합니다.
3. `bosspickseoul-vault-role-id`는 role을 재생성하지 않았다면 보통 그대로 둡니다. 그래도 스크립트 출력값과 맞춰 갱신해도 문제 없습니다.
4. Jenkins pipeline 또는 아래 AppRole 로그인 테스트를 실행합니다.
5. 테스트가 성공하면 이전 `secret_id`는 운영상 폐기된 값으로 간주합니다.

기존 `secret_id`를 즉시 무효화하려면 Vault의 `secret_id_accessor`가 필요합니다. 평소에는 새 값 발급 후 Jenkins credential을 갱신하는 방식으로 회전하고, 즉시 폐기가 필요한 사고 대응 상황에서는 관리자 token으로 accessor를 확인해 폐기합니다.

### 5. 수동 발급 명령

스크립트를 쓰지 않고 직접 발급할 수도 있습니다.

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

발급한 값은 다음처럼 관리합니다.

| 값 | 저장 위치 | 용도 |
| --- | --- | --- |
| Jenkins `role_id` | Jenkins Credential `bosspickseoul-vault-role-id` | Vault 로그인용 |
| Jenkins `secret_id` | Jenkins Credential `bosspickseoul-vault-secret-id` | Vault 로그인용 |
| backend `role_id` | backend-1 deploy agent secret | 필요 시 Vault 로그인용 |
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
- **root token을 채팅·이슈·PR·로그에 붙여넣지 않습니다.** 노출됐다면 즉시 폐기하고 새로 발급합니다. 폐기하지 않으면 그 토큰으로 Vault 전체를 읽고 쓸 수 있습니다.
  ```bash
  docker exec -it -e VAULT_TOKEN='<노출된-root-token>' vault vault token revoke -self
  docker exec -it vault vault operator generate-root -init   # unseal key 로 새 root token 발급
  ```
- Jenkins와 backend-1은 root token 대신 AppRole을 사용합니다.
- 정책(`.hcl`)을 바꿨을 때는 컨테이너를 건드리지 말고 bootstrap만 다시 실행합니다. (`Bootstrap` 절 참고)
- 운영 중 `vault.hcl`을 바꾸면 컨테이너 재시작이 필요하고, 재시작하면 **sealed 상태가 되어 수동 unseal이 필요**합니다.
- 서비스 또는 환경이 분리되면 policy도 분리합니다. 단, Jenkins 파이프라인이 늘어나는 경우는 AppRole을 새로 만들지 말고 `jenkins-bosspickseoul.hcl`에 경로 블록을 추가합니다.
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
