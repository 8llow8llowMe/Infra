#!/usr/bin/env sh
# Vault 데이터/로그 디렉터리를 준비하고 서버를 실행합니다.

set -eu

mkdir -p /vault/file /vault/logs

exec vault server -config=/vault/config/vault.hcl
