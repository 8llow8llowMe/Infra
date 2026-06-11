# Jenkins deploy agent 이미지입니다.
# Jenkins controller/remoting 클래스 버전에 맞추기 위해 Java 21을 사용합니다.
# builder agent보다 가볍게 유지하기 위해 Node.js, pnpm, yarn, Gradle 캐시는 포함하지 않습니다.

FROM eclipse-temurin:21-jdk-jammy AS jdk

FROM jenkins/inbound-agent:latest-jdk17

USER root

COPY --from=jdk /opt/java/openjdk /opt/java/openjdk21

ENV JAVA_HOME=/opt/java/openjdk21
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    docker.io \
    git \
    gnupg \
    gosu \
    jq \
    lsb-release \
    openssh-client \
    rsync \
    tini \
    unzip \
    wget \
 && mkdir -p /usr/libexec/docker/cli-plugins \
 && arch="$(uname -m)" \
 && case "$arch" in \
      x86_64) buildx_arch="amd64"; compose_arch="x86_64" ;; \
      aarch64|arm64) buildx_arch="arm64"; compose_arch="aarch64" ;; \
      armv7l) buildx_arch="arm-v7"; compose_arch="armv7" ;; \
      *) echo "Unsupported architecture: $arch"; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/docker/buildx/releases/download/v0.17.1/buildx-v0.17.1.linux-${buildx_arch}" \
    -o /usr/libexec/docker/cli-plugins/docker-buildx \
 && curl -fsSL "https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-${compose_arch}" \
    -o /usr/libexec/docker/cli-plugins/docker-compose \
 && chmod +x /usr/libexec/docker/cli-plugins/docker-buildx /usr/libexec/docker/cli-plugins/docker-compose \
 && mkdir -p /home/jenkins/.ssh \
 && chown -R jenkins:jenkins /home/jenkins \
 && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint-jenkins-agent.sh /usr/local/bin/docker-entrypoint-jenkins-agent.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-jenkins-agent.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-jenkins-agent.sh"]
