#!/usr/bin/env sh
# 원격 서버용 Jenkins deploy agent를 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. deploy agent 값을 확인하세요."
fi

get_env_value() {
  grep -E "^$1=" ./.env | tail -n 1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

JENKINS_DEPLOY_AGENT_SECRET="$(get_env_value JENKINS_DEPLOY_AGENT_SECRET)"
JENKINS_DEPLOY_AGENT_CONTAINER_NAME="$(get_env_value JENKINS_DEPLOY_AGENT_CONTAINER_NAME)"
JENKINS_DEPLOY_AGENT_WORKDIR="$(get_env_value JENKINS_DEPLOY_AGENT_WORKDIR)"

if [ -z "$JENKINS_DEPLOY_AGENT_CONTAINER_NAME" ]; then
  JENKINS_DEPLOY_AGENT_CONTAINER_NAME="jenkins-deploy-agent"
fi

if [ -z "$JENKINS_DEPLOY_AGENT_WORKDIR" ]; then
  JENKINS_DEPLOY_AGENT_WORKDIR="jenkins-deploy-agent"
fi

if [ "$JENKINS_DEPLOY_AGENT_SECRET" = "change-me-after-node-created" ] || [ -z "$JENKINS_DEPLOY_AGENT_SECRET" ]; then
  echo "JENKINS_DEPLOY_AGENT_SECRET이 아직 설정되지 않았습니다."
  echo "Jenkins UI에서 deploy node를 만든 뒤 발급된 secret을 .env에 입력하세요."
  exit 1
fi

mkdir -p "./$JENKINS_DEPLOY_AGENT_WORKDIR"

docker compose --env-file .env -f docker-compose-jenkins-deploy-agent.yml up -d --build

echo "Jenkins deploy agent가 시작되었습니다."
echo "로그 확인: docker logs -f $JENKINS_DEPLOY_AGENT_CONTAINER_NAME"
