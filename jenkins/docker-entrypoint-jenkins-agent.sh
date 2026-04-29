#!/usr/bin/env bash
# Docker socket 접근 권한을 준비한 뒤 Jenkins inbound agent를 실행합니다.

set -euo pipefail

SOCK="/var/run/docker.sock"
LOG_FILE="/tmp/jenkins-agent-entrypoint.log"

log() {
  echo "[$(date --iso-8601=seconds)] $*" | tee -a "$LOG_FILE"
}

require_env() {
  local name="$1"
  if [ -z "${!name+x}" ] || [ -z "${!name}" ]; then
    log "ERROR missing required environment variable: $name"
    exit 1
  fi
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

prepare_workdir() {
  mkdir -p "$AGENT_DIR" /home/jenkins/.gradle /home/jenkins/.npm /home/jenkins/.local/share/pnpm
  chown -R jenkins:jenkins "$AGENT_DIR" /home/jenkins/.gradle /home/jenkins/.npm /home/jenkins/.local
}

require_env JENKINS_URL
require_env JENKINS_AGENT_NAME
require_env JENKINS_AGENT_SECRET
require_env JENKINS_AGENT_WORKDIR

AGENT_DIR="$JENKINS_AGENT_WORKDIR"

export JAVA_HOME=/opt/java/openjdk21
export PATH="${JAVA_HOME}/bin:${PATH}"

sync_docker_group
prepare_workdir

log "INFO starting Jenkins agent: ${JENKINS_AGENT_NAME}"

exec gosu jenkins /usr/local/bin/jenkins-agent \
  -url "$JENKINS_URL" \
  -name "$JENKINS_AGENT_NAME" \
  -secret "$JENKINS_AGENT_SECRET" \
  -workDir "$AGENT_DIR"
