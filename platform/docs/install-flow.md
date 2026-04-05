# Install Flow · `install.sh` 오케스트레이션

> **⚠️ 설계 문서**: 이 파일은 최종 목표 상태의 설치 흐름을 기술합니다. 현재 구현 상태는 일부만 반영돼 있으며, 일부 Phase 는 특정 전제(제품 레포 접근, GitHub App 구성 등) 를 가정합니다. 본인 환경에서는 해당 Phase 를 건너뛰거나 재정의하세요.

> 목표: 첫 설치 시 **사람 개입 2~3 분**, 이후 재실행은 **10 초 이내** 완전 자동.

## 12 Phase 전체 흐름

```
[기존 8 Phase — 사람 cockpit]
  Phase 1   doctor              (필수·권장 CLI 진단)
  Phase 2   global link         (CLAUDE.md, settings.json, keybindings.json)
  Phase 3   skills link         (빈 카테고리 자동 skip)
  Phase 4   agents link         (humans/subagents/ → ~/.claude/agents)
  Phase 5   hooks verify        (chmod + bash -n)
  Phase 6   memory seed         (새 파일만, 기존 보존)
  Phase 7   MCP (옵션)          (--with-mcp)
  Phase 8   post-install check

[신규 4 Phase — 에이전트 플랫폼]
  Phase 9   Slack bootstrap     🔴 새로 추가
  Phase 10  Worker 이미지 빌드   🔴
  Phase 11  Worker 기동          🔴
  Phase 12  통합 헬스체크         🔴
```

## Phase 9 · Slack Bootstrap

가장 복잡한 Phase. Slack 의 자동화 한계를 "Bootstrapper App" 트릭으로 우회.

### 9.1 Bootstrapper App 존재 확인

```
check: op://cockpit/shared/slack-bootstrapper-token 존재?
  YES → skip 9.1
  NO  → 아래 대화형 루프 실행
```

**첫 설치만 실행하는 1회성 수동 단계**:

```
▸ Slack Bootstrapper App 필요합니다 (첫 설치 1회성)
▸ 브라우저에서 다음 URL 열립니다:
  https://api.slack.com/apps?new_app=1&manifest_yaml=...

  (manifest 는 cockpit/slack/bootstrapper-manifest.yaml 에서 자동 생성됨)

▸ 브라우저에서:
  1. "Create" 클릭
  2. "Install to Workspace" 클릭
  3. 권한 승인
  4. OAuth Token 복사 (xoxb- 로 시작)
  5. 여기 돌아와서 붙여넣기:

  Token > _
```

- 붙여넣은 토큰을 `op item create` 로 1Password 에 저장
- 이후 재설치 시 이 Phase 는 자동 skip

### 9.2 workspace.yaml → 채널 생성

```bash
yq '.channels[] | .name' slack/workspace.yaml | while read channel; do
  bootstrapper_api conversations.create \
    --name "$channel" \
    --is_private "$(yq ".channels[] | select(.name == \"$channel\") | .private" ...)"
done
```

Idempotent: 이미 존재하는 채널은 `already_exists` 에러를 무시하고 계속.

### 9.3 AGENT.md → Slack App Manifest 생성

```bash
for worker_dir in workers/*/; do
  name="$(basename "$worker_dir")"
  [[ "$name" == _* ]] && continue  # _runtime, _template 스킵

  python scripts/render-slack-manifest.py \
    --agent-md "$worker_dir/AGENT.md" \
    --template slack/templates/leader.yaml.tmpl \
    --output slack/manifests/$name.yaml
done

# CTO 서브워커
for sub in workers/cto/sub-workers/*/; do
  name="$(basename "$sub")"
  python scripts/render-slack-manifest.py \
    --agent-md "$sub/AGENT.md" \
    --template slack/templates/sub-worker.yaml.tmpl \
    --output slack/manifests/$name.yaml
done
```

### 9.4 Bootstrapper 로 일괄 앱 생성

```bash
for manifest in slack/manifests/*.yaml; do
  name="$(basename "$manifest" .yaml)"

  # 이미 생성됐는지 확인 (.cockpit/state.json)
  if jq -e ".slack_apps[\"$name\"]" .cockpit/state.json > /dev/null; then
    echo "  = $name (이미 생성됨)"
    continue
  fi

  # Bootstrapper admin token 으로 앱 생성
  result=$(curl -s https://slack.com/api/apps.manifest.create \
    -H "Authorization: Bearer $BOOTSTRAPPER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(yq -o json "$manifest" | jq -c '{manifest: .}')")

  app_id=$(echo "$result" | jq -r '.app_id')

  # state.json 에 기록
  jq ".slack_apps[\"$name\"] = \"$app_id\"" .cockpit/state.json > tmp.json
  mv tmp.json .cockpit/state.json

  echo "  + $name (app_id: $app_id)"
done
```

### 9.5 각 앱 Install to Workspace · Token 발급

