#!/bin/bash
set -e

LOG_FILE="/tmp/jenkins-entrypoint.log"
touch "$LOG_FILE"

echo "[$(date)] docker.sock의 GID를 동기화 시작합니다." | tee -a "$LOG_FILE"

SOCK="/var/run/docker.sock"
if [ -S "$SOCK" ]; then
    GID=$(stat -c '%g' "$SOCK")
    groupadd -for -g "$GID" docker
    usermod -aG docker jenkins
    echo "[$(date)] [INFO] jenkins 사용자를 docker 그룹에 추가했습니다. (GID=$GID)" | tee -a "$LOG_FILE"
else
    echo "[$(date)] [WARN] docker.sock이 존재하지 않습니다." | tee -a "$LOG_FILE"
fi

# Java 환경 설정
export JAVA_HOME=/opt/java/openjdk21
export PATH=$JAVA_HOME/bin:$PATH

echo "[$(date)] [INFO] ENTRYPOINT 실행 완료" | tee -a "$LOG_FILE"

# jenkins 사용자로 전환 + 환경 유지
exec gosu jenkins /usr/local/bin/jenkins.sh "$@"