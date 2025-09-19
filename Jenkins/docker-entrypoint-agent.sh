#!/bin/bash
set -e

LOG_FILE="/tmp/jenkins-agent-entrypoint.log"
touch "$LOG_FILE"

echo "[$(date)] Jenkins Agent 시작 중..." | tee -a "$LOG_FILE"

# Docker socket 권한 설정
SOCK="/var/run/docker.sock"
if [ -S "$SOCK" ]; then
    GID=$(stat -c '%g' "$SOCK")
    groupadd -for -g "$GID" docker 2>/dev/null || true
    usermod -aG docker jenkins 2>/dev/null || true
    echo "[$(date)] [INFO] jenkins 사용자를 docker 그룹에 추가했습니다. (GID=$GID)" | tee -a "$LOG_FILE"
else
    echo "[$(date)] [WARN] docker.sock이 존재하지 않습니다." | tee -a "$LOG_FILE"
fi

# Java 환경 설정
export JAVA_HOME=/opt/java/openjdk21
export PATH=$JAVA_HOME/bin:$PATH

echo "[$(date)] [INFO] Jenkins Agent ENTRYPOINT 실행 완료" | tee -a "$LOG_FILE"

# Jenkins Agent 실행
exec /usr/local/bin/jenkins-agent "$@"