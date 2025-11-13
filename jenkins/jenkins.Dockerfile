# Jenkins Master Dockerfile (Slim Edition)
# - 빌드/배포는 Agent가 수행, Master는 관리/UI 전용
# - 필요 최소 구성: Java 21 + Docker + Compose + gosu

# Stage 1: 최신 Java 21 LTS 복사용
FROM eclipse-temurin:21-jdk as jdk

# Stage 2: Jenkins Master
FROM jenkins/jenkins:lts

USER root

# 1. Java 환경 정리 및 OpenJDK 21로 교체
RUN rm -rf /usr/local/openjdk* /opt/java/openjdk /opt/java/openjdk*
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21
ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH=$JAVA_HOME/bin:$PATH

# 2. Docker CLI 및 Compose Plugin 설치
RUN apt-get update && apt-get install -y \
    curl \
    docker.io \
    && mkdir -p /usr/libexec/docker/cli-plugins && \
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
    -o /usr/libexec/docker/cli-plugins/docker-compose && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# 3. gosu 설치 (jenkins 사용자 권한 전환용)
RUN apt-get install -y gosu tini && rm -rf /var/lib/apt/lists/*

# 4. Entrypoint 스크립트 복사
COPY docker-entrypoint-jenkins.sh /usr/local/bin/docker-entrypoint-jenkins.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-jenkins.sh

# 5. Jenkins Entrypoint 실행
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint-jenkins.sh"]
