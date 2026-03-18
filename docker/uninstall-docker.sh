#!/bin/bash
# uninstall-docker.sh - Docker Engine 및 관련 컴포넌트 완전 제거
# 주의: Docker 데이터와 설정 파일도 함께 삭제

set -Eeuo pipefail

echo "========================================="
echo "Docker 제거 스크립트"
echo "========================================="
echo ""

# 1. root 권한 확인
if [[ "${EUID}" -ne 0 ]]; then
  printf '%s\n' "root 권한이 필요합니다."
  printf '%s\n' "다음 명령으로 실행하세요: sudo ./uninstall-docker.sh"
  exit 1
fi

# 2. 사용자 확인
printf '%s\n' "다음 항목이 제거됩니다."
printf '%s\n' "  - Docker Engine, CLI, Compose 플러그인"
printf '%s\n' "  - Docker 데이터 디렉터리(/var/lib/docker, /var/lib/containerd)"
printf '%s\n' "  - Docker 설정 및 APT 저장소 정보"
read -r -p "계속하시겠습니까? [y/N] " REPLY

if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
  printf '%s\n' "작업이 취소되었습니다."
  exit 0
fi

# 3. Docker 서비스 중지
printf '\n%s\n' "[1/4] Docker 서비스 중지..."
systemctl stop docker.socket >/dev/null 2>&1 || true
systemctl stop docker >/dev/null 2>&1 || true

# 4. Docker 패키지 제거
printf '\n%s\n' "[2/4] Docker 패키지 제거..."
apt-get purge -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin >/dev/null 2>&1 || true
apt-get remove -y docker.io docker-doc docker-compose >/dev/null 2>&1 || true
apt-get autoremove -y

# 5. Docker 데이터 및 저장소 정보 삭제
printf '\n%s\n' "[3/4] Docker 데이터 및 저장소 설정 삭제..."
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg

# 6. APT 캐시 갱신
printf '\n%s\n' "[4/4] APT 캐시 갱신..."
apt-get update

printf '\n%s\n' "Docker 제거가 완료되었습니다."
