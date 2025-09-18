# 기본 nginx 이미지
FROM nginx:alpine

# 심볼릭 링크 설정: access.log -> stdout, error.log -> stderr
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Nginx 설정 파일 복사
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/