# Logrotate 전용 컨테이너
# - Alpine 기반 (경량)
# - 매일 0시 기준 로그 회전 실행
# - nginx 로그 reopen 자동 트리거

FROM alpine:latest

# 필요한 패키지 설치
RUN apk add --no-cache logrotate bash docker-cli

# 설정 복사
COPY logrotate.conf /etc/logrotate.conf

# 권한 수정 (보안 경고 방지)
RUN chmod 644 /etc/logrotate.conf

# 매일 자정(00:00) 정각 실행 루프
CMD ["sh", "-c", "while true; do \
      now=$(date +%s); \
      next=$(( ( (now / 86400 + 1) * 86400 ) )); \
      sleep $(( next - now )); \
      echo \"[INFO] Running logrotate at $(date)...\"; \
      logrotate -v /etc/logrotate.conf; \
    done"]
