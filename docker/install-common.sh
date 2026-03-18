#!/bin/bash
# install-common.sh - Docker 설치 공통 로직
# 지원 버전: Ubuntu 20.04, 22.04, 24.04

set -Eeuo pipefail

SUPPORTED_ARCHES=("amd64" "arm64")
DOCKER_PACKAGES=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
)
LEGACY_DOCKER_PACKAGES=(
  docker.io
  docker-doc
  docker-compose
  docker-compose-v2
  podman-docker
  containerd
  runc
)

log() {
  printf '%s\n' "$1"
}

section() {
  printf '\n[%s] %s\n' "$1" "$2"
}

# 1. 공통 사전 검사 함수
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log "root 권한이 필요합니다."
    exit 1
  fi
}

require_ubuntu() {
  if [[ ! -r /etc/os-release ]]; then
    log "/etc/os-release 파일을 읽을 수 없습니다."
    exit 1
  fi

  if ! grep -qi '^ID=ubuntu' /etc/os-release; then
    log "이 스크립트는 Ubuntu 전용입니다."
    exit 1
  fi
}

# 2. 시스템 정보 조회 함수
get_architecture() {
  dpkg --print-architecture
}

get_ubuntu_version() {
  lsb_release -rs 2>/dev/null || awk -F'"' '/^VERSION_ID=/{print $2}' /etc/os-release
}

get_ubuntu_codename() {
  . /etc/os-release
  printf '%s\n' "${VERSION_CODENAME}"
}

# 3. 아키텍처 검증 함수
validate_architecture() {
  local expected_arch="$1"
  local actual_arch

  actual_arch="$(get_architecture)"
  if [[ "${actual_arch}" != "${expected_arch}" ]]; then
    log "이 스크립트는 ${expected_arch} 아키텍처 전용입니다."
    log "현재 아키텍처: ${actual_arch}"
    exit 1
  fi
}

validate_supported_architecture() {
  local actual_arch
  actual_arch="$(get_architecture)"

  for arch in "${SUPPORTED_ARCHES[@]}"; do
    if [[ "${actual_arch}" == "${arch}" ]]; then
      return 0
    fi
  done

  log "지원하지 않는 아키텍처입니다: ${actual_arch}"
  log "지원 아키텍처: ${SUPPORTED_ARCHES[*]}"
  exit 1
}

# 4. 설치 시작 배너 출력
print_install_banner() {
  local title="$1"
  local arch="$2"

  log "========================================="
  log "${title}"
  log "========================================="
  log "Ubuntu 버전: $(get_ubuntu_version)"
  log "아키텍처: ${arch}"
}

# 5. 기존 Docker 패키지 제거
remove_legacy_packages() {
  section "1/6" "기존 Docker 패키지 제거..."

  for pkg in "${LEGACY_DOCKER_PACKAGES[@]}"; do
    apt-get remove -y "${pkg}" >/dev/null 2>&1 || true
  done

  log "기존 패키지 제거 완료"
}

# 6. 필수 패키지 설치
install_prerequisites() {
  section "2/6" "필수 패키지 설치..."

  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release

  log "필수 패키지 설치 완료"
}

# 7. Docker 저장소 및 GPG 키 설정
configure_docker_repository() {
  local arch="$1"
  local codename

  codename="$(get_ubuntu_codename)"

  section "3/6" "Docker GPG 키 추가..."
  rm -f /etc/apt/keyrings/docker.gpg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  log "GPG 키 추가 완료"

  section "4/6" "Docker APT 저장소 추가..."
  log "아키텍처: ${arch}"
  log "코드네임: ${codename}"
  cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable
EOF
  log "저장소 추가 완료"
}

# 8. Docker Engine 설치
install_docker_packages() {
  section "5/6" "Docker Engine 설치..."

  apt-get update
  apt-get install -y "${DOCKER_PACKAGES[@]}"

  log "Docker Engine 설치 완료"
}

# 9. Docker 서비스 활성화 및 시작
enable_docker_services() {
  section "6/6" "Docker 서비스 설정..."

  systemctl enable docker
  systemctl enable containerd
  systemctl start docker

  log "Docker 서비스 시작 완료"
}

# 10. 설치 결과 확인
verify_installation() {
  log ""
  log "========================================="
  log "설치 확인"
  log "========================================="
  log ""
  log "--- Docker 버전 ---"
  docker --version
  log ""
  log "--- Docker Compose 버전 ---"
  docker compose version
  log ""
  log "--- Docker 서비스 상태 ---"
  systemctl is-active docker
}

# 11. 설치 후 안내 메시지
print_post_install_message() {
  log ""
  log "========================================="
  log "Docker 설치 완료!"
  log "========================================="
  log ""
  log "다음 단계:"
  log "  1. 현재 사용자를 docker 그룹에 추가:"
  log "     sudo ./setup-docker-user.sh"
  log ""
  log "  2. 그룹 변경 적용 (재로그인 또는):"
  log "     newgrp docker"
  log ""
  log "  3. docker 명령 테스트:"
  log "     docker ps"
}

# 12. Docker 설치 전체 실행
run_install() {
  local arch="$1"

  require_root
  require_ubuntu
  validate_architecture "${arch}"
  print_install_banner "Docker Engine 설치 스크립트" "${arch}"
  remove_legacy_packages
  install_prerequisites
  configure_docker_repository "${arch}"
  install_docker_packages
  enable_docker_services
  verify_installation
  print_post_install_message
}
