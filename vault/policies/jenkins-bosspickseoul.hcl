# Jenkins가 BossPickSeoul 배포 시크릿을 읽기 위한 정책입니다.
# KV v2는 값 조회에 /data, 목록 조회에 /metadata 경로를 사용합니다.
#
# backend 와 frontend 를 한 policy 에 두는 이유:
# 두 파이프라인 모두 같은 AppRole(jenkins-bosspickseoul) 로 로그인합니다.
# 애플리케이션 그룹이 더 늘어나면 여기에 블록을 추가합니다.
# (와일드카드를 bosspickseoul/* 로 넓히지 않는 것은, 나중에 배포와 무관한 시크릿이
#  같은 mount 에 생겼을 때 Jenkins 가 그것까지 읽게 되는 것을 막기 위해서입니다)

# ── backend ──────────────────────────────────────────────
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

# ── frontend ─────────────────────────────────────────────
path "kv/data/bosspickseoul/frontend/*" {
  capabilities = ["read"]
}

# frontend 하위 secret 목록 조회용 권한입니다.
path "kv/metadata/bosspickseoul/frontend" {
  capabilities = ["list", "read"]
}

# env 하위 경로 목록 조회용 권한입니다.
path "kv/metadata/bosspickseoul/frontend/*" {
  capabilities = ["list", "read"]
}
