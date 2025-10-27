#!/bin/sh
# Entrypoint for Fail2Ban
# - /var/log/fail2ban.log + stdout 동시 출력
# - 차단/해제/탐지 이벤트 실시간 확인 가능

# 로그 파일 초기화
mkdir -p /var/log
touch /var/log/fail2ban.log

echo "[INFO] Starting Fail2Ban..."
echo "[INFO] Logs will be written to /var/log/fail2ban.log and mirrored to stdout."

# Fail2Ban 실행 (포그라운드 + 강제 시작)
# tee를 통해 파일과 stdout으로 동시에 출력
fail2ban-server -f -x start 2>&1 | tee -a /var/log/fail2ban.log
