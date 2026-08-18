# Jenkins 운영 가이드

이 디렉터리는 Jenkins controller, builder agent, deploy agent를 역할별 IaC로 분리해서 운영하기 위한 구성입니다.

- `jenkins-controller`: Jenkins Web UI, job 관리, agent 연결 관리
- `jenkins-builder-agent`: Gradle/Node/Docker build 전용 agent
- `jenkins-deploy-agent`: Docker Compose 배포 전용 agent

controller는 Jenkins UI에서 executor 수를 `0`으로 설정하고, 실제 작업은 label이 맞는 agent에서만 실행하는 것을 권장합니다.

## 권장 구성

```text
ollama-01 / Jenkins 서버
├── jenkins-controller              # Web UI, pipeline 관리
└── jenkins-builder-agent           # label: builder builder-backend builder-frontend
                                    # (Node 22/pnpm 포함 — 프론트 전용 빌더를 따로 두지 않는다)

main-server (dev 배포 대상)
└── backend-dev-agent               # label: deploy-backend-dev deploy-frontend-dev

backend-1 (prod 배포 대상)
└── backend-prod-agent              # label: deploy-backend-prod deploy-frontend-prod
```

호스트당 deploy agent 하나를 두고 라벨을 여러 개 붙입니다. 프로젝트나 환경마다 노드를 늘리지 않습니다.

무거운 build/test는 builder agent가 처리하고, deploy agent는 pull/restart/health check 같은 배포 작업만 처리합니다.

## Compose `name` 사용 기준

Compose 파일 최상단의 `name:`은 Docker Compose project name입니다. Docker Compose는 이 값을 기준으로 기본 컨테이너, 네트워크, 볼륨 이름을 묶습니다.

예를 들어:

```yaml
name: backend-dev-agent
```

이면 Compose가 자동 생성하는 리소스가 대체로 `backend-dev-agent_default`, `backend-dev-agent_<volume>`처럼 이 project 아래에 묶입니다.

이 구성에서 `name:`을 쓰는 이유는 같은 서버에서 여러 agent를 동시에 띄울 수 있게 하기 위해서입니다. `backend-dev-agent`, `backend-prod-agent`가 같은 compose 파일을 쓰더라도 project name이 다르면 서로 다른 배포 단위로 관리할 수 있습니다.

현재 배치는 호스트당 agent 하나에 라벨을 여러 개 붙이는 방식이라 한 서버에서 여러 agent를 띄우지 않습니다. 나중에 한 호스트가 dev/prod 를 함께 담당하게 되면 이 기능이 필요해집니다.

주의할 점:

- `container_name`을 직접 지정하면 컨테이너 이름은 project name prefix를 따르지 않습니다.
- 같은 서버에서 여러 agent를 띄울 때는 `name`, `container_name`, `workdir`를 모두 다르게 둡니다.
- `docker compose -p <name>`도 같은 역할을 하지만, 여기서는 `.env`로 관리하려고 compose 파일의 `name:`을 사용합니다.

## 파일 구조

```text
jenkins/
├── docker-compose-jenkins-controller.yml      # controller 전용 compose
├── docker-compose-jenkins-builder-agent.yml   # builder agent 전용 compose
├── docker-compose-jenkins-deploy-agent.yml    # deploy agent 전용 compose
├── jenkins-controller.Dockerfile              # controller 이미지
├── jenkins-builder-agent.Dockerfile           # builder agent 이미지
├── jenkins-deploy-agent.Dockerfile            # deploy agent 이미지
├── docker-entrypoint-jenkins.sh               # controller 시작 스크립트
├── docker-entrypoint-jenkins-agent.sh         # builder/deploy agent 공통 시작 스크립트
├── install-jenkins.sh                         # controller 실행
├── install-jenkins-builder.sh                 # builder agent 실행
├── install-jenkins-agent.sh                   # deploy agent 실행
├── .env.example                               # 환경변수 예시
└── README.md
```

agent 시작 스크립트는 공통으로 사용합니다. Jenkins inbound agent 실행, Docker socket group 동기화, workdir 권한 정리는 동일하고, 캐시 준비만 `JENKINS_AGENT_CACHE_PROFILE`로 `builder`/`deploy`를 나눕니다.

## 환경변수

실행 전에 `.env`를 준비합니다.

```bash
cd jenkins
cp .env.example .env
```

controller 주요 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `JENKINS_WEB_PORT` | Jenkins Web UI 외부 포트 | `49999` |
| `JENKINS_AGENT_PORT` | inbound agent 연결 포트 | `50000` |
| `JENKINS_CONTROLLER_PROJECT_NAME` | controller compose project name | `jenkins-controller` |
| `JENKINS_CONTROLLER_IMAGE` | controller 이미지 이름 | `jenkins-controller:latest` |
| `JENKINS_CONTROLLER_CONTAINER_NAME` | controller 컨테이너 이름 | `jenkins-controller` |
| `JENKINS_CONTROLLER_HOME` | Jenkins home bind mount 경로 | `./jenkins-home` |
| `JENKINS_CONTROLLER_JAVA_OPTS` | controller JVM 옵션 | `"-Xms512m -Xmx2048m -Duser.timezone=Asia/Seoul"` |

