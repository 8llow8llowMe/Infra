#!/bin/bash
# install-docker-arm64.sh - Ubuntu 서버(ARM64)에 Docker Engine 및 Docker Compose 설치
# 지원: Ubuntu 20.04, 22.04, 24.04 / 아키텍처: arm64 전용

set -e

echo "========================================="
echo "Docker Engine 설치 스크립트 (ARM64)"
echo "========================================="
echo ""

# ═══════════════════════════════════════════════════════════════
# 사전 검사
# ═══════════════════════════════════════════════════════════════

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "root 권한이 필요합니다."
    echo "다음 명령으로 실행하세요: sudo ./install-docker-arm64.sh"
    exit 1
fi

# Ubuntu 확인
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    echo "이 스크립트는 Ubuntu 전용입니다."
    exit 1
fi

# ARM64 아키텍처 확인
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != "arm64" ]; then
    echo "이 스크립트는 ARM64 전용입니다. 현재 아키텍처: $ARCH"
    echo "일반(amd64) 서버는 install-docker.sh 를 사용하세요."
    exit 1
fi

# Ubuntu 버전 확인
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || grep VERSION_ID /etc/os-release | cut -d'"' -f2)
echo "Ubuntu 버전: $UBUNTU_VERSION"
echo "아키텍처: $ARCH (arm64)"

# ═══════════════════════════════════════════════════════════════
# 1. 기존 Docker 패키지 제거
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[1/6] 기존 Docker 패키지 제거..."

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y $pkg 2>/dev/null || true
done

echo "기존 패키지 제거 완료"

# ═══════════════════════════════════════════════════════════════
# 2. 필수 패키지 설치
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[2/6] 필수 패키지 설치..."

apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "필수 패키지 설치 완료"

# ═══════════════════════════════════════════════════════════════
# 3. Docker 공식 GPG 키 추가
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[3/6] Docker GPG 키 추가..."

rm -f /etc/apt/keyrings/docker.gpg
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "GPG 키 추가 완료"

# ═══════════════════════════════════════════════════════════════
# 4. Docker 저장소 추가 (arm64)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[4/6] Docker APT 저장소 추가 (arm64)..."

CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "코드네임: $CODENAME"

echo \
  "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "저장소 추가 완료"

# ═══════════════════════════════════════════════════════════════
# 5. Docker Engine 설치
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[5/6] Docker Engine 설치..."

apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "Docker Engine 설치 완료"

# ═══════════════════════════════════════════════════════════════
# 6. Docker 서비스 활성화 및 시작
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[6/6] Docker 서비스 설정..."

systemctl enable docker
systemctl enable containerd
systemctl start docker

echo "Docker 서비스 시작 완료"

# ═══════════════════════════════════════════════════════════════
# 설치 확인
# ═══════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "설치 확인"
echo "========================================="

echo ""
echo "--- Docker 버전 ---"
docker --version

echo ""
echo "--- Docker Compose 버전 ---"
docker compose version

echo ""
echo "--- Docker 서비스 상태 ---"
systemctl is-active docker

echo ""
echo "--- Docker 테스트 (hello-world) ---"
docker run --rm hello-world 2>/dev/null | head -5

echo ""
echo "========================================="
echo "Docker 설치 완료! (ARM64)"
echo "========================================="
echo ""
echo "다음 단계:"
echo "  1. 현재 사용자를 docker 그룹에 추가:"
echo "     sudo ./setup-docker-user.sh"
echo "     또는: sudo usermod -aG docker \$USER"
echo ""
echo "  2. 그룹 변경 적용 (재로그인 또는):"
echo "     newgrp docker"
echo ""
echo "  3. docker 명령 테스트:"
echo "     docker ps"
echo ""
