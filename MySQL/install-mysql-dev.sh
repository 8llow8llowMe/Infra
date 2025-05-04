#!/bin/bash

set -e

# MySQL 볼륨 디렉토리 (로컬 볼륨을 직접 쓸 경우 사용할 수 있음)
MYSQL_VOLUME_DIR="./mysql-data"
if [ ! -d "$MYSQL_VOLUME_DIR" ]; then
    mkdir -p "$MYSQL_VOLUME_DIR"
    echo "MySQL 데이터 디렉토리 생성 완료: $MYSQL_VOLUME_DIR"
fi

# Docker Compose 실행
echo "Docker Compose로 MySQL 컨테이너 실행 중..."
docker compose -f docker-compose-mysql.yml up -d

# 상태 출력
echo "MySQL 컨테이너 실행 완료"