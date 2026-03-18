#!/bin/bash
# setup-docker-user.sh - 현재 사용자를 docker 그룹에 추가
# sudo 없이 docker 명령을 실행할 수 있도록 설정

set -Eeuo pipefail

echo "========================================="
echo "Docker 사용자 권한 설정 스크립트"
echo "========================================="
echo ""

# 1. root 권한 확인
if [[ "${EUID}" -ne 0 ]]; then
  printf '%s\n' "root 권한이 필요합니다."
  printf '%s\n' "다음 명령으로 실행하세요: sudo ./setup-docker-user.sh"
  exit 1
fi

# 2. 대상 사용자 확인
CURRENT_USER="${SUDO_USER:-${USER}}"

if [[ -z "${CURRENT_USER}" || "${CURRENT_USER}" == "root" ]]; then
  printf '%s\n' "root 사용자는 이미 Docker 접근 권한이 있습니다."
  exit 0
fi

printf '대상 사용자: %s\n' "${CURRENT_USER}"

# 3. docker 그룹 존재 여부 확인
if ! getent group docker >/dev/null 2>&1; then
  printf '%s\n' "docker 그룹이 존재하지 않습니다. 먼저 Docker를 설치하세요."
  exit 1
fi

# 4. 사용자를 docker 그룹에 추가
if id -nG "${CURRENT_USER}" | tr ' ' '\n' | grep -qx 'docker'; then
  printf '%s\n' "${CURRENT_USER} 사용자는 이미 docker 그룹에 포함되어 있습니다."
else
  usermod -aG docker "${CURRENT_USER}"
  printf '%s\n' "${CURRENT_USER} 사용자를 docker 그룹에 추가했습니다."
fi

# 5. 적용 방법 안내
printf '\n%s\n' "설정 완료 후 아래 둘 중 하나를 수행하세요."
printf '%s\n' "  1. 재로그인"
printf '%s\n' "  2. newgrp docker 실행"
printf '%s\n' "적용 확인 명령: docker ps"
