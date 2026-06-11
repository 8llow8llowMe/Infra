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
├── jenkins-builder-agent           # label: builder builder-backend
└── frontend-builder-agent          # label: builder-frontend, 필요 시 추가

deploy 서버
├── backend-dev-agent               # label: deploy-backend-dev
├── backend-prod-agent              # label: deploy-backend-prod
├── frontend-dev-agent              # label: deploy-frontend-dev
└── frontend-prod-agent             # label: deploy-frontend-prod
```

무거운 build/test는 builder agent가 처리하고, deploy agent는 pull/restart/health check 같은 배포 작업만 처리합니다.

## Compose `name` 사용 기준

Compose 파일 최상단의 `name:`은 Docker Compose project name입니다. Docker Compose는 이 값을 기준으로 기본 컨테이너, 네트워크, 볼륨 이름을 묶습니다.

예를 들어:

```yaml
name: backend-dev-agent
```

이면 Compose가 자동 생성하는 리소스가 대체로 `backend-dev-agent_default`, `backend-dev-agent_<volume>`처럼 이 project 아래에 묶입니다.

이 구성에서 `name:`을 쓰는 이유는 같은 서버에서 여러 agent를 동시에 띄우기 위해서입니다. `backend-dev-agent`, `backend-prod-agent`, `frontend-dev-agent`가 같은 compose 파일을 쓰더라도 project name이 다르면 서로 다른 배포 단위로 관리할 수 있습니다.

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

## 노드/라벨 예시

| Jenkins 노드명 | 실제 서버 | Jenkins 라벨 | 역할 |
| --- | --- | --- | --- |
| `jenkins-builder-agent` | `192.168.0.10` | `builder builder-backend` | Gradle build/test |
| `frontend-builder-agent` | 빌드 서버 또는 Jenkins 서버 | `builder-frontend` | Next.js install/build |
| `backend-dev-agent` | deploy 서버 | `deploy-backend-dev` | 백엔드 dev compose 배포 |
| `backend-prod-agent` | deploy 서버 | `deploy-backend-prod` | 백엔드 prod compose 배포 |
| `frontend-dev-agent` | deploy 서버 | `deploy-frontend-dev` | Next.js dev/prod app 배포 |
| `frontend-prod-agent` | deploy 서버 | `deploy-frontend-prod` | 프론트 운영 배포 |

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
