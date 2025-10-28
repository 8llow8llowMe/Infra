# NGINX Dockerfile
# - Alpine 기반 (경량)
# - access.log → 파일 저장 + stdout 병행 (tail -F)
# - Fail2Ban, logrotate, ELK 호환 구조

FROM nginx:alpine

# 로그 디렉토리 생성 및 권한 설정
RUN mkdir -p /var/log/nginx \
    && touch /var/log/nginx/access.log /var/log/nginx/error.log \
    && chmod 644 /var/log/nginx/*.log

# 설정 복사
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/

# 엔트리포인트 복사 및 실행권한 부여
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
