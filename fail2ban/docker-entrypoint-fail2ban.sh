#!/bin/sh
# - Docker 환경에서 Fail2Ban을 포그라운드(foreground) 모드로 실행
# - PID 관리 및 로그 파일 생성
# - Docker logs를 통해 실시간 로그 스트림 확인 가능

# 1. 에러 발생 시 즉시 종료
set -e

# 2. Fail2Ban 로그 파일 경로 지정
LOG_FILE="/var/log/fail2ban.log"

# 3. 로그 파일이 없으면 생성
touch "$LOG_FILE"

# 4. Fail2Ban PID 디렉토리 준비 (일부 Alpine 환경에서는 미존재)
mkdir -p /var/run/fail2ban
chmod 755 /var/run/fail2ban

# 5. 시작 메시지 출력
echo "[INFO] Starting Fail2Ban (foreground mode)..."
echo "[INFO] Logs -> $LOG_FILE"

# 6. Fail2Ban 실행
# - '-f' : foreground 모드 (백그라운드 데몬화 방지)
# - '-x' : 기존 pid 파일이 있을 경우 강제 재시작
# - 'exec' : 현재 쉘 프로세스를 교체하여 Fail2Ban을 PID 1로 실행
# → Docker가 Fail2Ban 프로세스를 직접 관리할 수 있게 함
exec fail2ban-server -f -x start