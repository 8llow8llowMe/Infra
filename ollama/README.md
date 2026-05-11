# Ollama 운영 가이드

이 디렉터리는 미니PC `ai-host`에서 Ollama와 Open WebUI를 Docker Compose로 운영하기 위한 구성입니다.

현재 장비는 Ryzen 7 8845HS, Radeon 780M, RAM 32GB급이므로 기본 운영은 일반 Ollama 이미지로 안정화하고, AMD ROCm 가속은 별도 override compose로 테스트하는 방식을 권장합니다.

## ollama와 ollama-rocm 차이

`docker-compose-ollama.yml`은 기본 구성입니다.

- `ollama/ollama:latest` 이미지를 사용합니다.
- CPU 실행을 기본 전제로 둡니다.
- Linux 호스트의 GPU 장치를 컨테이너에 넘기지 않습니다.
- 가장 단순하고 안정적인 운영 모드입니다.
- Open WebUI는 같은 compose 안에서 `http://ollama:11434`로 Ollama에 연결됩니다.

`docker-compose-ollama-rocm.yml`은 단독 실행용이 아니라 override 구성입니다.

- Ollama 이미지를 `ollama/ollama:rocm`으로 바꿉니다.
- Linux 호스트의 AMD GPU 장치인 `/dev/kfd`, `/dev/dri`를 컨테이너에 넘깁니다.
- 컨테이너를 `video` 그룹에 추가합니다.
- `HSA_OVERRIDE_GFX_VERSION` 값을 주입해 Radeon 780M 같은 일부 AMD iGPU 환경을 테스트할 수 있게 합니다.

즉, 기본 compose는 “안정 운영용”, ROCm compose는 “AMD GPU 가속 실험용 덮어쓰기”입니다.

실행 차이는 이렇습니다.

```bash
# 기본 CPU/일반 모드
docker compose --env-file .env -f docker-compose-ollama.yml up -d

# AMD ROCm override 모드
docker compose --env-file .env \
  -f docker-compose-ollama.yml \
  -f docker-compose-ollama-rocm.yml \
  up -d
```

Radeon 780M은 내장 GPU라 ROCm 가속이 항상 안정적으로 동작한다고 보기 어렵습니다. 먼저 기본 모드로 모델과 Open WebUI를 안정화한 뒤, 필요할 때 ROCm override를 테스트하는 편이 좋습니다.

## 파일 구조

```text
ollama/
├── docker-compose-ollama.yml
├── docker-compose-ollama-rocm.yml
├── install-ollama.sh
├── install-ollama-rocm.sh
├── pull-model.sh
├── .env.example
├── .gitignore
└── README.md
```

실행 후 생성되는 로컬 데이터:

- `ollama-data/`: Ollama 모델과 설정
- `open-webui-data/`: Open WebUI 사용자/설정 데이터

## 환경변수

```bash
cd ollama
cp .env.example .env
```

Compose 파일에는 기본값을 넣지 않습니다. 실행 전에 `.env`를 준비해야 합니다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `OLLAMA_IMAGE` | 기본 Ollama 이미지 | `ollama/ollama:latest` |
| `OLLAMA_ROCM_IMAGE` | ROCm Ollama 이미지 | `ollama/ollama:rocm` |
| `OLLAMA_CONTAINER_NAME` | Ollama 컨테이너 이름 | `ollama` |
| `OLLAMA_PORT` | Ollama 외부 포트 | `11434` |
| `OLLAMA_CONTAINER_PORT` | Ollama 컨테이너 포트 | `11434` |
| `OLLAMA_HOST` | Ollama listen 주소 | `0.0.0.0:11434` |
| `OLLAMA_KEEP_ALIVE` | 모델 메모리 유지 시간 | `24h` |
| `OLLAMA_NUM_PARALLEL` | 동시 추론 수 | `1` |
| `OLLAMA_DATA_DIR` | 호스트 모델 데이터 경로 | `./ollama-data` |
| `OLLAMA_CONTAINER_DATA_DIR` | 컨테이너 모델 데이터 경로 | `/root/.ollama` |
| `OPEN_WEBUI_IMAGE` | Open WebUI 이미지 | `ghcr.io/open-webui/open-webui:main` |
| `OPEN_WEBUI_CONTAINER_NAME` | Open WebUI 컨테이너 이름 | `open-webui` |
| `OPEN_WEBUI_PORT` | Open WebUI 외부 포트 | `3000` |
| `OPEN_WEBUI_CONTAINER_PORT` | Open WebUI 컨테이너 포트 | `8080` |
| `OPEN_WEBUI_OLLAMA_BASE_URL` | WebUI가 사용할 Ollama 내부 주소 | `http://ollama:11434` |
| `OPEN_WEBUI_DATA_DIR` | 호스트 WebUI 데이터 경로 | `./open-webui-data` |
| `OPEN_WEBUI_CONTAINER_DATA_DIR` | 컨테이너 WebUI 데이터 경로 | `/app/backend/data` |
| `WEBUI_SECRET_KEY` | WebUI 세션 암호화 키 | 긴 랜덤 문자열 |
| `AMD_GPU_KFD_DEVICE` | ROCm KFD 장치 | `/dev/kfd` |
| `AMD_GPU_DRI_DEVICE` | ROCm DRI 장치 | `/dev/dri` |
| `AMD_GPU_GROUP` | GPU 접근 그룹 | `video` |
| `HSA_OVERRIDE_GFX_VERSION` | AMD iGPU 테스트용 GFX override | `11.0.0` |
| `TZ` | 컨테이너 타임존 | `Asia/Seoul` |