builder 주요 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `JENKINS_URL` | agent가 접근할 controller 주소 | `http://<controller-private-ip>:49999` |
| `JENKINS_BUILDER_NAME` | Jenkins UI에 등록한 builder node 이름 | `jenkins-builder-agent` |
| `JENKINS_BUILDER_SECRET` | Jenkins가 발급한 node secret | Jenkins UI 발급값 |
| `JENKINS_BUILDER_PROJECT_NAME` | builder compose project name | `jenkins-builder-agent` |
| `JENKINS_BUILDER_IMAGE` | builder 이미지 이름 | `jenkins-builder-agent:latest` |
| `JENKINS_BUILDER_CONTAINER_NAME` | builder 컨테이너 이름 | `jenkins-builder-agent` |
| `JENKINS_BUILDER_WORKDIR` | builder 작업공간 | `./jenkins-builder-agent` |

deploy 주요 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `JENKINS_URL` | agent가 접근할 controller 주소 | `http://<controller-private-ip>:49999` |
| `JENKINS_DEPLOY_AGENT_NAME` | Jenkins UI에 등록한 deploy node 이름 | `backend-dev-agent` |
| `JENKINS_DEPLOY_AGENT_SECRET` | Jenkins가 발급한 node secret | Jenkins UI 발급값 |
| `JENKINS_DEPLOY_AGENT_PROJECT_NAME` | deploy compose project name | `backend-dev-agent` |
| `JENKINS_DEPLOY_AGENT_IMAGE` | deploy 이미지 이름 | `jenkins-deploy-agent:latest` |
| `JENKINS_DEPLOY_AGENT_CONTAINER_NAME` | deploy 컨테이너 이름 | `backend-dev-agent` |
| `JENKINS_DEPLOY_AGENT_WORKDIR` | deploy 작업공간 | `backend-dev-agent` |

`.env`는 secret을 포함하므로 Git에 커밋하지 않습니다. `JENKINS_BUILDER_SECRET`, `JENKINS_DEPLOY_AGENT_SECRET`은 직접 정하는 비밀번호가 아니라 Jenkins UI에서 node 생성 후 표시되는 값입니다.

## 실행

controller:

```bash
cd jenkins
sh install-jenkins.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-jenkins-controller.yml up -d --build
```

builder agent:

```bash
cd jenkins
sh install-jenkins-builder.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-jenkins-builder-agent.yml up -d --build
```

deploy agent:

```bash
cd jenkins
sh install-jenkins-agent.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-jenkins-deploy-agent.yml up -d --build
```

## 노드/라벨 배치

**노드는 프로젝트나 환경마다 늘리지 않고, 호스트당 하나를 두고 라벨을 여러 개 붙입니다.** 라벨은 "이 노드가 무엇을 할 수 있는가"를 나타내므로, 같은 호스트에 배포하는 파이프라인이 늘어나도 라벨만 추가하면 됩니다. 노드를 쪼개면 컨테이너와 워크스페이스가 그만큼 늘고 메모리만 더 씁니다.

| Jenkins 노드명 | 실제 서버 | Jenkins 라벨 | 역할 | 상태 |
| --- | --- | --- | --- | --- |
| `jenkins-builder-agent` | ollama-01 (`192.168.0.10`) | `builder` `builder-backend` `builder-frontend` | Gradle build/test, Next.js install/build | 기동 중 — **`builder-frontend` 라벨 추가 필요** |
| `backend-dev-agent` | main-server (`192.168.0.11`) | `deploy-backend-dev` `deploy-frontend-dev` | dev compose 배포 (백엔드 + 프론트) | 기동 중 — **`deploy-frontend-dev` 라벨 추가 필요** |
| `backend-prod-agent` | backend-1 (`192.168.0.13`) | `deploy-backend-prod` `deploy-frontend-prod` | prod compose 배포 (백엔드 + 프론트) | **미기동 — 컨테이너 추가 필요** |

즉 **새로 띄워야 하는 컨테이너는 `backend-prod-agent` 하나**이고, 나머지는 Jenkins UI 에서 기존 노드의 라벨 문자열만 고치면 됩니다.

- **빌드**: `jenkins-builder-agent` 이미지에 이미 Node.js 22 와 `pnpm` 이 들어 있습니다(`jenkins-builder-agent.Dockerfile`). 프론트 전용 빌더를 새로 띄우면 pnpm/gradle 캐시 볼륨이 분리되어 첫 빌드가 매번 느려집니다.
- **배포**: deploy agent 가 하는 일은 `rsync` + `docker compose up` + health check 입니다. 백엔드용이든 프론트용이든 필요한 것이 같아서(Docker socket, 해당 호스트의 홈 디렉터리) 노드를 나눌 이유가 없습니다.

