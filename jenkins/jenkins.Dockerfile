# 미니PC용 Jenkins controller 이미지입니다.
# Jenkins LTS에 Java 21과 간단한 관리 작업용 Docker CLI를 포함합니다.

FROM eclipse-temurin:21-jdk-jammy AS jdk

FROM jenkins/jenkins:lts

USER root

COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21

ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    docker.io \
    gosu \
    tini \
 && mkdir -p /usr/libexec/docker/cli-plugins \
 && curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
    -o /usr/libexec/docker/cli-plugins/docker-compose \
 && chmod +x /usr/libexec/docker/cli-plugins/docker-compose \
 && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint-jenkins.sh /usr/local/bin/docker-entrypoint-jenkins.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-jenkins.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint-jenkins.sh"]
