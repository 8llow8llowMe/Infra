# SearXNG 운영 가이드

이 디렉터리는 미니PC `ai-host`에서 Open WebUI용 웹 검색 엔진 SearXNG를 Docker Compose로 운영하기 위한 구성입니다.

SearXNG는 Ollama 모델이 직접 할 수 없는 실시간 웹 검색을 대신 수행합니다. Open WebUI가 SearXNG에서 검색 결과를 받아 Ollama 모델의 컨텍스트로 전달하는 구조입니다.

```text
Open WebUI
  -> SearXNG web search
  -> Ollama model
  -> answer with search context
```

## 파일 구조

```text
searxng/
├── docker-compose-searxng.yml
├── install-searxng.sh
├── .env.example
├── .gitignore
├── config/
│   └── settings.yml
└── README.md
```

실행 후 생성되는 로컬 데이터:

- `cache/`: SearXNG cache 데이터

## 환경변수

```bash
cd searxng
cp .env.example .env
```

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `SEARXNG_IMAGE` | SearXNG 이미지 | `searxng/searxng:latest` |
| `SEARXNG_CONTAINER_NAME` | 컨테이너 이름 | `searxng` |
| `SEARXNG_PORT` | 호스트 노출 포트 | `8080` |
| `SEARXNG_CONTAINER_PORT` | 컨테이너 포트 | `8080` |
| `SEARXNG_BASE_URL` | SearXNG 외부 기준 URL | `http://localhost:8080/` |
| `TZ` | 컨테이너 타임존 | `Asia/Seoul` |

내부망에서만 쓸 경우 `SEARXNG_BASE_URL=http://<ai-host-ip>:8080/` 정도로 두면 됩니다. 외부 공개용으로 운영할 경우 HTTPS reverse proxy 주소로 바꿉니다.

Docker 네트워크 이름은 compose에서 `8llow8llowme-net`으로 고정합니다.

## settings.yml

[config/settings.yml](config/settings.yml)은 Open WebUI 연동을 위해 JSON 응답을 켜둔 상태입니다.

중요 설정:

```yaml
search:
  formats:
    - html
    - json
```

Open WebUI는 JSON 검색 결과를 사용하므로 `json`이 없으면 검색 시 `403 Forbidden` 오류가 날 수 있습니다.

운영 전에 다음 값은 변경하는 것을 권장합니다.

```yaml
server:
  secret_key: "change-me-before-production"
```

## 실행

```bash
cd searxng
sh install-searxng.sh
```

직접 실행:

```bash
docker compose --env-file .env -f docker-compose-searxng.yml up -d
```

상태 확인:

```bash
docker compose --env-file .env -f docker-compose-searxng.yml ps
docker logs -f searxng
```

중지:

```bash
docker compose --env-file .env -f docker-compose-searxng.yml down
```

## 접속

브라우저:

```text
http://<ai-host-ip>:8080
```

컨테이너 내부 네트워크:

```text
http://searxng:8080
```

JSON 검색 테스트:

```bash
curl 'http://localhost:8080/search?q=samsung%20electronics&format=json'
```

Open WebUI 컨테이너에서 테스트:

```bash
docker exec -it open-webui curl 'http://searxng:8080/search?q=samsung%20electronics&format=json'
```

## Open WebUI 연동

Open WebUI 관리자 화면에서 Web Search를 켠 뒤 SearXNG Query URL을 다음처럼 설정합니다.

```text
http://searxng:8080/search?q=<query>&format=json
```

Open WebUI와 SearXNG가 같은 `8llow8llowme-net` 네트워크에 붙어 있어야 합니다.

Ollama/Open WebUI/SearXNG 전체 연동 절차는 [../ollama/README-SEARXNG.md](../ollama/README-SEARXNG.md)를 참고합니다.

권장 흐름:

1. SearXNG 컨테이너 실행
2. `curl http://localhost:8080/search?q=test&format=json` 확인
3. Open WebUI Admin Panel에서 Web Search 활성화
4. SearXNG Query URL 등록
5. 채팅에서 Web Search 버튼 또는 agentic search 기능 사용

## 운영 주의사항

- 공개망에 직접 노출하지 않는 것을 권장합니다.
- 외부 공개가 필요하면 Nginx TLS, 인증, IP allowlist를 먼저 적용합니다.
- SearXNG는 검색 엔진별 차단이나 rate limit 영향을 받을 수 있습니다.
- 금융/주가처럼 정확성이 중요한 질문은 결과 출처를 함께 확인합니다.
- Docker json 로그는 `max-size: "10m"`, `max-file: "3"`으로 고정합니다.

## 백업과 복구

백업 대상:

- `.env`
- `config/settings.yml`

`cache/`는 재생성 가능하므로 보통 백업하지 않습니다.

백업 예시:

```bash
cd searxng
tar czf searxng-backup-$(date +%Y%m%d).tar.gz .env config
```

복구 예시:

```bash
cd searxng
tar xzf searxng-backup-YYYYMMDD.tar.gz
docker compose --env-file .env -f docker-compose-searxng.yml up -d
```

## 문제 해결

JSON 응답 확인:

```bash
curl 'http://localhost:8080/search?q=test&format=json'
```

로그 확인:

```bash
docker logs -f searxng
```

Open WebUI에서 `403 Forbidden`이 보이면 [config/settings.yml](config/settings.yml)의 `search.formats`에 `json`이 있는지 확인합니다.

참고:

- SearXNG Docker 문서: https://docs.searxng.org/admin/installation-docker
- Open WebUI SearXNG 문서: https://docs.openwebui.com/features/web-search/searxng/
