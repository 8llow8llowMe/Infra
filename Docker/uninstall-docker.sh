#!/bin/bash
# uninstall-docker.sh - Docker Engine 및 관련 컴포넌트 완전 제거

set -e

echo "========================================="
echo "Docker 제거 스크립트"
echo "========================================="
echo ""

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "root 권한이 필요합니다."
    echo "다음 명령으로 실행하세요: sudo ./uninstall-docker.sh"
    exit 1
fi

echo "다음 항목이 제거됩니다:"
echo "  - Docker Engine, CLI, Compose 플러그인"
echo "  - 컨테이너, 이미지, 볼륨 (선택)"
echo "  - Docker APT 저장소 및 GPG 키"
echo ""
read -p "계속하시겠습니까? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "취소되었습니다."
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# 1. Docker 서비스 중지
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[1/4] Docker 서비스 중지..."
systemctl stop docker.socket 2>/dev/null || true
systemctl stop docker 2>/dev/null || true
echo "완료"

# ═══════════════════════════════════════════════════════════════
# 2. 패키지 제거
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[2/4] Docker 패키지 제거..."

apt-get purge -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    2>/dev/null || true

apt-get remove -y docker.io docker-doc docker-compose 2>/dev/null || true
apt-get autoremove -y

echo "패키지 제거 완료"

# ═══════════════════════════════════════════════════════════════
# 3. 이미지/컨테이너/볼륨 등 삭제 (선택)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[3/4] Docker 데이터 삭제..."

rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg

echo "데이터 삭제 완료"

# ═══════════════════════════════════════════════════════════════
# 4. 정리
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[4/4] APT 캐시 갱신..."
apt-get update

echo ""
echo "========================================="
echo "Docker 제거 완료"
echo "========================================="
echo ""
