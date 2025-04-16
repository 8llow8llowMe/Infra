#!/bin/bash

LOG_FILE="/var/log/jenkins-entrypoint.log"
touch "$LOG_FILE"

echo "[$(date)] docker.sock의 GID를 동기화 시작합니다." | tee -a "$LOG_FILE"

# docker.sock의 GID 동기화
SOCK="/var/run/docker.sock"
if [ -S "$SOCK" ]; then
    GID=$(stat -c '%g' "$SOCK")
    groupadd -for -g "$GID" docker
    usermod -aG docker jenkins
    echo "[$(date)] [INFO] jenkins 사용자를 docker 그룹에 추가했습니다. (GID=$GID)" | tee -a "$LOG_FILE"
else
    echo "[$(date)] [WARN] docker.sock이 존재하지 않습니다. (/var/run/docker.sock)" | tee -a "$LOG_FILE"
fi

# ENTRYPOINT 작동 확인용 테스트 파일 생성
touch /tmp/jenkins-entrypoint-test
echo "[$(date)] [INFO] ENTRYPOINT 실행 완료" | tee -a "$LOG_FILE"

# 기존 entrypoint로 넘어감
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