`WEBUI_SECRET_KEY`는 운영 전에 반드시 바꿉니다.

Docker json 로그는 compose에서 `max-size: "10m"`, `max-file: "3"`으로 고정합니다.
Docker 네트워크 이름은 compose에서 `8llow8llowme-net`으로 고정합니다.

SearXNG를 붙여 웹 검색을 사용하려면 [README-SEARXNG.md](README-SEARXNG.md)를 참고합니다.

## 실행

기본 모드:

```bash
cd ollama
sh install-ollama.sh
```

직접 실행:

```bash
cd ollama
docker compose --env-file .env -f docker-compose-ollama.yml up -d
```

Ollama만 실행:

```bash
docker compose --env-file .env -f docker-compose-ollama.yml up -d ollama
```

ROCm 모드:

```bash
cd ollama
sh install-ollama-rocm.sh
```

상태 확인:

```bash
docker compose --env-file .env -f docker-compose-ollama.yml ps
docker logs -f ollama
docker logs -f open-webui
```

중지:

```bash
docker compose --env-file .env -f docker-compose-ollama.yml down
```

## 접속

Ollama API:

```text
http://<ai-host-ip>:11434
```

Open WebUI:

```text
http://<ai-host-ip>:3000
```

Docker 네트워크 내부에서는 다음 주소를 사용합니다.

```text
http://ollama:11434
```

## 모델 설치

권장 시작 모델:

```bash
sh pull-model.sh qwen2.5-coder:7b
sh pull-model.sh llama3.1:8b
sh pull-model.sh mistral:7b
```

직접 실행:

```bash
docker exec -it ollama ollama pull qwen2.5-coder:7b
docker exec -it ollama ollama run qwen2.5-coder:7b
```

32GB RAM 장비에서는 7B/8B quant 모델 위주로 시작하는 것을 권장합니다. 14B 이상은 실행 가능하더라도 Jenkins, Vault, 관제 서비스와 메모리를 공유하므로 응답 지연이나 메모리 압박이 생길 수 있습니다.

## 운영 주의사항

- `ollama-data/`, `open-webui-data/`, `.env`는 Git에 커밋하지 않습니다.
- 모델 파일은 용량이 크므로 SSD 여유 공간을 주기적으로 확인합니다.
- `OLLAMA_NUM_PARALLEL=1`로 시작하고, 여유가 확인되면 2 이상을 테스트합니다.
- API 포트 `11434`는 공개망에 직접 노출하지 않습니다.
- Open WebUI를 외부에 열어야 한다면 Nginx TLS, 인증, IP allowlist를 먼저 구성합니다.
- Jenkins/Vault와 같은 호스트에서 운영하므로 큰 모델을 상시 로드하지 않도록 관리합니다.

## 백업과 복구

백업 대상:

- `.env`
- `open-webui-data/`
- 필요한 경우 `ollama-data/`

모델은 다시 pull 받을 수 있으므로, 백업 시간이 부담되면 `ollama-data/`는 제외할 수 있습니다.

백업 예시:

```bash
cd ollama
tar czf ollama-backup-$(date +%Y%m%d).tar.gz .env open-webui-data
```

복구 예시:

```bash
cd ollama
tar xzf ollama-backup-YYYYMMDD.tar.gz
docker compose --env-file .env -f docker-compose-ollama.yml up -d
```

## 문제 해결

Ollama API 확인:

```bash
curl http://localhost:11434/api/tags
```

컨테이너 로그:

```bash
docker logs -f ollama
docker logs -f open-webui
```

모델 목록:

```bash
docker exec -it ollama ollama list
```

디스크 사용량:

```bash
du -sh ollama-data open-webui-data
```
