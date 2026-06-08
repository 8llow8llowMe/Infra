#!/usr/bin/env sh
# BossPickSeoul용 Vault 정책과 AppRole을 초기 구성합니다.
# 실행 시점: Vault init, unseal, login 완료 후 1회 실행합니다.

set -eu

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
