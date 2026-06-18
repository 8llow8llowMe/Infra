#!/usr/bin/env sh
# AppRole의 새 secret_id를 발급하고, 함께 사용할 role_id를 출력합니다.
# secret_id는 비밀번호와 같은 credential 값입니다. 명령 출력값을 Git에 커밋하지 마세요.

set -eu

ROLE_NAME="${1:-${ROLE_NAME:-jenkins-bosspickseoul}}"
AUTH_PATH="${AUTH_PATH:-approle}"

usage() {
  cat <<'EOF'
사용법:
  sh /vault/scripts/rotate-approle-secret.sh [role-name]

예시:
  sh /vault/scripts/rotate-approle-secret.sh
  sh /vault/scripts/rotate-approle-secret.sh jenkins-bosspickseoul
  sh /vault/scripts/rotate-approle-secret.sh backend-bosspickseoul

환경변수:
  ROLE_NAME   인자를 생략했을 때 사용할 기본 role 이름입니다.
  AUTH_PATH   Vault AppRole auth mount 경로입니다. 기본값: approle

이 스크립트는 role_id와 새로 발급한 secret_id를 출력합니다.
출력값은 Jenkins Credentials 또는 별도 비밀 저장소에만 보관하고, Git에는 저장하지 마세요.
EOF
}

case "$ROLE_NAME" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    echo "ERROR: role 이름이 비어 있습니다." >&2
    usage >&2
    exit 1
    ;;
esac

if ! vault token lookup >/dev/null 2>&1; then
  cat >&2 <<'EOF'
ERROR: Vault CLI token이 없거나 유효하지 않습니다.

먼저 로그인하거나, docker exec 실행 시 VAULT_TOKEN을 전달하세요.

예시:
  docker exec -it vault vault login
  docker exec -it -e VAULT_TOKEN='<admin-token>' vault sh /vault/scripts/rotate-approle-secret.sh
EOF
  exit 1
fi

ROLE_PATH="auth/${AUTH_PATH}/role/${ROLE_NAME}"

if ! vault read "${ROLE_PATH}/role-id" >/dev/null 2>&1; then
  cat >&2 <<EOF
ERROR: AppRole이 없거나 현재 token으로 읽을 수 없습니다: ${ROLE_NAME}

먼저 bootstrap을 실행하거나 ROLE_NAME/AUTH_PATH 값을 확인하세요.
  sh /vault/scripts/bootstrap-bosspickseoul.sh
EOF
  exit 1
fi

ROLE_ID="$(vault read -field=role_id "${ROLE_PATH}/role-id")"
SECRET_ID="$(vault write -field=secret_id -f "${ROLE_PATH}/secret-id")"

cat <<EOF
AppRole credential 발급이 완료되었습니다.

role_name:
${ROLE_NAME}

role_id:
${ROLE_ID}

new_secret_id:
${SECRET_ID}

다음 단계:
1. Jenkins의 해당 Secret text credential 값을 갱신합니다.
2. Jenkins pipeline 또는 AppRole 로그인 테스트를 실행합니다.
3. 기존 secret_id는 운영상 만료된 값으로 취급합니다.

이 출력값을 Git에 커밋하지 마세요.
EOF
