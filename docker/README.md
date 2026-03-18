# Docker 설치 가이드

Ubuntu 서버에 Docker Engine 및 Docker Compose를 설치하기 위한 스크립트입니다.

공통 설치 로직은 유지하면서도, CPU 아키텍처별로 실행 파일을 분리하여 IaC 관점에서 관리하기 쉽게 정리했습니다.

---

## 지원 환경

| OS     | 버전                | 아키텍처     |
| ------ | ------------------- | ------------ |
| Ubuntu | 20.04, 22.04, 24.04 | amd64, arm64 |

---

## 파일 구조

```text
docker/
├── install-common.sh        # Docker 설치 공통 로직
├── install-docker.sh        # 아키텍처 자동 감지 후 설치 실행
├── install-docker-amd64.sh  # amd64 전용 설치 스크립트
├── install-docker-arm64.sh  # arm64 전용 설치 스크립트
├── setup-docker-user.sh     # 현재 사용자를 docker 그룹에 추가
├── uninstall-docker.sh      # Docker 완전 제거
└── README.md                # 이 문서
```

---

## 설치 방법

### 1단계: 저장소 이동 및 실행 권한 부여

```bash
cd docker
chmod +x *.sh
```

### 2단계: Docker 설치

일반적으로는 아키텍처 자동 감지 스크립트를 실행하면 됩니다.

```bash
sudo ./install-docker.sh
```

설치 스크립트는 현재 서버의 CPU 아키텍처를 감지한 뒤 아래 스크립트 중 하나를 자동으로 실행합니다.

- `amd64` 서버: `install-docker-amd64.sh`
- `arm64` 서버: `install-docker-arm64.sh`

직접 지정해서 실행하고 싶다면 다음과 같이 사용할 수 있습니다.

```bash
sudo ./install-docker-amd64.sh
sudo ./install-docker-arm64.sh
```

설치 내용:

- Docker Engine (`docker-ce`)
- Docker CLI (`docker-ce-cli`)
- `containerd`
- Docker Buildx 플러그인
- Docker Compose v2 플러그인

### 3단계: 사용자 권한 설정

```bash
sudo ./setup-docker-user.sh
```

또는 수동으로 설정할 수도 있습니다.

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 4단계: 설치 확인

```bash
# Docker 버전 확인
docker --version

# Docker Compose 버전 확인
docker compose version

# Docker 데몬 접근 확인
docker ps
```

필요하면 테스트 이미지도 실행해볼 수 있습니다.

```bash
docker run --rm hello-world
```

---

## 스크립트 상세

### install-common.sh

Docker 설치의 공통 로직을 담당하는 내부용 스크립트입니다.

주요 역할:

1. root 권한 확인
2. Ubuntu 환경 확인
3. 아키텍처 검증
4. 기존 Docker 패키지 제거
5. 필수 패키지 설치
6. Docker 공식 GPG 키 등록
7. Docker APT 저장소 등록
8. Docker Engine 및 Compose 플러그인 설치
9. Docker 서비스 활성화 및 시작
10. 설치 결과 확인

직접 실행하기보다는 `install-docker*.sh` 에서 불러서 사용하는 용도입니다.

### install-docker.sh

Docker 설치 진입 스크립트입니다.

역할:

1. root 권한 확인
2. Ubuntu 환경 확인
3. 현재 CPU 아키텍처 확인
4. 맞는 설치 스크립트로 자동 분기

운영자가 가장 먼저 실행하면 되는 기본 스크립트입니다.

### install-docker-amd64.sh

`amd64` 서버 전용 Docker 설치 스크립트입니다.

용도:

- x86_64 기반 Ubuntu 서버 설치
- CI 서버, 일반 VM, 물리 서버 등에서 사용

### install-docker-arm64.sh

`arm64` 서버 전용 Docker 설치 스크립트입니다.

용도:

- ARM 기반 클라우드 인스턴스
- ARM 서버 또는 ARM 개발 환경에서 사용

### setup-docker-user.sh

현재 사용자를 `docker` 그룹에 추가하는 스크립트입니다.

효과:

- `sudo` 없이 `docker` 명령 실행 가능

주의사항:

- 적용 후 재로그인하거나 `newgrp docker` 실행 필요
- Docker가 먼저 설치되어 있어야 함

### uninstall-docker.sh

Docker를 완전히 제거하는 스크립트입니다.

삭제 대상:

- Docker Engine
- Docker CLI
- Docker Compose 플러그인
- `containerd`
- Docker 데이터 디렉터리
- Docker 설정 파일
- Docker APT 저장소 정보 및 GPG 키

주의사항:

- `/var/lib/docker` 와 `/var/lib/containerd` 가 삭제되므로 컨테이너, 이미지, 볼륨 데이터가 함께 사라질 수 있습니다.

---

## 설치 후 추가 설정

### Docker 로그 로테이션 설정

운영 환경에서는 로그가 무한정 쌓이지 않도록 설정하는 것을 권장합니다.

`/etc/docker/daemon.json` 파일 예시:

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

### Docker 데이터 디렉터리 변경

기본 데이터 경로는 `/var/lib/docker` 입니다.

디스크 분리를 원한다면 다음과 같이 설정할 수 있습니다.

```json
{
  "data-root": "/data/docker"
}
```

적용 후에는 Docker 재시작이 필요합니다.

```bash
sudo systemctl restart docker
```

### 메모리 잠금 제한 설정

특정 워크로드에서 `memlock` 설정이 필요하다면 다음과 같이 구성할 수 있습니다.

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

# 시작
sudo systemctl start docker

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

# 모든 미사용 리소스 정리(이미지 포함)
docker system prune -a

# 볼륨까지 정리
docker system prune -a --volumes
```

### 정보 확인

```bash
# Docker 상세 정보
docker info

# 디스크 사용량
docker system df

# 실행 중인 컨테이너
docker ps

# 전체 컨테이너
docker ps -a

# 이미지 목록
docker images
```

---

## 문제 해결

### 1. permission denied 오류

오류 예시:

```bash
Got permission denied while trying to connect to the Docker daemon socket
```

해결 방법:

```bash
sudo ./setup-docker-user.sh
newgrp docker
```

또는:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Cannot connect to the Docker daemon

확인 및 조치:

```bash
sudo systemctl status docker
sudo systemctl start docker
```

### 3. 디스크 공간 부족

확인:

```bash
docker system df
```

정리:

```bash
docker system prune -a --volumes
```

### 4. GPG 키 또는 저장소 오류

다음 명령으로 키를 다시 설정할 수 있습니다.

```bash
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update
```

### 5. 잘못된 아키텍처 스크립트를 실행한 경우

예를 들어 `arm64` 서버에서 `install-docker-amd64.sh` 를 실행하면 아키텍처 검증 단계에서 종료됩니다.

권장 방식:

```bash
sudo ./install-docker.sh
```

자동 감지 스크립트를 사용하면 실수를 줄일 수 있습니다.

---

## 참고 자료

- [Docker 공식 문서 - Ubuntu 설치](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Compose 공식 문서](https://docs.docker.com/compose/)
- [Docker Post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)
