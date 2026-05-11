# Certbot 운영 가이드

이 디렉터리는 Let's Encrypt 인증서 발급과 자동 갱신을 담당합니다.

현재 구조는 Nginx가 외부 `80`, `443` 포트를 받고, Certbot은 HTTP-01 challenge 파일을 공유 webroot에 생성하는 방식입니다. 인증서가 실제로 갱신되면 Certbot deploy hook이 Nginx 컨테이너를 reload 해서 새 인증서가 즉시 반영됩니다.

---

## 디렉터리 구조

```text
certbot/
├── .env.example                 # 환경변수 예시
├── .gitignore                   # 인증서/로그/런타임 파일 제외
├── docker-compose-certbot.yml   # Certbot 갱신 컨테이너 정의
├── install-certbot.sh           # 갱신 컨테이너 실행 스크립트
├── renew-loop.sh                # 12시간 주기 갱신 루프와 Nginx reload hook
├── init-cert-non-www.sh         # 최초 non-www 인증서 발급용 스크립트
├── init-cert-with-www.sh        # 최초 www 포함 인증서 발급용 스크립트
├── letsencrypt/                 # 인증서, renewal 설정, TLS helper 파일
├── logs/                        # Certbot 로그
└── webroot/                     # HTTP-01 challenge 파일 공유 경로
```

실행 중 생성되는 `letsencrypt/`, `logs/`, `webroot/` 데이터는 운영 서버의 로컬 상태입니다.

---

## 구성 개요

1. Certbot이 `/var/www/certbot/.well-known/acme-challenge/` 아래에 challenge 파일을 생성합니다.
2. Nginx는 같은 호스트 디렉터리를 `/var/www/certbot`으로 마운트해서 외부 HTTP 요청에 응답합니다.
3. Let's Encrypt가 `http://도메인/.well-known/acme-challenge/<token>`으로 파일을 검증합니다.
4. 인증서가 갱신되면 Certbot deploy hook이 `docker exec nginx nginx -s reload`를 실행합니다.
5. Nginx가 새 인증서를 다시 읽고 HTTPS 응답에 반영합니다.

Nginx 쪽에는 도메인별 HTTP server block마다 아래 location이 있어야 합니다.

```nginx
location /.well-known/acme-challenge/ {
    root /var/www/certbot;
}
```

---

## 주요 파일

### docker-compose-certbot.yml

Certbot 컨테이너를 계속 실행하면서 주기적으로 갱신을 확인합니다.

주요 마운트:

- `./letsencrypt:/etc/letsencrypt`: 인증서와 renewal 설정 저장
- `./logs:/var/log/letsencrypt`: Certbot 로그 저장
- `./webroot:/var/www/certbot`: HTTP-01 challenge 파일 공유
- `./renew-loop.sh:/usr/local/bin/renew-loop.sh:ro`: 갱신 루프 스크립트
- `/usr/bin/docker:/usr/bin/docker:ro`: Nginx reload를 위한 Docker CLI
- `/var/run/docker.sock:/var/run/docker.sock`: Docker daemon 접근

주요 환경 변수:

| 변수 | 설명 | 기본값 |
| --- | --- | --- |
| `CERTBOT_WEBROOT` | HTTP-01 challenge webroot | `/var/www/certbot` |
| `CERTBOT_RENEW_INTERVAL` | 갱신 확인 주기 | `12h` |
| `NGINX_CONTAINER` | reload할 Nginx 컨테이너 이름 | `nginx` |
| `STRONG_DH` | 값이 있으면 `ssl-dhparams.pem`을 4096bit로 생성 | 빈 값 |

### renew-loop.sh

Certbot 컨테이너의 entrypoint입니다.

주요 역할:

- Nginx SSL 설정에 필요한 `options-ssl-nginx.conf` 생성
- `ssl-dhparams.pem` 생성
- `certbot renew` 주기 실행
- 인증서 갱신 성공 시 Nginx reload
- Docker 종료 신호 처리

---

## 실행 방법

실행 전 `.env`를 준비합니다.

```bash
cd ~/infra/certbot
cp .env.example .env
vi .env
```

필수 값:

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `TZ` | 컨테이너 타임존 | `Asia/Seoul` |
| `CERTBOT_WEBROOT` | HTTP-01 challenge webroot | `/var/www/certbot` |
| `CERTBOT_RENEW_INTERVAL` | 갱신 확인 주기 | `12h` |
| `NGINX_CONTAINER` | reload할 Nginx 컨테이너 이름 | `nginx` |
| `STRONG_DH` | 값이 있으면 4096bit DH 파라미터 생성 | 빈 값 |
| `CERTBOT_EMAIL` | 최초 인증서 발급 이메일 | `admin@example.com` |

스크립트 실행:

```bash
cd ~/infra/certbot
sh install-certbot.sh
```

직접 실행:

