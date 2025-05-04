#!/bin/bash

set -e

# -------------------------------
# 1. 기존 MySQL 완전 제거
# -------------------------------
echo "[1] 기존 MySQL 제거 중..."
sudo apt purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* || true
sudo rm -rf /etc/mysql /var/lib/mysql
sudo apt autoremove -y
sudo apt autoclean

# -------------------------------
# 2. 패키지 목록 업데이트
# -------------------------------
echo "[2] 패키지 목록 업데이트 중..."
sudo apt update

# -------------------------------
# 3. ARM64 호환 MySQL 설치
# -------------------------------
echo "[3] MySQL 설치 중..."
sudo apt install -y mysql-server

# -------------------------------
# 4. MySQL 서비스 시작 및 부팅 시 자동 시작 설정
# -------------------------------
echo "[4] MySQL 시작 및 자동 실행 설정..."
sudo systemctl start mysql
sudo systemctl enable mysql

# -------------------------------
# 5. 커스텀 설정 적용 (mysqld.cnf는 현재 디렉토리에 존재해야 함)
# -------------------------------
echo "[5] MySQL 설정 적용..."
sudo cp ./mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf

# -------------------------------
# 6. 사용자 및 DB 생성
# -------------------------------
MYSQL_USER="your_user"
MYSQL_PASS="your_password"
MYSQL_DB="your_database"

echo "[6] MySQL 계정 및 데이터베이스 생성..."
sudo mysql -u root <<EOF
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS ${MYSQL_DB};
FLUSH PRIVILEGES;
EOF

# -------------------------------
# 7. MySQL 재시작
# -------------------------------
echo "[7] MySQL 재시작 중..."
sudo systemctl restart mysql

echo "MySQL 설치 및 설정 완료 (ARM64 / Raspberry Pi 5)"
