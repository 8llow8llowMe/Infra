#!/usr/bin/env sh
# kv secret engine을 삭제 후 다시 생성합니다.
# Vault 전체 초기화가 아니라 kv mount 아래 secret만 모두 삭제됩니다.

set -eu

if [ "${CONFIRM_RESET_KV:-}" != "bosspickseoul" ]; then
  cat <<'EOF'
ERROR: kv secret engine reset은 모든 kv secret을 삭제합니다.

정말 실행하려면 아래처럼 확인값을 전달하세요.
  CONFIRM_RESET_KV=bosspickseoul sh /vault/scripts/reset-kv-bosspickseoul.sh
EOF
  exit 1
fi

vault secrets disable kv 2>/dev/null || true
vault secrets enable -path=kv kv-v2

cat <<'EOF'
kv secret engine을 다시 생성했습니다.

권장 secret path:
  mount: kv
  path:  bosspickseoul/backend/dev/env

저장 예시:
  vault kv put -mount="kv" bosspickseoul/backend/dev/env env_file=@.env
EOF
