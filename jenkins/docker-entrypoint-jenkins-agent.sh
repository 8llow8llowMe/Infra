#!/bin/bash
# Jenkins Agent Entrypoint Script
# - docker.sock의 "GID"를 기준으로 정확히 그룹 매칭
# - 그룹이름이 달라도 동작 (없으면 해당 GID로 새 그룹 생성)
# - 실행 시점에 sg로 보조그룹을 강제 적용

set -euo pipefail
LOG_FILE="/tmp/jenkins-agent-entrypoint.log"
echo "[$(date)] INIT start" | tee -a "$LOG_FILE"

# 1) docker.sock 점검 및 GID 추출
SOCK="/var/run/docker.sock"
if [ ! -S "$SOCK" ]; then
  echo "[$(date)] WARN: $SOCK not found" | tee -a "$LOG_FILE"
else
  SOCK_GID="$(stat -c '%g' "$SOCK")"
  echo "[$(date)] INFO: sock gid=$SOCK_GID" | tee -a "$LOG_FILE"

  # 2) 해당 GID에 대응되는 그룹명 탐색 (없으면 생성)
  EXISTING_GRP="$(getent group "$SOCK_GID" | cut -d: -f1 || true)"
  if [ -z "$EXISTING_GRP" ]; then
    # 이미 docker라는 이름이 있으면 충돌 피해서 별도 이름 사용
    GRP_NAME="dockersock"
    if getent group "$GRP_NAME" >/dev/null 2>&1; then
      # 동일 이름이 있으면 GID를 붙여 충돌 회피
      GRP_NAME="dockersock_$SOCK_GID"
    fi
    groupadd -g "$SOCK_GID" "$GRP_NAME"
    echo "[$(date)] INFO: created group $GRP_NAME (gid=$SOCK_GID)" | tee -a "$LOG_FILE"
  else
    GRP_NAME="$EXISTING_GRP"
    echo "[$(date)] INFO: found group $GRP_NAME (gid=$SOCK_GID)" | tee -a "$LOG_FILE"
  fi

  # 3) jenkins를 해당 그룹에 추가
  usermod -aG "$GRP_NAME" jenkins
  echo "[$(date)] INFO: added jenkins to group $GRP_NAME" | tee -a "$LOG_FILE"
fi

# 4) 작업 디렉토리 권한
AGENT_DIR="/home/jenkins/agent"
mkdir -p "$AGENT_DIR"
chown -R jenkins:jenkins "$AGENT_DIR"
chmod -R 755 "$AGENT_DIR"

# 5) Java PATH
export JAVA_HOME=/opt/java/openjdk21
export PATH="$JAVA_HOME/bin:$PATH"

# 6) 상태 로그
echo "[$(date)] INFO: id(jenkins) before exec:" | tee -a "$LOG_FILE"
su -s /bin/bash -c "id && groups" jenkins | tee -a "$LOG_FILE"

# 7) 실행
# - sg <그룹>로 보조그룹을 강제 적용한 상태에서 gosu로 UID/GID를 jenkins로 전환
# - docker.sock이 없을 수도 있으니, 없으면 sg 없이 바로 실행
if [ -S "$SOCK" ]; then
  exec sg "$GRP_NAME" -c 'exec gosu jenkins /usr/local/bin/jenkins-agent -url "$JENKINS_URL" -secret "$JENKINS_AGENT_SECRET" -workDir "/home/jenkins/agent"'
else
  exec gosu jenkins /usr/local/bin/jenkins-agent -url "$JENKINS_URL" -secret "$JENKINS_AGENT_SECRET" -workDir "/home/jenkins/agent"
fi
