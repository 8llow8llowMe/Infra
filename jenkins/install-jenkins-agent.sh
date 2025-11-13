#!/bin/bash
# Jenkins Agent 설치 스크립트
# - .env 기반 Jenkins Agent 자동 빌드 및 실행
# - infra/jenkins-agent 경로 내에서 실행 가능

set -e

# 스크립트가 위치한 절대 경로 계산
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
COMPOSE_FILE="$BASE_DIR/docker-compose-jenkins-agent.yml"
NETWORK_NAME="8llow8llowme-net"

echo "[INFO] Jenkins Agent 설치 시작..."

# 1. 디렉토리 및 필수 파일 확인
cd "$BASE_DIR"

if [ ! -f ".env" ]; then
  echo "[ERROR] .env 파일이 없습니다. Jenkins 환경 변수를 먼저 설정해주세요."
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[ERROR] docker-compose-jenkins-agent.yml 파일이 없습니다."
  exit 1
fi

# 2. Docker 네트워크 확인/생성
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  docker network create "$NETWORK_NAME"
  echo "[INFO] Docker 네트워크 생성: $NETWORK_NAME"
else
  echo "[INFO] Docker 네트워크 이미 존재: $NETWORK_NAME"
fi

# 3. Jenkins Agent 빌드 및 실행
echo "[INFO] Jenkins Agent 컨테이너 빌드 및 실행 중..."
docker compose -f "$COMPOSE_FILE" up -d --build

# 4. 실행 확인
sleep 3
if docker ps | grep -q "jenkins-agent"; then
  echo "[SUCCESS] Jenkins Agent가 정상적으로 실행되었습니다."
else
  echo "[ERROR] Jenkins Agent 실행 실패. 로그 확인 필요:"
  docker logs jenkins-agent || true
  exit 1
fi
