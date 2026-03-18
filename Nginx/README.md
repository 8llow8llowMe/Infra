# Nginx 운영 가이드

이 디렉터리는 인프라 프로젝트에서 사용하는 Nginx 리버스 프록시 구성을 관리합니다.

주요 역할은 다음과 같습니다.

- 도메인별 가상 호스트 라우팅
- HTTP -> HTTPS 리다이렉트
- Certbot HTTP-01 인증 경로 제공
- 백엔드 애플리케이션, Jenkins, MinIO 등으로 프록시 전달
- 로그 파일 생성 및 외부 보안/로그 수집 도구와의 연계

---

## 디렉터리 구조

```text
Nginx/
├── conf.d/                    # 도메인별 서버 블록 설정
├── docker-compose-nginx.yml   # Nginx 컨테이너 실행 정의
├── entrypoint.sh              # 컨테이너 시작 시 실행되는 엔트리포인트
├── nginx.conf                 # Nginx 전역 설정
├── nginx.Dockerfile           # Nginx 커스텀 이미지 빌드 파일
└── README.md                  # 이 문서
```

---

## 구성 개요

현재 Nginx는 다음 흐름으로 동작합니다.

1. 클라이언트 요청이 `80`, `443` 포트로 Nginx에 도착합니다.
2. `conf.d/*.conf` 의 도메인 설정에 따라 요청을 분기합니다.
3. 정적 리다이렉트는 Nginx가 직접 처리합니다.
4. 동적 요청은 내부 컨테이너 또는 사설망 백엔드 서버로 프록시합니다.
5. 로그는 `/var/log/nginx` 에 파일로 남기고, 일부는 컨테이너 stdout 으로도 노출합니다.

---

## 주요 파일 설명

### nginx.conf

Nginx 전역 설정 파일입니다.

주요 내용:

- worker 프로세스 수 자동 설정
- 공통 access log 포맷 정의
- `/var/log/nginx/access.log` 파일 기록
- gzip 압축 설정
- `conf.d/*.conf` 포함

### docker-compose-nginx.yml

Nginx 컨테이너 실행 정의 파일입니다.

주요 내용:

- `80`, `443` 포트 바인딩
- `nginx.conf`, `conf.d`, `logs` 디렉터리 마운트
- Certbot 인증서 디렉터리 공유
- Docker 로그 롤링 정책 설정

### nginx.Dockerfile

커스텀 Nginx 이미지를 빌드합니다.

주요 내용:

- `nginx:alpine` 기반
- 로그 파일 사전 생성
- 설정 파일 복사
- 커스텀 `entrypoint.sh` 실행

### entrypoint.sh

컨테이너 시작 시 실행되는 스크립트입니다.

주요 역할:

- Nginx 실행
- `access.log` 를 `tail -F` 로 stdout 에 연결
- 종료 시 Nginx/tail 프로세스 정리

이 구조는 다음 도구와 함께 운영하기 좋습니다.

- Docker 로그 드라이버
- Filebeat
- Fail2Ban
- logrotate

---

## 가상 호스트 정책

`conf.d` 아래 각 파일은 하나 이상의 도메인 서버 블록을 포함합니다.

현재 공통 패턴은 다음과 같습니다.

### 1. HTTP -> HTTPS 강제 전환

대부분의 도메인은 `listen 80` 서버 블록에서 HTTPS 주소로 리다이렉트합니다.

예시:

```nginx
location / {
    return 301 https://example.com$request_uri;
}
```

### 2. ACME 챌린지 경로 유지

Let's Encrypt 인증서 갱신을 위해 아래 경로를 예외 처리합니다.

```nginx
location /.well-known/acme-challenge/ {
    root /var/www/certbot;
}
```

### 3. 정규 도메인으로 통일

`www` 또는 non-`www` 중 하나를 기준 도메인으로 정하고, 나머지는 301 리다이렉트로 정리합니다.

### 4. 백엔드 프록시

동적 요청은 아래 대상 중 하나로 전달됩니다.

