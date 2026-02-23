# Docker 설치 가이드

Ubuntu 서버에 Docker Engine 및 Docker Compose를 설치하기 위한 스크립트입니다.

---

## 지원 환경

| OS     | 버전              | 아키텍처   |
|--------|-------------------|------------|
| Ubuntu | 20.04, 22.04, 24.04 | amd64      |
| Ubuntu | 20.04, 22.04, 24.04 | arm64      |

- **일반(amd64)**: `install-docker.sh`
- **ARM64**: `install-docker-arm64.sh`

---

## 파일 구조

```
Docker/
├── install-docker.sh        # Docker 설치 (일반/amd64)
├── install-docker-arm64.sh  # Docker 설치 (ARM64 전용)
├── setup-docker-user.sh     # 사용자 docker 그룹 추가
├── uninstall-docker.sh      # Docker 완전 제거
└── README.md                # 이 문서
```

---

## 설치 방법

### 1단계: 스크립트 실행 권한 부여

```bash
cd Docker
chmod +x *.sh
```

### 2단계: Docker 설치

**일반 서버 (amd64):**

```bash
sudo ./install-docker.sh
```

**ARM64 서버:**

```bash
sudo ./install-docker-arm64.sh
```

설치 내용:

- Docker Engine (docker-ce)
- Docker CLI
- containerd
- Docker Buildx
- Docker Compose v2 (플러그인)

### 3단계: 사용자 권한 설정

```bash
sudo ./setup-docker-user.sh
```

또는 수동으로:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 4단계: 설치 확인

```bash
# Docker 버전
docker --version

# Docker Compose 버전
docker compose version

# 테스트
docker run hello-world
```

---

## 스크립트 상세

### install-docker.sh

일반(amd64) Ubuntu용 Docker 설치. 아키텍처 자동 감지, arm64에서 실행 시 안내 후 선택 가능.

**수행 작업:**

1. 기존 Docker 관련 패키지 제거 (충돌 방지)
2. 필수 패키지 설치 (ca-certificates, curl, gnupg)
3. Docker 공식 GPG 키 추가
4. Docker APT 저장소 추가
5. Docker Engine 설치
6. Docker 서비스 활성화 및 시작

**요구 권한:** root (sudo)

### install-docker-arm64.sh

ARM64 전용 설치. arm64가 아니면 종료.

**요구 권한:** root (sudo)

### setup-docker-user.sh

현재 사용자를 docker 그룹에 추가합니다.

**효과:** `sudo` 없이 `docker` 명령 실행 가능

**요구 권한:** root (sudo)

**주의:** 그룹 변경 후 재로그인 또는 `newgrp docker` 필요

### uninstall-docker.sh

Docker를 완전히 제거합니다.

**삭제 대상:**

- Docker Engine 및 관련 패키지
- 모든 컨테이너, 이미지, 볼륨
- Docker 설정 파일
- APT 저장소 설정

**요구 권한:** root (sudo)

---

## 설치 후 설정 (선택)

### Docker 로그 로테이션

`/etc/docker/daemon.json` 생성:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

적용:

```bash
sudo systemctl restart docker
```

### Docker 데이터 디렉토리 변경

기본값: `/var/lib/docker`

`/etc/docker/daemon.json`에 추가:

```json
{
  "data-root": "/data/docker"
}
```

### Docker 메모리 제한

`/etc/docker/daemon.json`에 추가:

```json
{
  "default-ulimits": {
    "memlock": {
      "Name": "memlock",
      "Hard": -1,
      "Soft": -1
    }
  }
}
```

---

## 운영 명령어

### 서비스 관리

```bash
# 상태 확인
sudo systemctl status docker

# 재시작
sudo systemctl restart docker

# 중지
sudo systemctl stop docker

# 부팅 시 자동 시작 설정
sudo systemctl enable docker
```

### 디스크 정리

```bash
# 사용하지 않는 리소스 정리
docker system prune

# 모든 미사용 리소스 정리 (이미지 포함)
docker system prune -a

# 볼륨까지 정리
docker system prune -a --volumes
```

### 정보 확인

```bash
# Docker 정보
docker info

# 디스크 사용량
docker system df

# 실행 중인 컨테이너
docker ps

# 모든 컨테이너
docker ps -a

# 이미지 목록
docker images
```

---

## 문제 해결

### permission denied 오류

```text
Got permission denied while trying to connect to the Docker daemon socket
```

해결:

```bash
sudo usermod -aG docker $USER
newgrp docker
# 또는 재로그인
```

### Cannot connect to the Docker daemon

```bash
# 서비스 상태 확인
sudo systemctl status docker

# 서비스 시작
sudo systemctl start docker
```

### 디스크 공간 부족

```bash
# 현재 사용량 확인
docker system df

# 정리
docker system prune -a --volumes
```

### GPG 키 오류

```bash
# 키 재설치
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo apt-get update
```

---

## 참고 자료

- [Docker 공식 문서 - Ubuntu 설치](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Compose 공식 문서](https://docs.docker.com/compose/)
- [Docker Post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)
