# 공식 Jenkins 이미지를 기본 이미지로 사용
FROM jenkins/jenkins:latest

# 추가 패키지를 설치하기 위해 root 사용자로 전환
USER root

# 시스템 패키지 준비 및 Docker 저장소 등록
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    gnupg-agent \
    software-properties-common

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker 엔진 + Compose v2 plugin 설치
RUN apt-get update && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# EntryPoint 스크립트 복사
COPY docker-entrypoint-init.sh /usr/local/bin/docker-entrypoint-init.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-init.sh

# Entrypoint 덮어쓰기
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-init.sh"]

# Jenkins 사용자로 전환
# 이는 보안상의 이유로, Jenkins 프로세스는 일반 사용자 권한으로 실행되어야 하기 때문
USER jenkins