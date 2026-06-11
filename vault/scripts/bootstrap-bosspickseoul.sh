#!/usr/bin/env sh
# BossPickSeoul용 Vault 정책과 AppRole을 초기 구성합니다.
# 실행 시점: Vault init, unseal, login 완료 후 1회 실행합니다.

set -eu

require_admin_token() {
  if ! vault token lookup >/dev/null 2>&1; then
    cat <<'EOF'
ERROR: Vault CLI token이 설정되어 있지 않거나 유효하지 않습니다.

bootstrap은 policy와 AppRole을 갱신하므로 root token 또는 관리자 권한 token이 필요합니다.
먼저 Vault 컨테이너 안에서 root token으로 로그인하거나, docker exec 실행 시 VAULT_TOKEN을 전달하세요.

예시:
  docker exec -it vault vault login

또는:
  docker exec -it -e VAULT_TOKEN='<root-token>' vault sh /vault/scripts/bootstrap-bosspickseoul.sh
EOF
    exit 1
  fi

  if ! vault token capabilities sys/policies/acl/jenkins-bosspickseoul 2>/dev/null | grep -Eq '(^| )sudo( |$)|(^| )update( |$)|root'; then
    cat <<'EOF'
ERROR: 현재 Vault token에는 policy를 갱신할 권한이 없습니다.

bootstrap은 다음 작업을 수행하므로 root token 또는 관리자 권한 token으로 실행해야 합니다.
  - vault policy write
  - auth/approle role 생성 또는 갱신
  - userpass 사용자 생성 또는 갱신

현재 userpass Web UI 계정 token으로는 실행할 수 없습니다.
EOF
    exit 1
  fi
}

require_admin_token

vault secrets enable -path=kv kv-v2 2>/dev/null || true
vault auth enable approle 2>/dev/null || true
vault auth enable userpass 2>/dev/null || true

vault policy write jenkins-bosspickseoul /vault/policies/jenkins-bosspickseoul.hcl
vault policy write backend-bosspickseoul /vault/policies/backend-bosspickseoul.hcl
vault policy write ui-bosspickseoul /vault/policies/ui-bosspickseoul.hcl

vault write auth/approle/role/jenkins-bosspickseoul \
  token_policies="jenkins-bosspickseoul" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="720h" \
  secret_id_num_uses="0"

vault write auth/approle/role/backend-bosspickseoul \
  token_policies="backend-bosspickseoul" \
  token_ttl="30m" \
  token_max_ttl="2h" \
  secret_id_ttl="720h" \
  secret_id_num_uses="0"

if [ -n "${VAULT_UI_USERNAME:-}" ] && [ -n "${VAULT_UI_PASSWORD:-}" ]; then
  vault write "auth/userpass/users/${VAULT_UI_USERNAME}" \
    password="${VAULT_UI_PASSWORD}" \
    policies="ui-bosspickseoul" \
    token_ttl="8h" \
    token_max_ttl="24h"
fi

cat <<'EOF'
Vault 초기 구성이 완료되었습니다.

다음 값을 발급해 Jenkins/backend credential에 등록합니다.
  vault read auth/approle/role/jenkins-bosspickseoul/role-id
  vault write -f auth/approle/role/jenkins-bosspickseoul/secret-id
  vault read auth/approle/role/backend-bosspickseoul/role-id
  vault write -f auth/approle/role/backend-bosspickseoul/secret-id

Web UI username/password 로그인을 쓰려면 bootstrap 실행 시 다음 환경변수를 전달합니다.
  VAULT_UI_USERNAME='<username>' VAULT_UI_PASSWORD='<password>' sh /vault/scripts/bootstrap-bosspickseoul.sh
EOF
