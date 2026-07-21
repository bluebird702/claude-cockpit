# 로컬 개발 환경 표준

> 대상: cockpit 을 쓰는 모든 프로젝트의 로컬 개발 머신 설정.

## Docker 런타임: **Colima 사용**

Docker Desktop 대신 **Colima** 를 사용합니다. 라이선스 제약이 없고, 리소스 사용량이 가볍습니다.

### 설치 (macOS)

```bash
brew install colima docker docker-compose
```

*(참고: Linux 환경에서는 호스트의 네이티브 `docker` 데몬을 그대로 사용하므로 Colima가 필요하지 않습니다.)*

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

## Docker Desktop 사용 금지

Docker Desktop 은 팀 기준에 맞지 않으므로 설치/사용하지 않습니다. 이미 설치되어 있다면:

```bash
# Desktop 종료 후
brew uninstall --cask docker
brew install colima docker docker-compose
```

## 관련 문서

- @docs/dev/project-structure.md — 서비스/인프라 디렉토리 구조
- @docs/dev/new-service-checklist.md — 새 서비스 추가 시 체크리스트
