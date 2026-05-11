#!/usr/bin/env sh
# Vault 실행에 필요한 디렉터리를 준비하고 컨테이너를 시작합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. VAULT_ADDR와 VAULT_API_ADDR를 확인하세요."
fi

set -a
. ./.env
set +a

mkdir -p ./data ./logs

docker compose --env-file .env -f docker-compose-vault.yml up -d

echo "Vault가 시작되었습니다."
echo "Vault API/UI: ${VAULT_ADDR}"
echo "다음 단계: docker exec -it vault vault operator init"
