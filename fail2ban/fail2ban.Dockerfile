# Fail2Ban Dockerfile
# - Nginx access.log 기반 실시간 차단
# - Alpine + iptables + bash 포함
# 파일 + stdout 로그 병행

FROM alpine:latest

RUN apk add --no-cache fail2ban iptables bash coreutils

# 설정 복사
COPY jail.local /etc/fail2ban/jail.local
COPY filter.d/ /etc/fail2ban/filter.d/
COPY docker-entrypoint-fail2ban.sh /docker-entrypoint-fail2ban.sh
COPY fail2ban-healthcheck.sh /fail2ban-healthcheck.sh

# 실행 권한 부여
RUN chmod +x /docker-entrypoint-fail2ban.sh /fail2ban-healthcheck.sh

# 기본 실행 스크립트 (Fail2Ban 서버 + 로그 미러링)
ENTRYPOINT ["/docker-entrypoint-fail2ban.sh"]