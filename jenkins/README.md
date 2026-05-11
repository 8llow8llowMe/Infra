# Jenkins 운영 가이드

이 디렉터리는 미니PC에서 Jenkins controller와 builder agent를 운영하기 위한 IaC 구성입니다.

- `jenkins-controller`: Jenkins Web UI, job 관리, agent 연결 관리 담당
- `jenkins-builder-agent`: 미니PC에서 Gradle, Node, Docker build 담당
- `jenkins-deploy-agent`: backend-1 같은 원격 서버에서 배포만 담당

controller는 빌드를 직접 수행하지 않도록 Jenkins UI에서 executor 수를 `0`으로 설정하는 것을 권장합니다.

---

## 권장 구성

```text
mini PC
├── jenkins-controller      # Web UI, pipeline 관리
└── jenkins-builder-agent   # build 전용 agent, label: builder

backend-1 / raspberrypi / storage
└── jenkins-deploy-agent    # deploy 전용 agent, label: deploy-target
```

무거운 빌드는 미니PC가 처리하고, 라즈베리파이와 백엔드 서버는 자기 서버의 Docker Compose 배포만 처리합니다.

---

## 파일 구조

```text
jenkins/
├── docker-compose-jenkins.yml        # 미니PC controller + builder agent
├── docker-compose-jenkins-agent.yml  # 원격 서버 deploy agent
├── jenkins.Dockerfile                # Jenkins controller 이미지
├── jenkins-agent.Dockerfile          # Jenkins agent 공통 이미지
├── docker-entrypoint-jenkins.sh       # controller 시작 스크립트
├── docker-entrypoint-jenkins-agent.sh # agent 시작 스크립트
├── install-jenkins.sh                 # controller 실행 스크립트
├── install-jenkins-builder.sh         # builder agent 실행 스크립트
├── install-jenkins-agent.sh           # 원격 deploy agent 실행 스크립트
├── .env.example                      # 환경변수 예시
└── README.md
```

실행 후 생성되는 로컬 데이터:

- `jenkins-home/`: Jenkins controller 데이터
- `jenkins-builder-agent/`: 미니PC builder agent 작업공간
- `jenkins-deploy-agent/`: 원격 deploy agent 작업공간
- `jenkins-builder-agent-*` Docker volume: Gradle/npm/pnpm 캐시

---

## 환경변수 설정

이 구성은 compose 파일 안에 기본값을 두지 않습니다. 실행 전에 `.env`를 반드시 준비해야 합니다.

```bash
cd jenkins
cp .env.example .env
```

미니PC의 `docker-compose-jenkins.yml`에서 사용하는 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `JENKINS_WEB_PORT` | Jenkins Web UI 외부 포트 | `49999` |
| `JENKINS_AGENT_PORT` | inbound agent 연결 포트 | `50000` |
| `JENKINS_URL` | agent가 접근할 controller 주소 | `http://<ai-host-private-ip>:49999` |
| `JENKINS_CONTROLLER_JAVA_OPTS` | controller JVM 옵션 | `"-Xms512m -Xmx2048m -Duser.timezone=Asia/Seoul"` |
| `JENKINS_OPTS` | Jenkins 실행 옵션, 없으면 빈 값 | 빈 값 가능 |
| `TZ` | 컨테이너 타임존 | `Asia/Seoul` |
| `JENKINS_BUILDER_NAME` | Jenkins UI에 등록한 builder node 이름 | `ai-host-builder` |
| `JENKINS_BUILDER_SECRET` | builder node 생성 후 Jenkins가 발급한 secret | Jenkins UI 발급값 |

원격 서버의 `docker-compose-jenkins-agent.yml`에서 사용하는 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `JENKINS_URL` | 원격 agent가 접근할 controller 주소 | `http://<미니PC-IP>:49999` |
| `JENKINS_DEPLOY_AGENT_NAME` | Jenkins UI에 등록한 deploy node 이름 | `backend-1-deploy` |
| `JENKINS_DEPLOY_AGENT_SECRET` | deploy node 생성 후 Jenkins가 발급한 secret | Jenkins UI 발급값 |

주의:

- `.env`는 secret을 포함하므로 Git에 커밋하지 않습니다.
- `.env.example`만 Git에 커밋하고, 실제 값은 서버별 `.env`에서 관리합니다.
- `JENKINS_BUILDER_SECRET`, `JENKINS_DEPLOY_AGENT_SECRET`은 직접 정하는 비밀번호가 아닙니다. Jenkins UI에서 node 생성 후 발급받은 값으로 교체합니다.
- 공백이 있는 값은 `JENKINS_CONTROLLER_JAVA_OPTS="-Xms512m -Xmx2048m -Duser.timezone=Asia/Seoul"`처럼 따옴표로 감쌉니다.
- 호스트 OS 시간대도 KST로 맞추는 것을 권장합니다. 컨테이너 `TZ`와 Jenkins JVM 타임존을 함께 맞추면 로그와 스케줄 시간이 일관됩니다.

---

## 미니PC Jenkins 실행

처음에는 controller만 먼저 실행합니다. builder agent는 Jenkins UI에서 node를 만든 뒤 secret을 `.env`에 넣고 실행합니다.