```bash
cd ~/infra/certbot
docker compose --env-file .env -f docker-compose-certbot.yml up -d --force-recreate --remove-orphans
```

상태 확인:

```bash
docker ps -a | grep certbot
docker logs certbot --tail=100
```

---

## 최초 인증서 발급

신규 도메인은 Nginx에 HTTP challenge location을 먼저 추가하고 reload한 뒤 발급합니다.

non-www 단일 도메인:

```bash
cd ~/infra/certbot
./init-cert-non-www.sh example.com
```

www 포함 도메인:

```bash
cd ~/infra/certbot
./init-cert-with-www.sh example.com
```

4096bit DH 파라미터를 만들고 싶으면 두 번째 인자로 `--strong-dh`를 전달합니다.

```bash
./init-cert-with-www.sh example.com --strong-dh
```

발급 후 Nginx 설정의 인증서 경로가 실제 certificate name과 일치해야 합니다.

예시:

```nginx
ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

---

## 갱신 확인

등록된 인증서 목록:

```bash
docker exec certbot certbot certificates
```

실제 갱신 테스트:

```bash
docker exec certbot certbot renew \
  --dry-run \
  --webroot -w /var/www/certbot \
  -v
```

수동 갱신:

```bash
docker exec certbot certbot renew --webroot -w /var/www/certbot
docker exec nginx nginx -s reload
```

---

## Nginx 반영 확인

인증서 파일 자체의 만료일:

```bash
docker exec certbot certbot certificates
```

Nginx가 실제로 외부에 내보내는 인증서 만료일:

```bash
echo | openssl s_client \
  -connect jenkins.8llow8llowme.com:443 \
  -servername jenkins.8llow8llowme.com 2>/dev/null \
  | openssl x509 -noout -dates
```

Certbot 인증서는 갱신되어 있는데 브라우저에서 만료로 보이면 Nginx reload 여부를 먼저 확인합니다.

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

---

## HTTP-01 Challenge 점검

webroot 공유가 정상인지 확인:

```bash
cd ~/infra
sudo mkdir -p certbot/webroot/.well-known/acme-challenge
echo ok | sudo tee certbot/webroot/.well-known/acme-challenge/test
curl -i http://jenkins.8llow8llowme.com/.well-known/acme-challenge/test
```

정상이면 응답 본문에 `ok`가 나옵니다.

Certbot 컨테이너에서 만든 파일이 Nginx로 보이는지도 확인할 수 있습니다.

```bash
docker exec certbot sh -c 'mkdir -p /var/www/certbot/.well-known/acme-challenge && echo ok-from-certbot > /var/www/certbot/.well-known/acme-challenge/from-certbot'
curl -i http://jenkins.8llow8llowme.com/.well-known/acme-challenge/from-certbot
```

---

## 장애 대응

### Some challenges have failed

확인 순서:

```bash
docker exec certbot certbot certificates
docker exec certbot certbot renew --dry-run --webroot -w /var/www/certbot -v
sudo tail -n 200 ~/infra/certbot/logs/letsencrypt.log
```

주요 원인:

- DNS가 현재 Nginx 서버를 가리키지 않음
- 80번 포트가 외부에서 접근되지 않음
- Nginx에 ACME challenge location이 없음
- Certbot과 Nginx가 같은 webroot를 공유하지 않음
- renewal 설정에 포함된 도메인과 Nginx `server_name`이 다름

### 인증서는 갱신됐는데 브라우저에서 만료로 보임

대부분 Nginx reload가 안 된 상태입니다.

```bash
docker exec nginx nginx -s reload
```

이 구성을 유지하려면 Certbot 컨테이너에 Docker CLI와 Docker socket 마운트가 모두 필요합니다.

```yaml
- /usr/bin/docker:/usr/bin/docker:ro
- /var/run/docker.sock:/var/run/docker.sock
```

### docker CLI not found; nginx reload skipped

Certbot 컨테이너 안에서 `docker` 명령을 찾지 못한 상태입니다.

```bash
docker exec certbot which docker
```

없다면 `docker-compose-certbot.yml`의 `/usr/bin/docker` 마운트를 확인하고 컨테이너를 재생성합니다.

```bash
cd ~/infra/certbot
docker compose --env-file .env -f docker-compose-certbot.yml up -d --force-recreate
```

---

## 운영 주의사항

- 인증서가 갱신되어도 Nginx reload 전까지 기존 인증서를 계속 응답할 수 있습니다.
- Docker socket 마운트는 강한 권한입니다. 이 컨테이너는 신뢰 가능한 운영 서버에서만 실행합니다.
- `letsencrypt/`, `logs/`, `webroot/`는 서버 상태 데이터이므로 실수로 삭제하지 않습니다.
- 신규 도메인 추가 시 DNS, Nginx `server_name`, Certbot certificate name, SSL 경로를 함께 확인합니다.
