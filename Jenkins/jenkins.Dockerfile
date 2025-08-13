FROM eclipse-temurin:21-jdk as jdk

# 공식 Jenkins 이미지를 기본 이미지로 사용
FROM jenkins/jenkins:latest

# 추가 패키지를 설치하기 위해 root 사용자로 전환
USER root

# 기존 Java 제거 + OpenJDK 21 복사
RUN rm -rf /usr/local/openjdk* /opt/java/openjdk /opt/java/openjdk*

COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21
ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH=$JAVA_HOME/bin:$PATH

# Node.js 설치 (22.x LTS) (추가 부분 - 추후에 Jenkins Agent를 통해서 실행할 것이므로 해당 코드는 없어도 됨)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# Yarn 설치
RUN npm install -g yarn && \
    yarn --version

# MinIO Client (mc) 설치 (추가 부분 - 추후에 Jenkins Agent를 통해서 실행할 것이므로 해당 코드는 없어도 됨)
RUN curl -s https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

# Docker Engine만 apt로 간단히 설치 (Compose 제외)
RUN apt-get update && apt-get install -y docker.io

# Compose v2 plugin 바이너리 설치
RUN mkdir -p /usr/libexec/docker/cli-plugins && \
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# gosu 설치
RUN apt-get update && apt-get install -y docker.io gosu

# EntryPoint 스크립트 복사
COPY docker-entrypoint-init.sh /usr/local/bin/docker-entrypoint-init.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-init.sh

# Entrypoint 덮어쓰기
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint-init.sh"]