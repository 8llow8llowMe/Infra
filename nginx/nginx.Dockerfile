# NGINX Dockerfile
# - Alpine 기반 경량 이미지 사용
# - access/error 로그를 파일로 유지하면서 컨테이너 로그에도 노출
# - Fail2Ban, logrotate, Filebeat와 함께 쓰기 쉬운 구조

FROM nginx:alpine

# 1. 로그 파일 생성
# Nginx가 시작되기 전 로그 파일을 미리 생성해 두면 tail 기반 수집이 안정적입니다.
RUN mkdir -p /var/log/nginx \
    && touch /var/log/nginx/access.log /var/log/nginx/error.log \
    && chmod 644 /var/log/nginx/*.log

# 2. 메인 설정과 도메인별 설정 복사
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/

# 3. 커스텀 엔트리포인트 복사 및 실행 권한 부여
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
