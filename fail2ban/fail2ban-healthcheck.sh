#!/bin/sh
# Fail2Ban Health Check Script
# - 각 Jail별 현재 밴 상태 및 샘플 IP 출력

set -e

CLIENT="/usr/bin/fail2ban-client"

# Fail2Ban 실행 여부 확인
if ! pgrep -x "fail2ban-server" >/dev/null 2>&1; then
  echo "[FAIL] fail2ban-server process not found"
  exit 1
fi

# Jail 목록 추출
RAW_JAILS=$($CLIENT status 2>/dev/null | grep "Jail list:" | sed 's/.*Jail list:\s*//')
if [ -z "$RAW_JAILS" ]; then
  echo "[WARN] No active jails detected."
  exit 0
fi

JAILS=$(echo "$RAW_JAILS" | tr ',' ' ' | xargs)

echo "==== Fail2Ban Status Summary ===="

for jail in $JAILS; do
  jail=$(echo "$jail" | xargs)
  if [ -z "$jail" ]; then
    continue
  fi

  STATUS=$($CLIENT status "$jail" 2>/dev/null || true)

  # 공백/파이프/들여쓰기 제거 후 숫자 추출
  BANNED_COUNT=$(echo "$STATUS" | grep -E "banned:" | grep -v "Total" | sed 's/[^0-9]*//g')
  TOTAL_FAILS=$(echo "$STATUS" | grep -E "Total failed:" | sed 's/[^0-9]*//g')
  BANNED_IPS=$(echo "$STATUS" | grep -E "Banned IP list:" | sed 's/.*Banned IP list:\s*//' | xargs | cut -d' ' -f1-5)

  printf "Jail: %-18s | Banned: %-4s | Total fails: %-6s | Sample IPs: %s\n" \
    "$jail" "${BANNED_COUNT:-0}" "${TOTAL_FAILS:-0}" "${BANNED_IPS:-N/A}"
done

echo "================================="
exit 0
