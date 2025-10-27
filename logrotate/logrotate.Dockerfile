# Logrotate 전용 컨테이너
# - Alpine 기반 (경량)
# - 매일 0시 기준으로 로그 회전 실행

FROM alpine:latest

RUN apk add --no-cache logrotate bash docker docker-cli-compose

# logrotate 설정 복사
COPY logrotate.conf /etc/logrotate.conf

# 매일 0시 정각에 실행 (sleep 계산)
CMD ["sh", "-c", "while true; do \
      now=$(date +%s); \
      next=$(( ( (now / 86400 + 1) * 86400 ) )); \
      sleep $(( next - now )); \
      echo 'Running logrotate at $(date)...'; \
      logrotate -v /etc/logrotate.conf; \
    done"]
