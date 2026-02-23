#!/bin/bash
# setup-docker-user.sh - 현재 사용자를 docker 그룹에 추가
# sudo 없이 docker 명령을 실행할 수 있게 함

set -e

echo "========================================="
echo "Docker 사용자 설정"
echo "========================================="
echo ""

# 현재 사용자 확인
CURRENT_USER="${SUDO_USER:-$USER}"

if [ "$CURRENT_USER" = "root" ]; then
    echo "root 사용자는 이미 docker 접근 권한이 있습니다."
    exit 0
fi

echo "대상 사용자: $CURRENT_USER"

# docker 그룹 존재 확인
if ! getent group docker > /dev/null 2>&1; then
    echo "docker 그룹이 없습니다. Docker가 설치되어 있는지 확인하세요."
    exit 1
fi

# 이미 그룹에 있는지 확인
if groups "$CURRENT_USER" | grep -q '\bdocker\b'; then
    echo "$CURRENT_USER 사용자는 이미 docker 그룹에 속해 있습니다."
else
    # docker 그룹에 추가
    usermod -aG docker "$CURRENT_USER"
    echo "$CURRENT_USER 사용자를 docker 그룹에 추가했습니다."
fi

echo ""
echo "========================================="
echo "설정 완료!"
echo "========================================="
echo ""
echo "변경사항을 적용하려면:"
echo ""
echo "  방법 1: 재로그인"
echo "    exit 후 다시 로그인"
echo ""
echo "  방법 2: newgrp 사용 (현재 세션만)"
echo "    newgrp docker"
echo ""
echo "적용 후 테스트:"
echo "  docker ps"
echo ""
