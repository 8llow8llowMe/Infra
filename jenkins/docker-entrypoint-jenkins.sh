#!/usr/bin/env bash
# docker.sock 권한을 맞춘 뒤 Jenkins를 jenkins 사용자로 실행합니다.

set -euo pipefail

SOCK="/var/run/docker.sock"
LOG_FILE="/tmp/jenkins-entrypoint.log"

log() {
  echo "[$(date --iso-8601=seconds)] $*" | tee -a "$LOG_FILE"
}

sync_docker_group() {
  if [ ! -S "$SOCK" ]; then
    log "WARN docker socket not found: $SOCK"
    return
  fi

  local sock_gid group_name
  sock_gid="$(stat -c '%g' "$SOCK")"
  group_name="$(getent group "$sock_gid" | cut -d: -f1 || true)"

  if [ -z "$group_name" ]; then
    group_name="dockersock"
    if getent group "$group_name" >/dev/null 2>&1; then
      group_name="dockersock_${sock_gid}"
    fi
    groupadd -g "$sock_gid" "$group_name"
  fi

  usermod -aG "$group_name" jenkins
  log "INFO docker socket group synced: ${group_name}(${sock_gid})"
}

export JAVA_HOME=/opt/java/openjdk21
export PATH="${JAVA_HOME}/bin:${PATH}"

sync_docker_group
log "INFO starting Jenkins controller"

exec gosu jenkins /usr/local/bin/jenkins.sh "$@"
