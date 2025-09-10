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

# Node.js 설치 (22.x LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# Yarn 설치
RUN npm install -g yarn && \
    yarn --version

# Android SDK 설치 준비 + ARM64 호환성 도구
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    file \
    qemu-user-static \
    binfmt-support

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

# 라이센스 사전 수락
RUN mkdir -p $ANDROID_SDK_ROOT/licenses && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_SDK_ROOT/licenses/android-sdk-license && \
    echo "84831b9409646a918e30573bab4c9c91346d8abd" > $ANDROID_SDK_ROOT/licenses/android-sdk-preview-license

# ARM64 호환 빌드 도구 설치
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" \
               "platforms;android-34" \
               "platforms;android-33" \
               "build-tools;33.0.2" \
               "build-tools;34.0.0" \
               "ndk;26.1.10909125" \
               "cmake;3.22.1"

# AAPT2 ARM64 바이너리 확인 및 설정
RUN for dir in $ANDROID_SDK_ROOT/build-tools/*/; do \
        if [ -f "$dir/aapt2" ]; then \
            file "$dir/aapt2" || true; \
            chmod +x "$dir/aapt2" || true; \
        fi \
    done

# SDK 디렉토리 권한 설정
RUN chmod -R 777 $ANDROID_SDK_ROOT && \
    chown -R jenkins:jenkins $ANDROID_SDK_ROOT

# Gradle 설치
RUN wget https://services.gradle.org/distributions/gradle-8.6-bin.zip -P /tmp && \
    unzip /tmp/gradle-8.6-bin.zip -d /opt && \
    ln -s /opt/gradle-8.6 /opt/gradle && \
    rm /tmp/gradle-8.6-bin.zip
ENV GRADLE_HOME=/opt/gradle
ENV PATH=$GRADLE_HOME/bin:$PATH

# fastlane 설치
RUN apt-get update && apt-get install -y ruby-full ruby-dev build-essential && \
    gem install fastlane -NV

# MinIO Client (mc) 설치 - ARM64
RUN curl -s https://dl.min.io/client/mc/release/linux-arm64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

# Docker 설치
RUN apt-get update && apt-get install -y docker.io

# Compose v2 plugin 바이너리 설치
RUN mkdir -p /usr/libexec/docker/cli-plugins && \
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# gosu 설치
RUN apt-get update && apt-get install -y gosu

# EntryPoint 스크립트 복사
COPY docker-entrypoint-init.sh /usr/local/bin/docker-entrypoint-init.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-init.sh

# Entrypoint 덮어쓰기
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint-init.sh"]