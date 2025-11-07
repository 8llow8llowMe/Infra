# Jenkins Agent Dockerfile
# - Jenkins Inbound Agent + Java 21 + Node.js + Docker + Compose
# - 각 서버별 (storage/backend-1) 역할에 따라 동일 이미지 재활용 가능

# Stage 1. 최신 Java 21 빌드용 (Temurin)
FROM eclipse-temurin:21-jdk-jammy AS jdk

# Stage 2. Jenkins Inbound Agent (기본 jdk17)
FROM jenkins/inbound-agent:latest-jdk17

USER root

# 1. Java 교체 → OpenJDK 21 (Temurin)
RUN rm -rf /usr/local/openjdk* /opt/java/openjdk* \
 && mkdir -p /opt/java/openjdk21
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21
ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH=$JAVA_HOME/bin:$PATH

# 2. 필수 유틸리티 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git unzip ca-certificates gnupg lsb-release \
 && rm -rf /var/lib/apt/lists/*

# 3. Node.js 22.x LTS + Yarn + pnpm 설치
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y nodejs \
 && npm install -g yarn pnpm \
 && node -v && npm -v && yarn -v && pnpm -v

# 4. Docker CLI + Compose Plugin 설치
RUN apt-get update && apt-get install -y docker.io \
 && mkdir -p /usr/libexec/docker/cli-plugins \
 && curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose \
 && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# 5. 권한 전환용 gosu 설치
RUN apt-get update && apt-get install -y gosu tini \
 && rm -rf /var/lib/apt/lists/*

# 6. Gradle 캐시 경로 사전 생성 (빌드속도 개선)
RUN mkdir -p /home/jenkins/.gradle && chown -R jenkins:jenkins /home/jenkins/.gradle
ENV GRADLE_USER_HOME=/home/jenkins/.gradle

# 7. Entrypoint 스크립트 복사
COPY docker-entrypoint-jenkins-agent.sh /usr/local/bin/docker-entrypoint-jenkins-agent.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-jenkins-agent.sh

# 8. 기본 사용자 전환 및 실행
USER jenkins
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-jenkins-agent.sh"]
