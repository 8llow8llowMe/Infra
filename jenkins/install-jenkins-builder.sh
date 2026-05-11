#!/usr/bin/env sh
# Jenkins builder agent 작업 디렉터리를 준비하고 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  echo ".env 파일이 없습니다. 먼저 install-jenkins.sh를 실행하거나 .env를 준비하세요."
  exit 1
fi

get_env_value() {
  grep -E "^$1=" ./.env | tail -n 1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

JENKINS_BUILDER_SECRET="$(get_env_value JENKINS_BUILDER_SECRET)"

if [ "$JENKINS_BUILDER_SECRET" = "change-me-after-node-created" ] || [ -z "$JENKINS_BUILDER_SECRET" ]; then
  echo "JENKINS_BUILDER_SECRET이 아직 설정되지 않았습니다."
  echo "Jenkins UI에서 builder node를 만든 뒤 발급된 secret을 .env에 입력하세요."
  exit 1
fi

mkdir -p ./jenkins-builder-agent

docker compose --env-file .env -f docker-compose-jenkins.yml up -d --build jenkins-builder-agent

echo "Jenkins builder agent가 시작되었습니다."
echo "로그 확인: docker logs -f jenkins-builder-agent"
