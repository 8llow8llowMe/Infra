# 기본 nginx 이미지 사용
FROM nginx:alpine

# nginx.conf에서 동시에 파일 + stdout로 기록
RUN mkdir -p /var/log/nginx \
    && touch /var/log/nginx/access.log /var/log/nginx/error.log \
    && chmod 644 /var/log/nginx/*.log

# 설정 복사
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/