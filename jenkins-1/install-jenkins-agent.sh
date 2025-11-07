#!/bin/bash
# Jenkins Agent 설치 스크립트
# - 지정한 서버에 Jenkins Agent 환경 자동 구성
# - Systemd 서비스 등록 포함

set -e

# 색상 정의
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# 로깅 함수
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 파라미터 확인
AGENT_NAME=${1:-"jenkins-agent-$(hostname)"}
JENKINS_URL=${2:-"http://deploy-server:49999"}
JENKINS_SECRET=${3}

if [ -z "$JENKINS_SECRET" ]; then
  log_error "Jenkins Secret이 필요합니다."
  log_info  "사용법: $0 [AGENT_NAME] [JENKINS_URL] [JENKINS_SECRET]"
  exit 1
fi

log_info "Agent Name: $AGENT_NAME"
log_info "Jenkins URL: $JENKINS_URL"

# 필수 명령어 확인
for cmd in docker docker-compose; do
  if ! command -v $cmd &>/dev/null; then
    log_error "$cmd 명령어를 찾을 수 없습니다. 설치 후 다시 시도하세요."
    exit 1
  fi
done

# 디렉토리 생성
WORK_DIR="/opt/jenkins-agent"
log_info "작업 디렉토리 생성: $WORK_DIR"
sudo mkdir -p $WORK_DIR && cd $WORK_DIR

# Agent 구성 파일 복사
log_info "Jenkins Agent 파일 복사..."
sudo cp /path/to/Infra/Jenkins/jenkins-agent.Dockerfile ./jenkins-agent.Dockerfile
sudo cp /path/to/Infra/Jenkins/docker-entrypoint-agent.sh ./docker-entrypoint-agent.sh
sudo cp /path/to/Infra/Jenkins/docker-compose-jenkins-agent.yml ./docker-compose.yml

# 환경 변수 파일 생성
sudo tee .env > /dev/null <<EOF
JENKINS_AGENT_SECRET=$JENKINS_SECRET
JENKINS_AGENT_NAME=$AGENT_NAME
JENKINS_URL=$JENKINS_URL
EOF
log_info ".env 파일 생성 완료"

# Docker 네트워크 확인
docker network create 8llow8llowme-net 2>/dev/null || log_warn "네트워크 이미 존재"

# Agent 컨테이너 빌드 및 실행
log_info "컨테이너 빌드 및 실행..."
sudo docker compose up -d --build

sleep 5
if docker ps | grep -q "$AGENT_NAME"; then
  log_info "Jenkins Agent가 정상적으로 시작되었습니다!"
else
  log_error "Jenkins Agent 시작 실패. 로그 확인 필요:"
  docker logs jenkins-agent || true
  exit 1
fi

# Systemd 서비스 등록
log_info "Systemd 서비스 등록..."
sudo tee /etc/systemd/system/jenkins-agent.service > /dev/null <<EOF
[Unit]
Description=Jenkins Agent Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$WORK_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent.service
log_info "Jenkins Agent 설치 완료"
