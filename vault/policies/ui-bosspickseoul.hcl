# BossPickSeoul Vault Web UI 사용자가 시크릿을 관리하기 위한 정책입니다.
# 운영 범위는 kv/bosspickseoul 하위로 제한합니다.

path "kv/data/bosspickseoul/*" {
  capabilities = ["create", "read", "update", "delete"]
}

# KV v2에서 UI 목록 조회와 secret metadata 관리를 위해 필요합니다.
path "kv/metadata/bosspickseoul" {
  capabilities = ["list", "read"]
}

path "kv/metadata/bosspickseoul/*" {
  capabilities = ["list", "read", "delete"]
}

# 삭제된 버전 복구와 영구 삭제가 필요할 때 사용합니다.
path "kv/delete/bosspickseoul/*" {
  capabilities = ["update"]
}

path "kv/undelete/bosspickseoul/*" {
  capabilities = ["update"]
}

path "kv/destroy/bosspickseoul/*" {
  capabilities = ["update"]
}
