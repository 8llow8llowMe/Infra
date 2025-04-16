#!/bin/bash

# docker.sock의 GID 동기화
SOCK="/var/run/docker.sock"
if [ -S "$SOCK" ]; then
    GID=$(stat -c '%g' "$SOCK")
    groupadd -for -g "$GID" docker
    usermod -aG docker jenkins
    echo "[INFO] Added jenkins user to docker group (GID=$GID)"
fi

# 기존 entrypoint로 넘어감
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"