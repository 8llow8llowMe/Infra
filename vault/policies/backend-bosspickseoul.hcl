# backend-1 deploy/runtime이 BossPickSeoul backend 시크릿을 읽기 위한 정책입니다.
# 서비스 그룹이 더 나뉘면 이 정책도 더 좁게 분리합니다.

path "kv/data/bosspickseoul/backend/*" {
  capabilities = ["read"]
}

# backend 하위 secret 목록 조회용 권한입니다.
path "kv/metadata/bosspickseoul/backend" {
  capabilities = ["list", "read"]
}

# env/group/service 하위 경로 목록 조회용 권한입니다.
path "kv/metadata/bosspickseoul/backend/*" {
  capabilities = ["list", "read"]
}
