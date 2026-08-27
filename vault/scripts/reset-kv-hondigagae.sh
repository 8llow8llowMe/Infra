#!/usr/bin/env sh
# 혼디가개 kv 경로만 삭제합니다.
#
# ⚠️ BossPickSeoul 과 같은 kv mount 를 공유하므로 `vault secrets disable kv` 를 쓰면 안 됩니다.
#    그건 BossPickSeoul 시크릿까지 함께 날립니다.
#    (reset-kv-bosspickseoul.sh 는 mount 를 통째로 지우는 스크립트입니다 - 혼동하지 마세요)
#    여기서는 kv/hondigagae 아래 metadata 를 재귀 삭제하는 방식만 씁니다.

set -eu

if [ "${CONFIRM_RESET_KV:-}" != "hondigagae" ]; then
  cat <<'INNER'
ERROR: 이 스크립트는 kv/hondigagae 아래 모든 secret 을 영구 삭제합니다.

정말 실행하려면 아래처럼 확인값을 전달하세요.
  docker exec -it -e CONFIRM_RESET_KV=hondigagae vault sh /vault/scripts/reset-kv-hondigagae.sh
INNER
  exit 1
fi

delete_tree() {
  prefix="$1"
  # `vault kv list` 는 디렉터리에 / 접미사를 붙여 반환합니다. 헤더 2줄은 건너뜁니다.
  for entry in $(vault kv list -format=table "kv/metadata/${prefix}" 2>/dev/null | tail -n +3); do
    case "$entry" in
      */) delete_tree "${prefix}$(printf '%s' "$entry" | tr -d '/')/" ;;
      *)
        echo "destroy: kv/${prefix}${entry}"
        vault kv metadata delete "kv/${prefix}${entry}"
        ;;
    esac
  done
}

delete_tree "hondigagae/"

cat <<'EOM'
kv/hondigagae 아래 secret 을 삭제했습니다. mount(kv) 자체는 그대로입니다.

다시 넣는 예시:
  vault kv put -mount="kv" hondigagae/backend/dev/env env_file=@.env
EOM
