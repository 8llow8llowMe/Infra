#!/bin/bash

# Jenkins 볼륨 폴더 확인
JENKINS_DIR="./jenkins"
if [ ! -d "$JENKINS_DIR" ]; then
    mkdir "$JENKINS_DIR"
fi

# Docker Compose 실행
docker-compose -f docker-compose-jenkins.yml up -d --build

# Jenkins 컨테이너 실행 확인 대기
echo "Jenkins 컨테이너가 시작될 때까지 기다립니다..."
sleep 60

# Jenkins 설정 파일 존재 여부 확인
CONFIG_FILE="$JENKINS_DIR/hudson.model.UpdateCenter.xml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Jenkins 설정 파일이 아직 생성되지 않았습니다. Jenkins 컨테이너 상태를 확인하세요:"
    docker logs jenkins
    exit 1
fi

# CA 인증서 저장 디렉토리 생성
UPDATE_CENTER_DIR="./update-center-rootCAs"
if [ ! -d "$UPDATE_CENTER_DIR" ]; then
    mkdir "$UPDATE_CENTER_DIR"
fi

# CA 인증서 다운로드
wget https://cdn.jsdelivr.net/gh/lework/jenkins-update-center/rootCA/update-center.crt -O "$UPDATE_CENTER_DIR/update-center.crt"

# UpdateCenter 주소 수정
sed -i 's#https://updates.jenkins.io/update-center.json#https://raw.githubusercontent.com/lework/jenkins-update-center/master/updates/tencent/update-center.json#' "$CONFIG_FILE"

# Jenkins 재시작
docker restart jenkins