이 단계만 앱당 **브라우저 클릭 1 회** 필요 (Slack 정책).

```
▸ 각 앱을 워크스페이스에 설치해주세요 (앱당 5초)

  [1/12] secretary
  → 브라우저 열림: https://api.slack.com/apps/A08XXXXX/install-on-team
  → "Allow" 클릭 후 엔터
  (대기 중...)

  [✓] cfo — bot token 획득 → op://cockpit/workers/cfo/slack-bot-token 저장
       app-level token 생성 → op://cockpit/workers/cfo/slack-app-token 저장

  [2/11] cmo
  ...
```

**12 개 앱 × 5 초 ≈ 1 분**. 이후 재실행 시 전부 skip.


### 9.6 채널에 봇 초대

```bash
# workspace.yaml 의 members 필드에 따라
for channel in ...; do
  for member in ...; do
    bootstrapper_api conversations.invite \
      --channel "$channel_id" \
      --users "$bot_user_id"
  done
done
```

Idempotent: 이미 멤버인 경우 무시.

## Phase 10 · Worker 이미지 빌드

```bash
docker build \
  -t cockpit-worker:latest \
  -f deploy/Dockerfile \
  .

# 태그
docker tag cockpit-worker:latest cockpit-worker:v$(date +%Y%m%d-%H%M%S)
```

`deploy/Dockerfile` 은 **공통 이미지**:
- Python 3.12 + uv
- `workers/_runtime/` 복사
- `workers/<name>/` 은 런타임 시 마운트 (이미지 재빌드 없이 AGENT.md 수정 가능)

이 구조 덕분에 AGENT.md 수정 후 재배포 = 컨테이너 재시작만. 빌드 불필요.

## Phase 11 · Worker 기동

### 로컬 모드 (Phase 0-1)

```bash
# deploy/local/docker-compose.yaml 렌더링
python scripts/render-compose.py \
  --workers-dir workers \
  --image cockpit-worker:latest \
  > deploy/local/docker-compose.yaml

# 기동
docker compose -f deploy/local/docker-compose.yaml up -d
```

각 워커는 독립 컨테이너. `docker compose ps` 로 상태 확인.

### Fly.io 모드 (Phase 1)

```bash
for worker_dir in workers/*/ workers/cto/sub-workers/*/; do
  name="$(basename "$worker_dir")"
  [[ "$name" == _* ]] && continue

  # fly.toml 렌더링
  python scripts/render-fly-toml.py \
    --agent-md "$worker_dir/AGENT.md" \
    > /tmp/fly-$name.toml

  # 배포
  fly deploy --app "cockpit-$name" --config /tmp/fly-$name.toml
done
```

### 기동 대기

각 컨테이너가 Slack Socket Mode 연결 완료까지 최대 30 초 대기. 완료되면 `#agent-ops` 에 "ready" 포스트.

## Phase 12 · 통합 헬스체크

```
▸ Slack 에서 모든 봇이 online 인지 확인
  bootstrapper_api users.info <bot_user_id> → presence: active

▸ 각 봇에 /status 핑
  DM 으로 /status 전송 → 30 초 내 응답 대기

▸ #agent-admin 에 최종 리포트 포스트
  "✅ 조직 기동 완료
   • 비서 1 명: Secretary
   • 리더 6 명: CFO, CMO, CPO, CDO, Design, CTO
   • 서브워커 5 명: backend-dev, frontend-dev, qa-dev, devops-dev, infra-dev
   • 총 12 봇 online
   • 누적 비용 (월초부터): $X.XX / 예산 $Y.YY"
```

## 실행 시나리오

### 첫 설치 (2~3 분)

```bash
$ cd ~/Work/claude-cockpit
$ ./install.sh

▸ Phase 1 · 환경 진단
  ✔ git 2.47.0
  ✔ python 3.12
  ✔ docker 27.3.1
  ✔ fly 0.3.0

▸ Phase 2~8 · 기존 cockpit 설치 ... (생략)
  ✔ 사람 cockpit 준비 완료

▸ Phase 9 · Slack bootstrap
  ℹ Bootstrapper App 필요 (첫 설치 1회성)
  ℹ 브라우저 열림... Token 붙여넣기 후 엔터: ****
  ✔ 채널 17 개 생성
  ✔ 12 개 매니페스트 렌더링
  ✔ 12 개 앱 생성
  ℹ 각 앱 Install to Workspace 필요 (앱당 5 초)
  ✔ [1/12] secretary
  ✔ [2/11] cmo
  ...
  ✔ [12/12] infra-dev
  ✔ 12 개 앱 워크스페이스 설치 · 토큰 저장 완료

▸ Phase 10 · Worker 이미지 빌드
  ✔ cockpit-worker:v20260405-143022

▸ Phase 11 · Worker 기동 (local mode)
  ✔ cfo, cmo, cpo, cdo, design-chief, cto 기동
  ✔ backend-dev, frontend-dev, qa-dev, devops-dev, infra-dev 기동

▸ Phase 12 · 통합 헬스체크
  ✔ 12 봇 모두 Slack online
  ✔ /status 핑 응답 11/11
  ✔ #agent-admin 최종 리포트 포스트

✅ 설치 완료 (총 2분 47초, 수동 입력 시간 1분 12초)
```

