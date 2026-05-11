#!/usr/bin/env sh
# Jenkins controller 실행에 필요한 디렉터리를 준비하고 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. 포트와 Jenkins URL을 확인하세요."
fi

get_env_value() {
  grep -E "^$1=" ./.env | tail -n 1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

JENKINS_WEB_PORT="$(get_env_value JENKINS_WEB_PORT)"

mkdir -p ./jenkins-home

docker compose --env-file .env -f docker-compose-jenkins.yml up -d --build jenkins-controller

echo "Jenkins controller가 시작되었습니다."
echo "Web UI: http://<ai-host-ip>:${JENKINS_WEB_PORT}"
echo "초기 비밀번호 확인: docker exec jenkins-controller cat /var/jenkins_home/secrets/initialAdminPassword"
