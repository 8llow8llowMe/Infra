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

# Android SDK 설치 준비 (wget, unzip 필요)
RUN apt-get update && apt-get install -y wget unzip

# Android SDK 환경 변수
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=$ANDROID_SDK_ROOT
ENV PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH

# command line tools 다운로드 및 설치
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip /tmp/cmdline-tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools && \
    mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# 필수 SDK 패키지 설치
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" \
               "platforms;android-34" \
               "build-tools;34.0.0" \
               "ndk;26.1.10909125" \
               "cmake;3.22.1"

# Gradle 설치
RUN wget https://services.gradle.org/distributions/gradle-8.7-bin.zip -P /tmp && \
    unzip /tmp/gradle-8.7-bin.zip -d /opt && \
    ln -s /opt/gradle-8.7 /opt/gradle && \
    rm /tmp/gradle-8.7-bin.zip
ENV GRADLE_HOME=/opt/gradle
ENV PATH=$GRADLE_HOME/bin:$PATH

# fastlane 설치
RUN gem install fastlane -NV

# MinIO Client (mc) 설치 - ARM64 고정 (추가 부분 - 추후에 Jenkins Agent를 통해서 실행할 것이므로 해당 코드는 없어도 됨)
RUN curl -s https://dl.min.io/client/mc/release/linux-arm64/mc -o /usr/local/bin/mc && \
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