> **executor 수를 2 이상으로 올려두십시오.** 한 노드가 백엔드와 프론트 배포를 함께 받으므로 executor 가 1 이면 한쪽이 끝날 때까지 다른 쪽이 큐에서 대기합니다. 배포 자체는 파이프라인의 `lock` 으로 이미 직렬화되어 있으니(`backend-1-deploy`, `frontend-deploy`) executor 를 늘려도 같은 대상에 동시 배포가 나가지 않습니다.

> **아키텍처 주의** — 빌더가 도는 ollama-01 은 x86_64(Ryzen 7 8845HS)이고, 배포 대상 main-server / backend-1 / storage 는 모두 aarch64 입니다. 백엔드는 JAR 이라 무관하지만, 프론트는 빌더에서 만든 `.next/standalone` 을 arm64 호스트에서 실행합니다. 현재 프론트 의존성에는 네이티브 모듈이 없어 문제가 없고, 파이프라인이 번들에 `*.node` 바이너리가 섞이면 빌드를 UNSTABLE 로 표시해 알려줍니다. 그 경고가 뜨면 `builder-frontend` 라벨을 arm64 노드로 옮겨야 합니다.

### IaC 로 관리되는 범위

이 디렉터리가 커버하는 것과 그렇지 않은 것이 나뉩니다. 헷갈리면 "왜 코드에 라벨이 없지" 하고 찾게 됩니다.

| 항목 | 관리 방식 |
| --- | --- |
| agent 컨테이너(이미지·볼륨·환경변수·실행) | **IaC** — `docker-compose-jenkins-*.yml` + `.env` + `install-*.sh` |
| agent 이름 / 워크디렉터리 / compose project 이름 | **IaC** — `.env` 의 `JENKINS_*` 값 |
| Jenkins **노드 생성** | Jenkins UI 수작업 |
| Jenkins **노드 라벨** | Jenkins UI 수작업 |
| 노드 secret | Jenkins UI 에서 노드 생성 후 발급된 값을 `.env` 에 붙여넣기 |
| 잡(멀티브랜치 파이프라인) 정의 | 애플리케이션 레포의 `Jenkinsfile-*` (파라미터·게이트는 코드) |
| 잡 생성 자체 | Jenkins UI 수작업 |

inbound agent 방식이라 **컨트롤러에 노드가 먼저 있어야 컨테이너가 접속할 수 있습니다.** 그래서 순서는 항상 `Jenkins UI 에서 노드 생성(라벨 지정) → secret 복사 → .env 기입 → install 스크립트`입니다.

노드와 잡까지 코드로 관리하려면 `configuration-as-code`(JCasC) + `job-dsl` 플러그인을 도입해 컨트롤러에 `CASC_JENKINS_CONFIG` 를 주입하는 방식이 있습니다. 지금은 도입하지 않았습니다(controller Dockerfile 에 플러그인 설치 단계가 없습니다). 노드가 3개뿐이라 관리 비용보다 도입 비용이 큽니다. **그래서 위 노드/라벨 표가 사실상의 정본입니다 — 라벨을 바꾸면 이 표를 함께 갱신합니다.**

같은 deploy compose를 여러 번 쓰려면 각 agent별 `.env`에서 아래 값을 다르게 둡니다.

```env
JENKINS_DEPLOY_AGENT_NAME=backend-prod-agent
JENKINS_DEPLOY_AGENT_PROJECT_NAME=backend-prod-agent
JENKINS_DEPLOY_AGENT_CONTAINER_NAME=backend-prod-agent
JENKINS_DEPLOY_AGENT_WORKDIR=backend-prod-agent
```

## Pipeline 예시

```groovy
pipeline {
  agent none

  stages {
    stage('Backend Build') {
      agent { label 'builder-backend' }
      steps {
        sh './gradlew clean test bootJar'
      }
    }

    stage('Backend Dev Deploy') {
      agent { label 'deploy-backend-dev' }
      steps {
        sh 'docker compose pull'
        sh 'docker compose up -d'
      }
    }
  }
}
```

## 점검

Compose 문법 확인:

```bash
docker compose --env-file .env -f docker-compose-jenkins-controller.yml config
docker compose --env-file .env -f docker-compose-jenkins-builder-agent.yml config
docker compose --env-file .env -f docker-compose-jenkins-deploy-agent.yml config
```

로그 확인:

```bash
docker logs -f jenkins-controller
docker logs -f jenkins-builder-agent
docker logs -f backend-dev-agent
```

Docker socket 권한 확인:

```bash
docker exec jenkins-builder-agent id
docker exec jenkins-builder-agent docker ps
```
