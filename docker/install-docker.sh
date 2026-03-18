#!/bin/bash
# install-docker.sh - Ubuntu 서버에 Docker Engine 및 Docker Compose 설치
# 지원 버전: Ubuntu 20.04, 22.04, 24.04

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

echo "========================================="
echo "Docker 설치 진입 스크립트"
echo "========================================="
echo ""

# 1. root 권한 및 Ubuntu 환경 확인
require_root
require_ubuntu

# 2. 지원 아키텍처 확인
validate_supported_architecture

# 3. 현재 CPU 아키텍처에 맞는 설치 스크립트 실행
case "$(get_architecture)" in
  amd64)
    echo "amd64 환경이 감지되었습니다."
    exec "${SCRIPT_DIR}/install-docker-amd64.sh"
    ;;
  arm64)
    echo "arm64 환경이 감지되었습니다."
    exec "${SCRIPT_DIR}/install-docker-arm64.sh"
    ;;
  *)
    echo "지원하지 않는 아키텍처입니다: $(get_architecture)"
    exit 1
    ;;
esac
