# Stage 1. Java 21 빌드용 (Temurin)
    FROM eclipse-temurin:21-jdk-jammy AS jdk

# Stage 2. Jenkins Inbound Agent 기반 이미지
FROM jenkins/inbound-agent:latest-jdk17

USER root

# 1. Java 교체 → Temurin 21
RUN rm -rf /usr/local/openjdk* /opt/java/openjdk* \
 && mkdir -p /opt/java/openjdk21
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21
ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH=$JAVA_HOME/bin:$PATH

# 2. 필수 도구 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# 3. Node.js 22.x + Yarn 설치 (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y nodejs \
 && npm install -g yarn pnpm \
 && node -v && npm -v && yarn -v && pnpm -v

# 4. Docker CLI + Compose v2 설치 (배포 빌드용)
RUN apt-get update && apt-get install -y docker.io \
 && mkdir -p /usr/libexec/docker/cli-plugins \
 && curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
      -o /usr/libexec/docker/cli-plugins/docker-compose \
 && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# 5. 권한 제어용 gosu 설치
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# 6. 캐시 최적화를 위한 Gradle 설정 경로 미리 생성
RUN mkdir -p /home/jenkins/.gradle && chown -R jenkins:jenkins /home/jenkins/.gradle
ENV GRADLE_USER_HOME=/home/jenkins/.gradle

# 7. 엔트리포인트 스크립트 복사
COPY docker-entrypoint-agent.sh /usr/local/bin/docker-entrypoint-agent.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-agent.sh

USER jenkins

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-agent.sh"]
