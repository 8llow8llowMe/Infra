FROM alpine:latest

RUN apk add --no-cache logrotate bash docker-cli

# logrotate 설정 복사
COPY logrotate.conf /etc/logrotate.conf

# 하루마다 0시 기준 실행 (sleep 계산)
CMD ["sh", "-c", "while true; do \
      now=$(date +%s); \
      next=$(( ( (now / 86400 + 1) * 86400 ) )); \
      sleep $(( next - now )); \
      logrotate -v /etc/logrotate.conf; \
    done"]