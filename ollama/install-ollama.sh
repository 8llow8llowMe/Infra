#!/usr/bin/env sh
# Ollama(Vulkan iGPU 가속) 와 Open WebUI 실행에 필요한 디렉터리를 준비하고 시작합니다.
# Radeon 780M 등 AMD iGPU 를 Mesa RADV 경유 Vulkan 백엔드로 사용합니다.

set -eu

if [ ! -f ./.env ]; then
  cp ./.env.example ./.env
  echo ".env.example을 복사해 .env를 생성했습니다. WEBUI_SECRET_KEY와 포트를 확인하세요."
fi

set -a
. ./.env
set +a

# render 그룹은 호스트 GID 기준으로 컨테이너에 주입해야 /dev/dri/renderD128 에 접근 가능합니다.
# .env 의 AMD_GPU_RENDER_GROUP 이 비어 있으면 호스트에서 자동 해석합니다.
if [ -z "${AMD_GPU_RENDER_GROUP:-}" ]; then
  RENDER_GID="$(getent group render | cut -d: -f3 || true)"
  if [ -z "$RENDER_GID" ]; then
    echo "호스트에 render 그룹이 없습니다. /dev/dri/renderD128 의 소유 그룹 GID 를 확인 후"
    echo ".env 의 AMD_GPU_RENDER_GROUP 에 숫자 GID 를 직접 지정하세요."
    exit 1
  fi
  AMD_GPU_RENDER_GROUP="$RENDER_GID"
  export AMD_GPU_RENDER_GROUP
  echo "render 그룹 GID 를 자동 해석했습니다: $AMD_GPU_RENDER_GROUP"
fi

mkdir -p "$OLLAMA_DATA_DIR" "$OPEN_WEBUI_DATA_DIR"

docker compose --env-file .env -f docker-compose-ollama.yml up -d

echo ""
echo "Ollama 스택이 시작되었습니다."
echo "Ollama API: http://<ai-host-ip>:${OLLAMA_PORT}"
echo "Open WebUI: http://<ai-host-ip>:${OPEN_WEBUI_PORT}"
echo ""
echo "GPU 인식 여부 확인 (Vulkan 초기화 실패 시 Ollama 는 조용히 CPU 로 폴백합니다):"
echo "  docker logs ${OLLAMA_CONTAINER_NAME} 2>&1 | grep -iE 'vulkan|radv'"
echo "  docker exec ${OLLAMA_CONTAINER_NAME} ollama ps"
