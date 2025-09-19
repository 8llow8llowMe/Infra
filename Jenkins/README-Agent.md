# Jenkins Agent 설정 가이드

## 개요
Jenkins Agent는 각 서버(Backend, Web/SSR, Storage)에 설치하여 Jenkins Master의 작업을 분산 처리하는 역할을 합니다.

## 파일 구조
```
Jenkins/
├── jenkins-agent.Dockerfile          # Jenkins Agent용 Dockerfile
├── docker-compose-jenkins-agent.yml  # Jenkins Agent용 docker-compose
├── docker-entrypoint-agent.sh        # Jenkins Agent entrypoint 스크립트
├── install-jenkins-agent.sh          # Jenkins Agent 설치 스크립트
└── README-Agent.md                   # 이 파일
```

## 설치 방법

### 1. Jenkins Master에서 Agent Secret 확인
1. Jenkins Master 웹 UI 접속
2. `Manage Jenkins` → `Manage Nodes and Clouds` → `New Node`
3. Node Name 입력 후 `Permanent Agent` 선택
4. Agent Secret 복사 (나중에 사용)

### 2. 각 서버에 Jenkins Agent 설치

#### Backend 서버
```bash
# Backend 서버에서 실행
./install-jenkins-agent.sh backend-agent http://deploy-server:49999 [JENKINS_SECRET]
```

#### Web/SSR 서버
```bash
# Web/SSR 서버에서 실행
./install-jenkins-agent.sh web-agent http://deploy-server:49999 [JENKINS_SECRET]
```

#### Storage 서버 (MinIO 포함)
```bash
# Storage 서버에서 실행
./install-jenkins-agent.sh storage-agent http://deploy-server:49999 [JENKINS_SECRET]
```

## 환경 변수 설정

### .env 파일 예시
```bash
JENKINS_AGENT_SECRET=your-secret-here
JENKINS_AGENT_NAME=backend-agent
```

## 서비스 관리

### systemd 서비스 명령어
```bash
# 서비스 시작
sudo systemctl start jenkins-agent

# 서비스 중지
sudo systemctl stop jenkins-agent

# 서비스 상태 확인
sudo systemctl status jenkins-agent

# 서비스 자동 시작 설정
sudo systemctl enable jenkins-agent
```

### Docker 컨테이너 관리
```bash
# 컨테이너 상태 확인
docker ps | grep jenkins-agent

# 컨테이너 로그 확인
docker logs jenkins-agent

# 컨테이너 재시작
docker restart jenkins-agent
```

## Jenkins Pipeline에서 Agent 사용

### Pipeline 예시
```groovy
pipeline {
    agent none
    
    stages {
        stage('Backend Build') {
            agent {
                label 'backend-agent'
            }
            steps {
                // Backend 빌드 작업
            }
        }
        
        stage('Web Build') {
            agent {
                label 'web-agent'
            }
            steps {
                // Web/SSR 빌드 작업
            }
        }
        
        stage('Storage Deploy') {
            agent {
                label 'storage-agent'
            }
            steps {
                // MinIO 및 Storage 관련 작업
            }
        }
    }
}
```

## 장점

### 1. 리소스 분산
- Jenkins Master의 부하 감소
- 각 서버의 리소스 활용도 향상

### 2. 병렬 처리
- 여러 작업을 동시에 실행 가능
- 빌드 시간 단축

### 3. 특화된 환경
- 각 서버의 특성에 맞는 환경 구성
- 필요한 도구만 설치하여 가벼운 Agent

### 4. 안정성
- 한 Agent에 문제가 생겨도 다른 Agent는 정상 동작
- Master와 Agent 분리로 장애 격리

## 주의사항

1. **네트워크 연결**: Agent와 Master 간 네트워크 연결이 안정적이어야 함
2. **방화벽 설정**: Jenkins Master 포트(49999, 50000) 접근 허용
3. **리소스 모니터링**: 각 Agent의 리소스 사용량 모니터링 필요
4. **보안**: Agent Secret 관리 주의

## 문제 해결

### Agent 연결 실패
```bash
# 네트워크 연결 확인
ping deploy-server

# 포트 접근 확인
telnet deploy-server 49999
telnet deploy-server 50000

# Agent 로그 확인
docker logs jenkins-agent
```

### Docker 권한 문제
```bash
# Jenkins 사용자를 docker 그룹에 추가
sudo usermod -aG docker jenkins

# Docker 서비스 재시작
sudo systemctl restart docker
```