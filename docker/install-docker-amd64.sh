#!/bin/bash
# install-docker-amd64.sh - Ubuntu 서버(amd64)에 Docker Engine 및 Docker Compose 설치
# 지원 버전: Ubuntu 20.04, 22.04, 24.04

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 공통 설치 로직 로드
source "${SCRIPT_DIR}/install-common.sh"

# 2. amd64 전용 Docker 설치 실행
run_install "amd64"
