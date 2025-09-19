#!/bin/bash

# Jenkins Agent 설치 스크립트
# 사용법: ./install-jenkins-agent.sh [AGENT_NAME] [JENKINS_URL] [JENKINS_SECRET]

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 파라미터 확인
AGENT_NAME=${1:-"jenkins-agent-$(hostname)"}
JENKINS_URL=${2:-"http://deploy-server:49999"}
JENKINS_SECRET=${3}

if [ -z "$JENKINS_SECRET" ]; then
    log_error "Jenkins Secret이 필요합니다."
    log_info "사용법: $0 [AGENT_NAME] [JENKINS_URL] [JENKINS_SECRET]"
    log_info "예시: $0 backend-agent http://deploy-server:49999 abc123def456"
    exit 1
fi

log_info "Jenkins Agent 설치를 시작합니다..."
log_info "Agent Name: $AGENT_NAME"
log_info "Jenkins URL: $JENKINS_URL"

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    log_error "Docker가 설치되어 있지 않습니다."
    log_info "Docker를 먼저 설치해주세요."
    exit 1
fi

# Docker Compose 설치 확인
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose가 설치되어 있지 않습니다."
    log_info "Docker Compose를 먼저 설치해주세요."
    exit 1
fi

# 작업 디렉토리 생성
WORK_DIR="/opt/jenkins-agent"
log_info "작업 디렉토리 생성: $WORK_DIR"
sudo mkdir -p $WORK_DIR
cd $WORK_DIR

# Jenkins Agent 파일들 복사
log_info "Jenkins Agent 파일들을 복사합니다..."
sudo cp /path/to/Infra/Jenkins/jenkins-agent.Dockerfile ./jenkins-agent.Dockerfile
sudo cp /path/to/Infra/Jenkins/docker-entrypoint-agent.sh ./docker-entrypoint-agent.sh
sudo cp /path/to/Infra/Jenkins/docker-compose-jenkins-agent.yml ./docker-compose.yml

# 환경 변수 파일 생성
log_info "환경 변수 파일을 생성합니다..."
sudo tee .env > /dev/null <<EOF
JENKINS_AGENT_SECRET=$JENKINS_SECRET
JENKINS_AGENT_NAME=$AGENT_NAME
EOF

# Jenkins Agent 디렉토리 생성
log_info "Jenkins Agent 작업 디렉토리를 생성합니다..."
sudo mkdir -p ./jenkins-agent
sudo chown -R 1000:1000 ./jenkins-agent

# Docker 네트워크 생성 (이미 존재하면 무시)
log_info "Docker 네트워크를 생성합니다..."
docker network create 8llow8llowme-net 2>/dev/null || log_warn "네트워크가 이미 존재합니다."

# Jenkins Agent 컨테이너 빌드 및 실행
log_info "Jenkins Agent 컨테이너를 빌드합니다..."
sudo docker-compose build

log_info "Jenkins Agent 컨테이너를 시작합니다..."
sudo docker-compose up -d

# 컨테이너 상태 확인
sleep 5
if docker ps | grep -q jenkins-agent; then
    log_info "Jenkins Agent가 성공적으로 시작되었습니다!"
    log_info "컨테이너 상태:"
    docker ps | grep jenkins-agent
else
    log_error "Jenkins Agent 시작에 실패했습니다."
    log_info "로그 확인:"
    docker logs jenkins-agent
    exit 1
fi

# 서비스 등록 (systemd)
log_info "systemd 서비스로 등록합니다..."
sudo tee /etc/systemd/system/jenkins-agent.service > /dev/null <<EOF
[Unit]
Description=Jenkins Agent
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$WORK_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent.service

log_info "Jenkins Agent 설치가 완료되었습니다!"
log_info "서비스 관리 명령어:"
log_info "  시작: sudo systemctl start jenkins-agent"
log_info "  중지: sudo systemctl stop jenkins-agent"
log_info "  상태: sudo systemctl status jenkins-agent"
log_info "  로그: docker logs jenkins-agent"