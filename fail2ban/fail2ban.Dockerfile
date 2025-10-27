# Fail2Ban Dockerfile
# - Nginx access.log 기반 실시간 차단
# - Alpine + iptables + bash 포함
# 파일 + stdout 로그 병행

FROM alpine:latest

RUN apk add --no-cache fail2ban iptables bash coreutils

# 설정 복사
COPY jail.local /etc/fail2ban/jail.local
COPY filter.d/ /etc/fail2ban/filter.d/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
