#!/bin/bash
set -e

LOG_FILE="/tmp/jenkins-agent-entrypoint.log"
touch "$LOG_FILE"

echo "[$(date)] [INIT] Jenkins Agent 시작 중..." | tee -a "$LOG_FILE"

# 1. Docker socket 권한 조정
SOCK="/var/run/docker.sock"
if [ -S "$SOCK" ]; then
    GID=$(stat -c '%g' "$SOCK")
    groupadd -for -g "$GID" docker 2>/dev/null || true
    usermod -aG docker jenkins 2>/dev/null || true
    echo "[$(date)] [INFO] docker.sock 감지됨 → jenkins 그룹 GID=$GID 추가 완료" | tee -a "$LOG_FILE"
else
    echo "[$(date)] [WARN] docker.sock 파일이 존재하지 않습니다. (빌드 시 docker 사용 불가)" | tee -a "$LOG_FILE"
fi

# 2. Java 환경 설정
export JAVA_HOME=/opt/java/openjdk21
export PATH=$JAVA_HOME/bin:$PATH

# 3. 주요 버전 로깅
echo "[$(date)] [INFO] Java 버전: $(java -version 2>&1 | head -n 1)" | tee -a "$LOG_FILE"
echo "[$(date)] [INFO] Node 버전: $(node -v 2>/dev/null || echo 'N/A')" | tee -a "$LOG_FILE"
echo "[$(date)] [INFO] Yarn 버전: $(yarn -v 2>/dev/null || echo 'N/A')" | tee -a "$LOG_FILE"
echo "[$(date)] [INFO] Docker 버전: $(docker --version 2>/dev/null || echo 'N/A')" | tee -a "$LOG_FILE"
echo "[$(date)] [INFO] Compose 버전: $(docker compose version 2>/dev/null || echo 'N/A')" | tee -a "$LOG_FILE"

echo "[$(date)] [READY] Jenkins Agent ENTRYPOINT 초기화 완료" | tee -a "$LOG_FILE"

# 4. Jenkins Agent 실행
exec /usr/local/bin/jenkins-agent "$@"
