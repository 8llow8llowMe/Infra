# Ollama, Open WebUI, SearXNG 연동 가이드

이 문서는 미니PC `ai-host`에서 실행 중인 Ollama/Open WebUI와 SearXNG를 연결해 웹 검색이 가능한 로컬 AI 환경을 만드는 절차입니다.

Ollama 모델 자체는 인터넷 검색을 직접 하지 않습니다. Open WebUI가 SearXNG에 검색을 요청하고, 검색 결과를 Ollama 모델에 컨텍스트로 전달하는 구조입니다.

```text
Browser
  -> Open WebUI
    -> SearXNG search
    -> Ollama model
    -> Answer
```

## 전제

두 compose가 같은 Docker 네트워크를 사용해야 합니다.

Ollama/Open WebUI:

```env
OPEN_WEBUI_OLLAMA_BASE_URL=http://ollama:11434
```

두 compose의 Docker 네트워크 이름은 `8llow8llowme-net`으로 고정되어 있습니다. 이 구성이면 Open WebUI 컨테이너에서 다음 주소로 SearXNG에 접근할 수 있습니다.

```text
http://searxng:8080
```

## 1. Ollama와 Open WebUI 실행

```bash
cd ~/infra/ollama
docker compose --env-file .env -f docker-compose-ollama.yml up -d
```

상태 확인:

```bash
docker ps
docker logs -f ollama
docker logs -f open-webui
```

Ollama API 확인:

```bash
curl http://localhost:11434/api/tags
```

## 2. SearXNG 실행

```bash
cd ~/infra/searxng
cp .env.example .env
docker compose --env-file .env -f docker-compose-searxng.yml up -d
```

SearXNG 검색 확인:

```bash
curl 'http://localhost:8080/search?q=samsung%20electronics&format=json'
```

Open WebUI 컨테이너에서 SearXNG 접근 확인:

```bash
docker exec -it open-webui curl 'http://searxng:8080/search?q=samsung%20electronics&format=json'
```

여기서 JSON 응답이 나오면 컨테이너 네트워크 연결은 정상입니다.

## 3. Open WebUI에서 Web Search 설정

브라우저에서 Open WebUI에 접속합니다.

```text
http://<ai-host-ip>:3000
```

관리자 계정으로 로그인한 뒤 다음 메뉴로 이동합니다.

```text
Admin Panel -> Settings -> Web Search
```

설정값:

```text
Enable Web Search: On
Web Search Engine: searxng
SearXNG Query URL: http://searxng:8080/search?q=<query>&format=json
```

저장 후 새 채팅에서 Web Search 버튼을 켜고 질문합니다.

예시:

```text
현재 삼성전자 주가와 오늘 변동 이유를 출처와 함께 요약해줘.
```

## 4. 모델 선택

검색 기능은 모델이 아니라 Open WebUI가 담당합니다. 따라서 Ollama에 어떤 모델을 쓰든 Web Search 구조는 같습니다.

추천 시작 모델:

```bash
docker exec -it ollama ollama pull qwen2.5-coder:14b
docker exec -it ollama ollama pull llama3.1:8b
```

Open WebUI에서 모델을 선택하고 Web Search를 켜면 됩니다.

## 5. 동작 방식

검색 없는 질문:

```text
Open WebUI -> Ollama
```

검색 켠 질문:

```text
Open WebUI -> SearXNG -> 검색 결과 수집 -> Ollama -> 답변
```

그래서 `docker exec -it ollama ollama run ...`으로 직접 실행할 때는 검색이 되지 않습니다. CLI 테스트는 모델 자체 테스트용이고, 실시간 검색 테스트는 Open WebUI에서 하는 것이 맞습니다.

## 문제 해결

SearXNG가 JSON을 반환하는지 확인:

```bash
curl 'http://localhost:8080/search?q=test&format=json'
```

Open WebUI 컨테이너에서 SearXNG가 보이는지 확인:

```bash
docker exec -it open-webui curl 'http://searxng:8080/search?q=test&format=json'
```

Open WebUI에서 `403 Forbidden`이 나오면 SearXNG 설정을 확인합니다.

```bash
cd ~/infra/searxng
grep -A5 'formats:' config/settings.yml
```

다음처럼 `json`이 있어야 합니다.

```yaml
formats:
  - html
  - json
```

컨테이너가 같은 네트워크에 있는지 확인:

```bash
docker inspect open-webui | grep -A3 8llow8llowme-net
docker inspect searxng | grep -A3 8llow8llowme-net
```

로그 확인:

```bash
docker logs -f open-webui
docker logs -f searxng
```

## 운영 팁

- Ollama API `11434`는 공개망에 직접 노출하지 않습니다.
- Open WebUI `3000`도 가능하면 VPN, SSH tunnel, Nginx 인증 뒤에 둡니다.
- SearXNG `8080`은 내부용으로 두고 외부에 직접 열지 않는 것을 권장합니다.
- 주가/뉴스처럼 최신성이 중요한 답변은 출처 링크를 확인합니다.
