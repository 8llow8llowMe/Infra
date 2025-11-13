#!/bin/bash
# Jenkins Master 설치 자동화 스크립트
# - 볼륨 디렉토리 생성
# - Docker Compose 빌드 및 실행
# - Jenkins 초기 설정 검증 및 UpdateCenter 적용

set -e

JENKINS_DIR="./jenkins"
CONFIG_FILE="$JENKINS_DIR/hudson.model.UpdateCenter.xml"
UPDATE_CENTER_DIR="./update-center-rootCAs"
COMPOSE_FILE="docker-compose-jenkins.yml"

# 1. Jenkins 볼륨 디렉토리 확인
if [ ! -d "$JENKINS_DIR" ]; then
    mkdir -p "$JENKINS_DIR"
    echo "[INFO] Jenkins 데이터 디렉토리 생성: $JENKINS_DIR"
fi

# 2. Docker Compose 실행
echo "[INFO] Jenkins 컨테이너 빌드 및 실행 중..."
docker compose -f "$COMPOSE_FILE" up -d --build

# 3. 초기 부팅 대기
echo "[INFO] Jenkins 초기화 대기 중 (약 60초)..."
sleep 60

# 4. UpdateCenter 설정 수정
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[WARN] Jenkins 설정 파일이 아직 생성되지 않았습니다."
    docker logs jenkins
    exit 1
fi

mkdir -p "$UPDATE_CENTER_DIR"
wget -q https://cdn.jsdelivr.net/gh/lework/jenkins-update-center/rootCA/update-center.crt -O "$UPDATE_CENTER_DIR/update-center.crt"

# Jenkins UpdateCenter 주소를 Tencent Mirror로 교체
sed -i 's#https://updates.jenkins.io/update-center.json#https://raw.githubusercontent.com/lework/jenkins-update-center/master/updates/tencent/update-center.json#' "$CONFIG_FILE"
echo "[INFO] UpdateCenter Mirror 설정 완료"

# 5. Jenkins 재시작
docker restart jenkins
echo "[INFO] Jenkins Master 설정 완료"
