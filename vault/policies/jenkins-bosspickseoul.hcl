# Jenkins reads BossPickSeoul deployment secrets and can list metadata.
# KV v2 API paths use /data for values and /metadata for listing.

path "kv/data/bosspickseoul/backend/*" {
  capabilities = ["read"]
}

path "kv/metadata/bosspickseoul/backend" {
  capabilities = ["list", "read"]
}

path "kv/metadata/bosspickseoul/backend/*" {
  capabilities = ["list", "read"]
}
