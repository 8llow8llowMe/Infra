FROM alpine:latest

RUN apk add --no-cache fail2ban iptables bash

# 설정 복사
COPY jail.local /etc/fail2ban/jail.local
COPY filter.d/ /etc/fail2ban/filter.d/

CMD ["fail2ban-server", "-f", "-x", "start"]