#!/usr/bin/env sh
# Prepare local Vault directories, then start Vault with mounted config.

set -eu

mkdir -p /vault/file /vault/logs

exec vault server -config=/vault/config/vault.hcl