controller 실행:

```bash
cd jenkins
sh install-jenkins.sh
```

직접 실행:

```bash
cd jenkins
docker compose --env-file .env -f docker-compose-jenkins.yml up -d --build jenkins-controller
```

상태 확인:

```bash
docker compose --env-file .env -f docker-compose-jenkins.yml ps
docker logs -f jenkins-controller
```

중지:

```bash
docker compose --env-file .env -f docker-compose-jenkins.yml down
```

builder agent 실행:

1. Jenkins UI에서 `ai-host-builder` node 생성
2. 발급된 secret을 `.env`의 `JENKINS_BUILDER_SECRET`에 입력
3. builder agent 실행

```bash
cd jenkins
sh install-jenkins-builder.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-jenkins.yml up -d --build jenkins-builder-agent
docker logs -f jenkins-builder-agent
```

---

## 원격 Deploy Agent 실행

backend-1 같은 배포 대상 서버에서는 같은 폴더의 `.env`에 deploy agent 값을 넣고 실행합니다.

```bash
cd jenkins
sh install-jenkins-agent.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-jenkins-agent.yml up -d --build
```

상태 확인:

```bash
docker logs -f jenkins-deploy-agent
```

---

## Jenkins 초기 접속

Web UI 예시:

```text
http://<미니PC-IP>:49999
```

초기 관리자 비밀번호 확인:

```bash
docker exec jenkins-controller cat /var/jenkins_home/secrets/initialAdminPassword
```

권장 초기 설정:

- 관리자 계정 생성
- 필요한 플러그인 설치
- Jenkins URL 설정
- controller executor 수를 `0`으로 설정
- 빌드는 `builder` 라벨 agent에서만 실행

추천 플러그인:

- Pipeline
- Git
- Docker Pipeline
- Credentials Binding
- HashiCorp Vault Plugin
- Blue Ocean 또는 Pipeline Stage View

Vault를 먼저 구성했다면 Jenkins credential에 다음 값을 등록합니다.

| Credential ID | 종류 | 값 |
| --- | --- | --- |
| `vault-jenkins-role-id` | Secret text | `jenkins-bosspickseoul` AppRole role_id |
| `vault-jenkins-secret-id` | Secret text | `jenkins-bosspickseoul` AppRole secret_id |

Vault 주소는 Jenkins 전역 설정이나 pipeline 환경변수에서 사용합니다.

```text
VAULT_ADDR=http://<ai-host-private-ip>:8200
```

---

## Builder Agent 등록

Jenkins UI에서 node를 먼저 만듭니다.

1. Manage Jenkins -> Nodes -> New Node
2. Name: `ai-host-builder`
3. Type: Permanent Agent
4. Remote root directory: `/home/jenkins/agent`
5. Labels: `builder`
6. Usage: Only build jobs with label expressions matching this node
7. Launch method: Launch agent by connecting it to the controller

생성 후 표시되는 secret을 `.env`의 `JENKINS_BUILDER_SECRET`에 반영합니다.

그 다음 builder agent를 실행합니다.

```bash
sh install-jenkins-builder.sh
```

연결 확인:

```bash
docker logs -f jenkins-builder-agent
```

Jenkins UI의 node 상태가 online이면 정상입니다.

---

## Deploy Agent 등록

원격 서버별로 deploy node를 만듭니다.

권장 label:

- backend-1: `deploy-target backend-1`
- raspberrypi: `deploy-target raspberrypi`
- storage: `deploy-target storage`

deploy agent는 빌드하지 않고 아래 작업만 수행합니다.

- artifact 다운로드 또는 `unstash`
- Vault secret 주입
- `docker compose pull`
- `docker compose up -d`
- 배포 후 health check

---

## Pipeline 예시

```groovy
pipeline {
  agent none

  stages {
    stage('Build') {
      agent { label 'builder' }
      steps {
        sh './gradlew clean bootJar -x test'
        stash includes: '**/build/libs/*.jar', name: 'app-jars'
      }
    }

    stage('Deploy') {
      agent { label 'deploy-target && backend-1' }
      steps {
        unstash 'app-jars'
        sh 'docker compose up -d --build'
      }
    }
  }
}
```

---

## 문제 해결

Compose 문법 확인:

```bash
docker compose --env-file .env -f docker-compose-jenkins.yml config
docker compose --env-file .env -f docker-compose-jenkins-agent.yml config
```

agent가 연결되지 않을 때:

```bash
docker logs -f jenkins-builder-agent
docker logs -f jenkins-deploy-agent
```

확인할 항목:

- `.env`에 필요한 변수가 모두 있는지 확인
- `JENKINS_URL`이 agent에서 접근 가능한 controller 주소인지 확인
- Jenkins UI node 이름과 `JENKINS_BUILDER_NAME` 또는 `JENKINS_DEPLOY_AGENT_NAME`이 같은지 확인
- secret 값이 최신인지 확인
- node label이 pipeline 라벨과 일치하는지 확인

Docker 권한 확인:

```bash
docker exec jenkins-builder-agent id
docker exec jenkins-builder-agent docker ps
```
