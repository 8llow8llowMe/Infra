# 혼디가개 배포 대상 호스트(main-server / backend-1)의 deploy/runtime 이
# backend 시크릿을 읽기 위한 정책입니다.
# 서비스 그룹이 더 나뉘면 이 정책도 더 좁게 분리합니다.

path "kv/data/hondigagae/backend/*" {
  capabilities = ["read"]
}

# backend 하위 secret 목록 조회용 권한입니다.
path "kv/metadata/hondigagae/backend" {
  capabilities = ["list", "read"]
}

# env 하위 경로 목록 조회용 권한입니다.
path "kv/metadata/hondigagae/backend/*" {
  capabilities = ["list", "read"]
}
