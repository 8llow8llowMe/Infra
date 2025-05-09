# 공식 Jenkins 이미지를 기본 이미지로 사용
FROM jenkins/jenkins:latest

# 추가 패키지를 설치하기 위해 root 사용자로 전환
USER root

# Java 21 설치 + 기본 설정
RUN curl -L https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.2%2B13/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.2_13.tar.gz \
    -o /tmp/openjdk21.tar.gz && \
    mkdir -p /opt/java/openjdk21 && \
    tar -xzf /tmp/openjdk21.tar.gz -C /opt/java/openjdk21 --strip-components=1 && \
    rm /tmp/openjdk21.tar.gz

# Docker Engine만 apt로 간단히 설치 (Compose 제외)
RUN apt-get update && apt-get install -y docker.io

# Compose v2 plugin 바이너리 설치
RUN mkdir -p /usr/libexec/docker/cli-plugins && \
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# EntryPoint 스크립트 복사
COPY docker-entrypoint-init.sh /usr/local/bin/docker-entrypoint-init.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-init.sh

# Entrypoint 덮어쓰기
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-init.sh"]