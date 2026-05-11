# backend-1 deploy/runtime role gets read-only access to BossPickSeoul
# backend secrets. Keep this narrower than Jenkins if service groups split later.

path "kv/data/bosspickseoul/backend/*" {
  capabilities = ["read"]
}

path "kv/metadata/bosspickseoul/backend" {
  capabilities = ["list", "read"]
}

path "kv/metadata/bosspickseoul/backend/*" {
  capabilities = ["list", "read"]
}
