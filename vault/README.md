# Vault 운영 가이드

이 디렉터리는 미니PC에서 HashiCorp Vault를 단일 노드 파일 스토리지 방식으로 운영하기 위한 IaC 구성입니다.

Vault는 secret 허브 역할을 담당합니다. Jenkins, 애플리케이션, 배포 스크립트는 Vault에서 필요한 secret을 읽고, 실제 secret 값은 Git에 커밋하지 않습니다.

---

## 디렉터리 구조

```text
Vault/
├── docker-compose-vault.yml      # Vault 컨테이너 실행 정의
├── vault.hcl                     # Vault 서버 설정
├── docker-entrypoint-vault.sh     # Vault 시작 스크립트
├── .env.example                  # 환경변수 예시
└── README.md                     # 운영 가이드
```

런타임 데이터는 실행 후 아래 경로에 생성됩니다.

- `data/`: Vault 파일 스토리지 데이터
- `logs/`: Vault 로그 보관용 디렉터리

---

## 초기 설정

```bash
cd Vault
cp .env.example .env
```

`.env`의 주소는 운영 환경에 맞게 바꿉니다.

```env
VAULT_ADDR=http://<미니PC-IP>:8200
VAULT_API_ADDR=http://<미니PC-IP>:8200
```

사설망 안에서 Nginx나 별도 TLS 프록시를 둘 계획이면 `VAULT_ADDR`만 해당 주소로 맞춥니다.

---

## 실행

```bash
cd Vault
docker compose -f docker-compose-vault.yml up -d
```

상태 확인:

```bash
docker compose -f docker-compose-vault.yml ps
docker logs -f vault
```

Compose 문법 확인:

```bash
docker compose -f docker-compose-vault.yml config
```

---

## 초기화와 Unseal

Vault는 최초 1회 초기화가 필요합니다.

```bash
docker exec -it vault vault operator init
```

출력되는 unseal key와 initial root token은 안전한 오프라인 장소에 보관합니다. 이 값은 Git, 메신저, 일반 노트에 저장하지 않습니다.

unseal:

```bash
docker exec -it vault vault operator unseal
docker exec -it vault vault operator unseal
docker exec -it vault vault operator unseal
```

로그인:

```bash
docker exec -it vault vault login
```

상태 확인:

```bash
docker exec vault vault status
```

컨테이너 재시작 후에도 unseal은 다시 필요합니다. 자동 unseal은 이번 구성 범위에 포함하지 않습니다.

---

## KV v2 활성화

애플리케이션 secret 저장소 예시:

```bash
docker exec -it vault vault secrets enable -path=secret kv-v2
```

secret 저장:

```bash
docker exec -it vault vault kv put secret/nowdoboss/prod DB_PASSWORD='change-me'
```

secret 조회:

```bash
docker exec -it vault vault kv get secret/nowdoboss/prod
```

---

## AppRole 예시

Jenkins나 애플리케이션이 Vault에 접근할 때는 root token 대신 AppRole을 사용합니다.

정책 파일 생성 예시:

```bash
docker exec -i vault sh -c 'cat > /tmp/jenkins-policy.hcl' <<'EOF'
path "secret/data/*" {
  capabilities = ["read"]
}

path "secret/metadata/*" {
  capabilities = ["list", "read"]
}
EOF
```

정책 등록:

```bash
docker exec -it vault vault policy write jenkins-read /tmp/jenkins-policy.hcl
```

AppRole 활성화:

```bash
docker exec -it vault vault auth enable approle
```

role 생성:

```bash
docker exec -it vault vault write auth/approle/role/jenkins \
  token_policies='jenkins-read' \
  token_ttl='1h' \
  token_max_ttl='4h'
```

role id 확인:

```bash
docker exec -it vault vault read auth/approle/role/jenkins/role-id
```

secret id 발급:

```bash
docker exec -it vault vault write -f auth/approle/role/jenkins/secret-id
```

발급된 `role_id`와 `secret_id`를 Jenkins credential에 등록합니다.

---

## 백업과 복구

백업 대상:

- `data/`
- `.env`
- 보관 중인 unseal key와 root token

백업 예시:

```bash
tar czf vault-backup-$(date +%Y%m%d).tar.gz data .env
```

복구 예시:

```bash
tar xzf vault-backup-YYYYMMDD.tar.gz
docker compose -f docker-compose-vault.yml up -d
docker exec -it vault vault operator unseal
```

---

## 운영 주의사항

- `data/`, `.env`, unseal key, root token은 Git에 커밋하지 않습니다.
- root token은 초기 설정과 긴급 복구에만 사용합니다.
- 서비스별로 정책과 AppRole을 분리합니다.
- 외부 공개망에 직접 노출하지 않고 사설망 또는 TLS 프록시 뒤에서 운영합니다.
- 운영 중 `vault.hcl`을 바꾸면 컨테이너 재시작이 필요합니다.

---

## 문제 해결

sealed 상태 확인:

```bash
docker exec vault vault status
```

로그 확인:

```bash
docker logs -f vault
```

권한 문제 확인:

```bash
docker exec vault ls -la /vault/file /vault/logs
```

초기화 여부 확인:

```bash
docker exec vault vault status
```

`Initialized`가 `false`면 `vault operator init`을 먼저 실행합니다. `Sealed`가 `true`면 unseal key로 해제합니다.
