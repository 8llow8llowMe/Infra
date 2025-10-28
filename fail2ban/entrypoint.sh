#!/bin/sh
# Entrypoint for Fail2Ban
# - /var/log/fail2ban.log + stdout 동시 출력

touch /var/log/fail2ban.log

echo "[INFO] Starting Fail2Ban..."
echo "[INFO] Logs will be written to /var/log/fail2ban.log and mirrored to stdout."

# 포그라운드 실행 + stdout 미러링
fail2ban-server -f -x start 2>&1 | tee -a /var/log/fail2ban.log