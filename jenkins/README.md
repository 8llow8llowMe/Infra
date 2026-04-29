# Jenkins 운영 가이드

이 디렉터리는 미니PC에서 Jenkins controller와 builder agent를 함께 운영하기 위한 IaC 구성입니다.

controller는 Jenkins UI와 inbound agent 포트를 열고, builder agent는 Gradle/Node/Docker 빌드를 담당합니다. 실제 배포 대상 서버의 deploy agent는 별도 서버에서 운영하며, 이 문서에서는 예시만 다룹니다.

---

## 디렉터리 구조

```text
jenkins/
├── docker-compose-jenkins.yml        # controller + builder agent 실행 정의
├── jenkins.Dockerfile                # Jenkins controller 이미지
├── jenkins-agent.Dockerfile          # Jenkins builder agent 이미지
├── docker-entrypoint-jenkins.sh       # controller 시작 전 권한 정리
├── docker-entrypoint-jenkins-agent.sh # agent 시작 전 권한 정리
├── .env.example                      # 환경변수 예시
└── README.md                         # 운영 가이드
```

런타임 데이터는 실행 후 아래 경로에 생성됩니다.

- `jenkins-home/`: Jenkins controller 데이터
- `jenkins-builder/`: builder agent 작업공간
- Docker named volume: Gradle/npm/pnpm 캐시

---

## 초기 설정

`.env.example`을 기준으로 `.env`를 준비합니다.

```bash
cd jenkins
cp .env.example .env
```

처음 실행 전에는 `JENKINS_BUILDER_SECRET`을 임시값으로 둬도 됩니다. Jenkins UI에서 builder node를 만든 뒤 발급된 secret으로 교체합니다.

---

## 실행

```bash
cd jenkins
docker compose -f docker-compose-jenkins.yml up -d --build
```

상태 확인:

```bash
docker compose -f docker-compose-jenkins.yml ps
docker logs -f jenkins-controller
docker logs -f jenkins-builder
```

중지:

```bash
docker compose -f docker-compose-jenkins.yml down
```

이미지 변경 반영:

```bash
docker compose -f docker-compose-jenkins.yml up -d --build
```

---

## Jenkins 초기 접속

웹 UI 예시:

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

---

## Builder Agent 등록

Jenkins UI에서 node를 먼저 만듭니다.

1. Manage Jenkins -> Nodes -> New Node
2. Name: `minipc-builder`
3. Type: Permanent Agent
4. Remote root directory: `/home/jenkins/agent`
5. Labels: `builder`
6. Usage: Only build jobs with label expressions matching this node
7. Launch method: Launch agent by connecting it to the controller

생성 후 표시되는 secret을 `.env`에 반영합니다.

```env
JENKINS_BUILDER_NAME=minipc-builder
JENKINS_BUILDER_SECRET=<jenkins-ui-generated-secret>
```

반영:

```bash
docker compose -f docker-compose-jenkins.yml up -d --build jenkins-builder
```

---

## Pipeline 라벨 예시

빌드 단계는 미니PC builder에서 실행합니다.

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
      agent { label 'deploy-target' }
      steps {
        unstash 'app-jars'
        sh 'docker compose up -d --build'
      }
    }
  }
}
```

`deploy-target` agent는 backend-1 같은 실제 배포 대상 서버에 별도로 구성합니다.

---

## Docker 권한

controller와 builder는 호스트의 `/var/run/docker.sock`을 사용합니다. entrypoint가 컨테이너 시작 시 docker socket의 GID를 확인하고 `jenkins` 사용자를 해당 그룹에 추가합니다.

확인:

```bash
docker exec jenkins-builder id
docker exec jenkins-builder docker ps
```

---

## 백업과 복구

백업 대상:

- `jenkins-home/`
- `.env`

백업 예시:

```bash
tar czf jenkins-backup-$(date +%Y%m%d).tar.gz jenkins-home .env
```

복구 예시:

```bash
tar xzf jenkins-backup-YYYYMMDD.tar.gz
docker compose -f docker-compose-jenkins.yml up -d --build
```

---

## 문제 해결

Compose 문법 확인:

```bash
docker compose -f docker-compose-jenkins.yml config
```

agent가 연결되지 않을 때:

```bash
docker logs -f jenkins-builder
```

확인할 항목:

- `JENKINS_URL`이 controller에서 접근 가능한 주소인지 확인
- `JENKINS_BUILDER_NAME`이 Jenkins UI node 이름과 같은지 확인
- `JENKINS_BUILDER_SECRET`이 최신 secret인지 확인
- node label에 `builder`가 들어 있는지 확인

Docker 명령이 실패할 때:

```bash
docker exec jenkins-builder ls -l /var/run/docker.sock
docker exec jenkins-builder id
```

controller 로그:

```bash
docker logs -f jenkins-controller
```
