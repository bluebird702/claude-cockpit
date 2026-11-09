# 로컬 개발 환경 표준

> 대상: cockpit 을 쓰는 모든 프로젝트의 로컬 개발 머신 설정.

## Docker 런타임: **이미 쓰는 런타임을 그대로 사용**

cockpit 은 특정 Docker 런타임을 강제하지 않습니다. `docker` 명령이 동작하면 어떤 런타임이든 됩니다.

| 환경 | 지원 런타임 예시 |
|------|----------------|
| macOS | Colima · Docker Desktop · OrbStack · Rancher Desktop |
| Linux | 네이티브 Docker Engine (`docker.io`·`docker-ce`·`moby`) |
| Windows | Docker Desktop (WSL2) |

- `install.sh` 의 Phase 1(`scripts/configure.sh`)이 설치된 런타임을 감지해 `.cockpit-local/.cockpit-env` 의 `DOCKER_RUNTIME` 에 기록합니다. 세션 시작 컨텍스트에도 표시됩니다.
- MCP 설치(`system/mcp-shared/setup.sh`)는 먼저 이미 동작 중인 런타임을 씁니다. 데몬이 꺼져 있고 Colima 가 설치돼 있으면 Colima 를 시작합니다.
- 런타임이 하나도 없을 때만 설치를 **제안**합니다(사용자 확인 필요). macOS + Homebrew 에서는 Colima 를 권장합니다.

### 런타임이 없을 때의 권장값 (macOS): Colima

라이선스 제약이 없고 리소스 사용량이 가볍습니다.

```bash
brew install colima docker docker-compose
```

*(Linux 는 배포판의 Docker Engine 을 설치하세요. 설치 가이드: https://docs.docker.com/engine/install/)*

## Colima 를 쓰는 경우

### 시작 / 종료

```bash
colima start --cpu 4 --memory 8 --disk 60
colima stop
colima status
```

프로젝트에서 더 많은 리소스가 필요한 경우 `--cpu 6 --memory 12` 등으로 조정하세요.

### Docker Compose

Colima 기동 후에는 `docker`, `docker compose` 명령을 그대로 사용할 수 있습니다.

```bash
docker compose up -d
docker compose logs -f gateway
```

### 자주 겪는 이슈

| 증상 | 원인 | 해결 |
|------|------|------|
| `Cannot connect to the Docker daemon` | Colima 미기동 | `colima start` |
| 빌드가 느림 | VM 리소스 부족 | `colima stop && colima start --cpu 6 --memory 12` |
| `mount` 실패 | 기본 마운트 경로 제한 | `colima start --mount $HOME:w` |
| M 시리즈 Mac 에서 이미지 호환성 | amd64 전용 이미지 | `colima start --arch x86_64` (별도 프로필 권장) |

### 프로필 분리 (선택)

프로젝트별로 리소스 차이가 크면 프로필을 나눕니다.

```bash
colima start --profile heavy --cpu 8 --memory 16
colima start --profile light --cpu 2 --memory 4
docker context use colima-heavy
```

## 다른 런타임을 쓰는 경우

| 증상 | 확인 |
|------|------|
| `Cannot connect to the Docker daemon` (Docker Desktop·OrbStack 등) | 앱이 실행 중인지 확인 |
| Linux 에서 `permission denied ... docker.sock` | `sudo systemctl start docker`, 사용자를 `docker` 그룹에 추가 후 재로그인 |
| 여러 런타임이 설치되어 엉뚱한 쪽에 연결됨 | `docker context ls` 로 확인 후 `docker context use <이름>` |

> 팀·개인 선호로 특정 런타임만 쓰기로 정했다면 `system/CLAUDE.md` 의 "로컬 환경 표준" 항목을 포크에서 바꾸세요 (개인 선호 슬롯).

## 관련 문서

- @docs/dev/project-structure.md — 서비스/인프라 디렉토리 구조
- @docs/dev/new-service-checklist.md — 새 서비스 추가 시 체크리스트
