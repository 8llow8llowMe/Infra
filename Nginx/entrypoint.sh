#!/bin/sh
# Entrypoint for Nginx Container
# - nginx를 PID 1로 실행 (시그널 정상 전달)
# - access.log를 stdout으로 지속 출력 (ELK 수집용)

# 1. nginx를 포그라운드 모드로 실행 (PID 1)
nginx -g 'daemon off;' &

# 2. 약간의 지연 (nginx가 완전히 뜰 때까지)
sleep 2

# 3. access.log를 stdout으로 실시간 출력
# - 로그파일은 여전히 /var/log/nginx/access.log에 저장됨
# - tail은 백그라운드에서 실행되어 stdout으로 흘림
tail -F /var/log/nginx/access.log &

# 4. tail이나 nginx 둘 중 하나가 종료될 때까지 대기
wait -n
