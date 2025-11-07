#!/bin/bash
# Jenkins Master Entrypoint Script
# - docker.sock GID 자동 동기화 (호스트 Docker 접근용)
# - Jenkins를 jenkins 사용자로 실행

set -e
LOG_FILE="/tmp/jenkins-entrypoint.log"
SOCK="/var/run/docker.sock"

echo "[$(date)] [INFO] Jenkins Entrypoint 시작" | tee -a "$LOG_FILE"

# 1. docker.sock GID 자동 동기화
if [ -S "$SOCK" ]; then
    GID=$(stat -c '%g' "$SOCK")
    groupadd -for -g "$GID" docker
    usermod -aG docker jenkins
    echo "[$(date)] [INFO] docker.sock GID($GID) 동기화 완료" | tee -a "$LOG_FILE"
else
    echo "[$(date)] [WARN] docker.sock 파일이 존재하지 않습니다." | tee -a "$LOG_FILE"
fi

# 2. Java 환경 변수 설정
export JAVA_HOME=/opt/java/openjdk21
export PATH=$JAVA_HOME/bin:$PATH

echo "[$(date)] [INFO] JAVA_HOME=$JAVA_HOME" | tee -a "$LOG_FILE"

# 3. Jenkins 프로세스 실행
echo "[$(date)] [INFO] Jenkins 프로세스 시작" | tee -a "$LOG_FILE"
exec gosu jenkins /usr/local/bin/jenkins.sh "$@"
