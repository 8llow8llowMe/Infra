# Jenkins Agent Dockerfile
# - Jenkins Inbound Agent + Java 21 + Node.js + Docker CLI + Buildx + Compose + gosu
# - Root 권한으로 ENTRYPOINT 실행 → 내부에서 jenkins 유저 전환
# - IaC 환경 완전 자동화를 위해 권한 수동 조정 불필요

# Stage 1. 최신 Java 21 (Temurin JDK)
FROM eclipse-temurin:21-jdk-jammy AS jdk

# Stage 2. Jenkins Inbound Agent (기본 JDK17)
FROM jenkins/inbound-agent:latest-jdk17

# 1. 기본 실행 유저를 root로 변경
# → ENTRYPOINT에서 chown/chmod 수행 가능하게 하기 위함
USER root

# 2. Java 21 교체 (Temurin JDK 복사)
RUN rm -rf /usr/local/openjdk* /opt/java/openjdk* \
 && mkdir -p /opt/java/openjdk21
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21

ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH=$JAVA_HOME/bin:$PATH

# 3. 필수 유틸리티 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git unzip ca-certificates gnupg lsb-release tini \
 && rm -rf /var/lib/apt/lists/*

# 4. Node.js 22.x LTS + Yarn + pnpm 설치
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y nodejs \
 && npm install -g yarn pnpm \
 && node -v && npm -v && yarn -v && pnpm -v

# 5. Docker CLI + Compose Plugin 설치 (Buildx + Compose)
RUN mkdir -p /usr/libexec/docker/cli-plugins \
 && curl -SL https://github.com/docker/buildx/releases/download/v0.17.1/buildx-v0.17.1.linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-buildx \
 && chmod +x /usr/libexec/docker/cli-plugins/docker-buildx \
 && curl -SL https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose \
 && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# 6. gosu 설치 (root → jenkins 전환용)
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# 7. Gradle 캐시 경로 사전 생성 (빌드 속도 향상)
RUN mkdir -p /home/jenkins/.gradle && chown -R jenkins:jenkins /home/jenkins/.gradle
ENV GRADLE_USER_HOME=/home/jenkins/.gradle

# 8. Entrypoint 스크립트 복사 및 권한 부여
COPY docker-entrypoint-jenkins-agent.sh /usr/local/bin/docker-entrypoint-jenkins-agent.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-jenkins-agent.sh

# 9. ENTRYPOINT 지정 (root로 실행)
# → 내부에서 gosu로 jenkins 유저 전환 수행
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-jenkins-agent.sh"]
