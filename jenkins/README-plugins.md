# Jenkins 플러그인 설치 가이드

BossPickSeoul CI/CD에서 사용하는 Jenkins 플러그인 목록입니다.

현재 구성은 GitHub PR 라벨 기반 멀티브랜치 파이프라인, Vault AppRole 기반 환경변수 주입, builder/deploy agent 분리, Docker Compose 배포를 기준으로 합니다.

## 설치 위치

Jenkins Web UI에서 아래 경로로 이동합니다.

```text
Jenkins 관리 > Plugins > Available plugins
```

설치 후 Jenkins 재시작이 필요한 플러그인이 있으면 `Download now and install after restart` 방식으로 설치합니다.

## 필수 플러그인

| 플러그인 | 용도 | 필요한 이유 |
| --- | --- | --- |
| `Pipeline` | Jenkinsfile 실행 | Groovy 기반 CI/CD 파이프라인 실행에 필요합니다. |
| `Pipeline: Multibranch` | 멀티브랜치 파이프라인 | 브랜치/PR 단위로 Jenkinsfile을 자동 탐색합니다. |
| `Git` | Git checkout | GitHub 저장소 체크아웃에 필요합니다. |
| `Git client` | Git 내부 클라이언트 | Git 플러그인의 하위 의존 플러그인입니다. |
| `GitHub` | GitHub 연동 | GitHub webhook, 상태 알림, API 연동에 필요합니다. |
| `GitHub API` | GitHub API 호출 | GitHub App 인증과 PR/라벨 조회에 필요합니다. |
| `GitHub Branch Source` | GitHub 멀티브랜치 소스 | GitHub 저장소의 브랜치/PR을 멀티브랜치 파이프라인 소스로 사용합니다. |
| `GitHub Label Filter Plugin` | PR 라벨 필터링 | `backend-auth-service` 같은 GitHub 라벨별로 서비스 파이프라인 실행 대상을 제한합니다. |
| `Credentials` | Credential 저장소 | GitHub App, Vault role_id/secret_id 저장에 필요합니다. |
| `Credentials Binding` | Credential 환경변수 바인딩 | Jenkinsfile에서 Vault AppRole 값을 안전하게 주입합니다. |
| `Plain Credentials` | Secret text 타입 | Vault `role_id`, `secret_id`를 Secret text로 저장할 때 필요합니다. |
| `HashiCorp Vault Plugin` | Vault 연동 UI/설정 | Jenkins job/folder에서 Vault URL/Credential 설정을 관리할 수 있습니다. |
| `Pipeline Utility Steps` | `readJSON` 등 유틸 step | Vault API 응답 JSON을 Jenkins sandbox 승인 없이 파싱하기 위해 필요합니다. |
| `Lockable Resources` | 배포 직렬화 | 같은 서버에 여러 서비스가 동시에 배포되지 않도록 `lock` step을 사용합니다. |

## 권장 플러그인

| 플러그인 | 용도 | 비고 |
| --- | --- | --- |
| `Folders` | Job 그룹화 | backend/frontend/job 종류별로 Jenkins item을 정리할 때 유용합니다. |
| `Workspace Cleanup` | workspace 정리 | 현재는 `deleteDir()`를 쓰지만, 추후 `cleanWs()` 사용 시 필요합니다. |
| `Email Extension` | 빌드 알림 | 실패/성공 알림을 이메일로 보내고 싶을 때 사용합니다. |
| `Role-based Authorization Strategy` | 권한 분리 | Jenkins 사용자/팀별 권한을 나눌 때 권장합니다. |
| `Configuration as Code` | Jenkins 설정 IaC | 플러그인, credential, node, system 설정을 코드로 관리하고 싶을 때 권장합니다. |
| `Job DSL` | Jenkins Job IaC | 멀티브랜치 파이프라인 job을 코드로 생성하고 싶을 때 권장합니다. |

## 현재 파이프라인에서 직접 사용하는 기능

| Jenkinsfile 기능 | 필요 플러그인 |
| --- | --- |
| `node`, `stage`, `sh`, `archiveArtifacts`, `stash`, `unstash` | `Pipeline` |
| Multibranch Pipeline item | `Pipeline: Multibranch`, `GitHub Branch Source` |
| GitHub App Credential | `GitHub Branch Source`, `GitHub API`, `Credentials` |
| PR 라벨 조건 실행 | `GitHub Label Filter Plugin` |
| Vault AppRole 값 주입 | `Credentials Binding`, `Plain Credentials` |
| Vault JSON 응답 파싱 | `Pipeline Utility Steps` |
| 서버별 배포 lock | `Lockable Resources` |

