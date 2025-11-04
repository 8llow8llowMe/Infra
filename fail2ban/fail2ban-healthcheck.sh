#!/bin/sh
# Fail2Ban Health Check Script
# - 각 Jail별 상태 및 차단 IP 수 요약
# - Docker healthcheck 또는 수동 모니터링용

# Fail2Ban 서비스 실행 여부 확인
if ! pgrep -x "fail2ban-server" >/dev/null 2>&1; then
  echo "[FAIL] fail2ban-server process not found"
  exit 1
fi

# Jail 목록 확인
JAILS=$(fail2ban-client status | grep "Jail list:" | awk -F': ' '{print $2}' | tr ',' ' ')

if [ -z "$JAILS" ]; then
  echo "[WARN] No active jails detected."
  exit 0
fi

echo "==== Fail2Ban Status Summary ===="
for jail in $JAILS; do
  jail=$(echo "$jail" | xargs) # trim spaces
  BANNED_COUNT=$(fail2ban-client status "$jail" | grep "Currently banned:" | awk -F': ' '{print $2}' | xargs)
  TOTAL_FAILS=$(fail2ban-client status "$jail" | grep "Total failed:" | awk -F': ' '{print $2}' | xargs)

  printf "Jail: %-18s | Banned: %-4s | Total fails: %-4s\n" "$jail" "${BANNED_COUNT:-0}" "${TOTAL_FAILS:-0}"
done

echo "================================="
exit 0
