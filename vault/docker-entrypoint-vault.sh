#!/usr/bin/env sh
# 로컬 Vault 디렉터리를 준비한 뒤 마운트된 설정으로 Vault를 실행합니다.

set -eu

mkdir -p /vault/file /vault/logs

exec vault server -config=/vault/config/vault.hcl
