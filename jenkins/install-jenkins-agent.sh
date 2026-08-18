#!/usr/bin/env sh
# 원격 서버용 Jenkins deploy agent를 시작합니다.
#
# 사용법:
#   sh install-jenkins-agent.sh                       # ./.env 사용
#   sh install-jenkins-agent.sh .env.frontend-dev     # 지정한 env 파일 사용
#
# 한 호스트에 deploy agent를 여러 개 두려면 env 파일을 나누고 인수로 넘깁니다.
# (예: main-server에 backend-dev-agent와 frontend-dev-agent를 함께 띄우는 경우)
# 이때 env 파일마다 아래 4개를 서로 다르게 둬야 컨테이너와 작업 디렉터리가 충돌하지 않습니다.
#   JENKINS_DEPLOY_AGENT_NAME / _PROJECT_NAME / _CONTAINER_NAME / _WORKDIR

set -eu

ENV_FILE="${1:-./.env}"

if [ "$ENV_FILE" = "./.env" ] && [ ! -f "$ENV_FILE" ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. deploy agent 값을 확인하세요."
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "env 파일을 찾을 수 없습니다: $ENV_FILE"
  echo "예시를 복사해 만드세요: cp ./.env.example $ENV_FILE"
  exit 1
fi

get_env_value() {
  grep -E "^$1=" "$ENV_FILE" | tail -n 1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

JENKINS_DEPLOY_AGENT_NAME="$(get_env_value JENKINS_DEPLOY_AGENT_NAME)"
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
  echo "Jenkins UI에서 deploy node를 만든 뒤 발급된 secret을 $ENV_FILE 에 입력하세요."
  exit 1
fi

# agent secret은 node 이름으로 발급됩니다. 이름이 어긋나면 컨트롤러가 접속을 거부하므로
# 여러 agent를 돌릴 때 env 파일을 잘못 지정하는 실수를 여기서 알아채도록 출력합니다.
echo "env 파일: $ENV_FILE"
echo "node 이름: ${JENKINS_DEPLOY_AGENT_NAME:-(미지정)}"
echo "컨테이너: $JENKINS_DEPLOY_AGENT_CONTAINER_NAME"

mkdir -p "./$JENKINS_DEPLOY_AGENT_WORKDIR"

docker compose --env-file "$ENV_FILE" -f docker-compose-jenkins-deploy-agent.yml up -d --build

echo "Jenkins deploy agent가 시작되었습니다."
echo "로그 확인: docker logs -f $JENKINS_DEPLOY_AGENT_CONTAINER_NAME"

echo "Docker CLI 확인:"
docker exec "$JENKINS_DEPLOY_AGENT_CONTAINER_NAME" sh -lc 'command -v docker && docker --version && docker compose version'
