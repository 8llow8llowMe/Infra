# Jenkins가 BossPickSeoul backend 배포 시크릿을 읽기 위한 정책입니다.
# KV v2는 값 조회에 /data, 목록 조회에 /metadata 경로를 사용합니다.

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
