#!/bin/bash

# MinIO 볼륨 폴더 생성
MINIO_DIR="./minio-data"
if [ ! -d "$MINIO_DIR" ]; then
    mkdir -p "$MINIO_DIR"
    echo "MinIO 데이터 디렉토리 생성 완료: $MINIO_DIR"
fi

# Docker Compose 실행
docker compose -f docker-compose-minio.yml up -d

# 상태 출력
echo "MinIO 컨테이너 실행 완료"