### 재실행 (10 초)

```bash
$ ./install.sh

▸ Phase 1~8  (변경 없음, skip)
▸ Phase 9    state.json 기반 skip
▸ Phase 10   이미지 캐시 히트, 재빌드 불필요
▸ Phase 11   docker-compose restart (AGENT.md 변경 감지)
▸ Phase 12   헬스체크 통과

✅ 설치 완료 (11 초)
```

### 새 봇 추가 (30 초 + 앱 설치 1 클릭)

```bash
$ ./scripts/worker-scaffold.sh --leader sales-lead
  ✔ workers/sales-lead/ 생성
  ✔ AGENT.md · persona.md 템플릿 복사

$ vi workers/sales-lead/AGENT.md  # 편집
$ ./install.sh
  ▸ Phase 9   새 worker sales-lead 감지 → 앱 생성 → OAuth 1 클릭 → 저장
  ▸ Phase 11  sales-lead 컨테이너 추가 기동
  ✔ 완료
```

### 봇 회수 (10 초)

```bash
$ ./scripts/worker-retire.sh design-chief

  ▸ 컨테이너 정지: cockpit-design-chief
  ▸ Slack 봇 presence → offline
  ▸ 1Password 아이템 archive (삭제 아님, 감사 대비)
  ▸ Slack App 은 삭제하지 않음 (수동 검토 후 삭제)
  ▸ #agent-admin 에 "design-chief 퇴사 처리 완료" 포스트
  ✔ 완료
```

## 자동화 가능 / 불가능 매트릭스

| 단계 | 자동 가능? | 비고 |
|---|---|---|
| Slack workspace 생성 | ❌ | 1회, 이미 있으면 무관 |
| Bootstrapper App 생성 | 🟡 | manifest URL 자동 오픈, "Create" 1 클릭 |
| Bootstrapper 워크스페이스 설치 | 🟡 | "Allow" 1 클릭 |
| 12 봇 앱 생성 | ✅ | `apps.manifest.create` API |
| 각 봇 워크스페이스 설치 | 🟡 | 앱당 "Allow" 1 클릭 (11회) |
| Bot Token 발급 | ✅ | 설치 직후 API 로 조회 |
| 1Password 저장 | ✅ | `op item create` |
| 채널 생성 · 멤버 초대 | ✅ | `conversations.*` API |
| GitHub App 생성 | ❌ | Slack 과 유사, 별도 1 회 설정 |
| GitHub App 설치 | 🟡 | 대상 제품 레포에 "Install" 클릭 |
| Docker 이미지 빌드 | ✅ | |
| 컨테이너 기동 | ✅ | docker compose / fly deploy |
| 헬스체크 | ✅ | |

**총 수동 클릭 수**: 첫 설치 14 회 (Bootstrapper 2 + 12 봇 1 회씩). **시간**: 1~2 분. 이후 재설치·업데이트 시 0.

## Idempotency 보장

모든 Phase 는 **"이미 있으면 skip"** 원칙. `.cockpit/state.json` 이 상태를 추적:

```json
{
  "version": "1.0",
  "installed_at": "2026-04-05T14:30:22+09:00",
  "last_run_at": "2026-04-05T16:12:45+09:00",
  "slack_apps": {
    "cfo": "A08XXXX1",
    "cmo": "A08XXXX2",
    ...
  },
  "channels": {
    "engineering": "C08YYYY1",
    ...
  },
  "workers_running": ["cfo", "cmo", "cpo", "cdo", "design-chief", "cto",
                      "backend-dev", "frontend-dev", "qa-dev",
                      "devops-dev", "infra-dev"]
}
```

`install.sh` 가 idempotent 하다는 건 **매일 돌려도 아무 것도 망가지지 않는다** 는 뜻. 이게 재현 가능성의 핵심이다.

## 실패 복구

```bash
./install.sh --verify    # 현재 상태 검증만, 변경 없음
./install.sh --repair    # 틀어진 부분만 복구 (ex: 컨테이너 꺼진 봇 재기동)
./install.sh --force     # 모든 Phase 강제 재실행
./install.sh --phase 11  # 특정 Phase 만 실행
```

## Phase 별 소요 시간 (목표)

| Phase | 첫 설치 | 재실행 |
|---|---|---|
| 1 doctor | 3 s | 3 s |
| 2-8 기존 | 5 s | 1 s |
| 9 Slack | **1~2 min** (수동 입력 포함) | 1 s |
| 10 이미지 빌드 | 30 s | 2 s (캐시) |
| 11 기동 | 30 s | 5 s |
| 12 헬스체크 | 15 s | 5 s |
| **합계** | **~3 min** | **~17 s** |