- Docker 네트워크 내부 컨테이너
- 같은 서버의 다른 서비스
- 사설 IP 기반 백엔드 서버

---

## 현재 설정 파일 설명

### conf.d/tripmarble.conf

- `tripmarble.com` 을 `www.tripmarble.com` 으로 정규화
- 메인 웹 요청을 `web-ssr:3000` 으로 프록시

### conf.d/api.tripmarble.conf

- `api.tripmarble.com` 처리
- `/auth-service/` 와 `/api-gateway/` 를 서로 다른 백엔드로 전달

### conf.d/jamjamnow.conf

- 정적 파일은 MinIO에서 제공
- `/api` 는 `jamjamnow-backend:8080` 으로 프록시
- `index.html` 캐시 비활성화

### conf.d/jenkins.conf

- Jenkins API/Webhook 도메인과 콘솔 도메인 분리
- WebSocket 연결 지원
- 장시간 응답을 고려한 timeout 설정 포함

### conf.d/minio.conf

- MinIO API와 MinIO Console 도메인 분리
- 브라우저 기반 접근을 위한 CORS 헤더 포함
- Console 접속 시 WebSocket 업그레이드 지원

---

## 실행 방법

### 이미지 빌드 및 실행

```bash
cd Nginx
docker compose -f docker-compose-nginx.yml up -d --build
```

### 상태 확인

```bash
docker ps
docker logs nginx
```

### 설정 반영

설정 파일만 변경한 경우에는 컨테이너를 재시작하거나 reload 할 수 있습니다.

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

이미지 변경이 포함되면 재빌드가 필요합니다.

```bash
docker compose -f docker-compose-nginx.yml up -d --build
```

---

## 로그 운영

로그는 두 방향으로 사용됩니다.

### 파일 로그

경로:

- `/var/log/nginx/access.log`
- `/var/log/nginx/error.log`

용도:

- 운영 점검
- Fail2Ban 분석
- logrotate 관리
- Filebeat 수집

### 컨테이너 로그

`entrypoint.sh` 에서 `access.log` 를 stdout 으로 전달하므로 `docker logs nginx` 로도 일부 접근 로그를 확인할 수 있습니다.

---

## 인증서 연동

Certbot 관련 마운트 경로는 다음과 같습니다.

- `../certbot/webroot:/var/www/certbot`
- `../certbot/letsencrypt:/etc/letsencrypt`

즉, Nginx는 Certbot이 발급한 인증서를 직접 참조하며, HTTP-01 챌린지 파일도 같은 경로를 공유합니다.

---

## 운영 시 주의사항

- `conf.d` 안의 도메인 설정은 인증서 경로와 `server_name` 이 정확히 일치해야 합니다.
- 사설 IP로 프록시하는 설정은 대상 서버 IP 변경 시 함께 수정해야 합니다.
- WebSocket 또는 SSE를 쓰는 서비스는 `proxy_http_version`, `Upgrade`, `Connection`, timeout 설정을 확인해야 합니다.
- `nowdoboss` 관련 설정처럼 작업 중인 파일이 있을 수 있으므로, 운영 전 `git status` 로 로컬 변경사항을 먼저 확인하는 것이 좋습니다.

---

## 점검 명령어

### 설정 문법 테스트

```bash
docker exec nginx nginx -t
```

### 액세스 로그 확인

```bash
docker exec nginx tail -f /var/log/nginx/access.log
```

### 에러 로그 확인

```bash
docker exec nginx tail -f /var/log/nginx/error.log
```

### 컨테이너 로그 확인

```bash
docker logs -f nginx
```

---

## 개선 포인트 메모

현재 구성은 실무적으로 충분히 동작할 수 있지만, 장기적으로는 아래 개선을 고려할 수 있습니다.

- 공통 프록시 헤더를 `include` 스니펫으로 분리
- 공통 SSL 설정을 스니펫으로 정리
- 도메인별 네이밍 규칙 일관화
- 운영/개발 환경 분리
- 설정 검증 자동화(`nginx -t`)를 CI에 추가