## GitHub 라벨 기반 서비스 배포 플러그인 설정

서비스별 Multibranch Pipeline에서 아래처럼 설정합니다.

```text
Branch Sources > GitHub > Behaviours > Add
```

서비스별로 아래 중 하나를 추가합니다.

```text
Filter pull requests with any specified labels
```

예시:

| Jenkins item | GitHub label |
| --- | --- |
| `backend-service-discovery` | `backend-service-discovery` |
| `backend-auth-service` | `backend-auth-service` |
| `backend-api-gateway` | `backend-api-gateway` |
| `backend-ai-service` | `backend-ai-service` |
| `backend-district-service` | `backend-district-service` |
| `backend-commercial-service` | `backend-commercial-service` |
| `backend-community-service` | `backend-community-service` |
| `backend-batch-service` | `backend-batch-service` |

PR에 라벨을 나중에 추가/삭제해도 GitHub webhook의 `pull_request` 이벤트가 들어오면 Jenkins가 다시 PR을 스캔합니다.

## Vault Credential 설정

Jenkins Web UI에서 아래 경로로 이동합니다.

```text
Jenkins 관리 > Credentials > System > Global credentials
```

아래 Credential을 추가합니다.

| ID | Kind | Secret 값 |
| --- | --- | --- |
| `bosspickseoul-vault-role-id` | `Secret text` | Vault AppRole `role_id` |
| `bosspickseoul-vault-secret-id` | `Secret text` | Vault AppRole `secret_id` |

`secret_id`는 공백이나 줄바꿈 없이 저장하는 것을 권장합니다. 복사 과정에서 앞뒤 공백이 들어가면 Vault 로그인이 실패할 수 있습니다.

## GitHub App Credential 설정

Multibranch Pipeline의 Branch Source에서 GitHub App Credential을 사용합니다.

권장 Credential 예시:

```text
ID: github-app-followfollowme-jenkins
Kind: GitHub App
App ID: GitHub App ID
Key: GitHub App private key
```

Jenkins GitHub App Credential에서 private key 형식 오류가 나면 PKCS#8 형식으로 변환합니다.

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -in current-key.pem -out new-key.pem -nocrypt
```

## 설치 확인 체크리스트

- `New Item` 화면에 `Multibranch Pipeline`이 보이는지 확인합니다.
- Multibranch Pipeline의 `Branch Sources`에서 `GitHub`를 선택할 수 있는지 확인합니다.
- GitHub App Credential로 `Test Connection`이 성공하는지 확인합니다.
- `Behaviours > Add`에 `Filter pull requests with any specified labels`가 보이는지 확인합니다.
- Pipeline 실행 중 `readJSON` step이 정상 동작하는지 확인합니다.
- Pipeline 실행 중 `lock` step이 정상 동작하는지 확인합니다.
- 배포 agent에서 `docker --version`, `docker compose version`이 정상 출력되는지 확인합니다.

## 자주 만나는 오류

### `No such DSL method 'lock'`

`Lockable Resources` 플러그인이 없을 때 발생합니다.

### `No such DSL method 'readJSON'`

`Pipeline Utility Steps` 플러그인이 없을 때 발생합니다.

### `Scripts not permitted to use new groovy.json.JsonSlurperClassic`

Jenkins sandbox에서 Groovy JSON 파서 생성이 막힌 경우입니다.

현재 파이프라인은 `readJSON`을 사용하므로 `Pipeline Utility Steps`를 설치하면 별도 script approval 없이 처리할 수 있습니다.

### PR 라벨을 붙였는데 빌드가 안 도는 경우

아래를 확인합니다.

```text
GitHub Webhook Recent Deliveries > pull_request action=labeled
Jenkins Multibranch Pipeline > Branch Sources > label filter
Jenkins Multibranch Pipeline > Scan Multibranch Pipeline Now
```

Webhook은 정상인데 Jenkins가 반응하지 않으면 PR 라벨을 제거 후 다시 추가하거나 빈 커밋을 push해서 재스캔을 유도합니다.

