FROM eclipse-temurin:21-jdk as jdk

# Jenkins Agent 기본 이미지 사용
FROM jenkins/inbound-agent:latest

# 추가 패키지를 설치하기 위해 root 사용자로 전환
USER root

# 기존 Java 제거 + OpenJDK 21 복사
RUN rm -rf /usr/local/openjdk* /opt/java/openjdk /opt/java/openjdk*
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21
ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH=$JAVA_HOME/bin:$PATH

# 기본 패키지 설치
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Node.js 설치 (22.x LTS) - 웹/SSR 서버용
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# Yarn 설치
RUN npm install -g yarn && \
    yarn --version

# Docker Engine 설치 (컨테이너 배포용)
RUN apt-get update && apt-get install -y docker.io

# Compose v2 plugin 바이너리 설치
RUN mkdir -p /usr/libexec/docker/cli-plugins && \
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# gosu 설치
RUN apt-get update && apt-get install -y gosu

# Agent EntryPoint 스크립트 복사
COPY docker-entrypoint-agent.sh /usr/local/bin/docker-entrypoint-agent.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-agent.sh

# Jenkins 사용자로 전환
USER jenkins

# Entrypoint 설정
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-agent.sh"]