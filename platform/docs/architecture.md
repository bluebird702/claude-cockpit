# Architecture · 레포 · 런타임 · Slack

> **⚠️ 이 문서는 특정 레포 구성(`product-repo`, `knowledge-repo`)과 Slack workspace 배치를 전제한 샘플 설계입니다.** 제품명·레포 구성·채널 구조는 하나의 예시이니 본인 환경에 맞춰 재구성하세요. 전체 공지는 [`platform/docs/README.md`](./README.md) 참조.

## 레포 3 층 구조

```
~/Work/
├ claude-cockpit/    조직 인프라 · 에이전트 플랫폼 · Slack 부트스트랩
│                    "회사 OS + HR + 배치 자동화"
│
├ product-repo/      실제 제품 코드 (monorepo: platform/, ops/, e2e/, docs/)
│                    "일감이 여기 있음"
│                    cockpit 의 worker 들이 GitHub App 으로 드나듦
│
└ knowledge-repo/    (신규, Phase 3+) ADR · runbook · postmortem
                     초기엔 product-repo/docs/ 안에 두다가
                     리더 봇들이 PR 로 지식을 쌓기 시작하면 분리
```

### 경계 원칙

- **cockpit 은 product-repo 의 코드를 복사·포함하지 않는다**. 참조만.
- **product-repo 는 worker 런타임을 호스트하지 않는다**. cockpit 이 호스트.
- **product-repo 각 디렉토리의 `.claude/CLAUDE.md`** 는 cockpit 의 baseline 을 `@import` 로 상속한다.
- **secrets / identity 는 cockpit**, **제품 데이터는 product-repo**, **지식은 knowledge 레포**.

## claude-cockpit 레포 디렉토리

```
claude-cockpit/
├ core/                              전사 baseline — 전 worker + 전 사람 공통
│  ├ CLAUDE.md                        회사 톤 (한글·존댓말·코딩 원칙)
│  ├ settings.json                    권한 baseline
│  ├ standards/                       언어별 (python, ts, go, sql, k8s, tf)
│  ├ hooks/                           보안 훅 5 종 (현재 scripts/hooks/)
│  ├ mcp-shared/                      전원 공유 MCP (github, knowledge, slack)
│  └ memory-seed/
│     └ company-facts.md              회사 기본 사실·도구·프로세스
│
├ humans/                            CEO 및 미래 인간 직원의 대화형 도구
│  ├ skills/                          /review:*, /dev:*, /mgmt:*, ...
│  └ subagents/                       Task 툴 서브에이전트 (현재 agents/)
│
├ workers/                           🔴 에이전트 직원 정의
│  ├ _runtime/                        공통 런타임 (한 번만 작성, 모든 워커 공유)
│  │  ├ bolt_adapter.py               Slack Bolt 래퍼
│  │  ├ claude_adapter.py             Claude Agent SDK 래퍼
│  │  ├ loop_guard.py                 5 중 루프 방어
│  │  ├ budget.py                     토큰·USD 추적
│  │  ├ memory.py                     불변/가변 메모리 분리
│  │  ├ hitl.py                       리액션 승인 대기
│  │  ├ audit.py                      JSONL 로그 append
│  │  ├ delegation.py                 리더→하위 워커 위임 프로토콜
│  │  └ commands.py                   /status /pause /resume /budget 공통 핸들러
│  │
│  ├ _template/                       새 worker 스캐폴드
│  │
│  ├ secretary/                       🟢 CEO 운영 보조 (C-suite 아님, CEO 직속)
│  │  ├ AGENT.md                      읽기 우선, 모든 쓰기는 HITL
│  │  ├ persona.md                    비서 톤 · 프로액티브 수준
│  │  ├ memory-seed/
│  │  │  ├ role.md                    브리핑 · 일정 · TODO 추적
│  │  │  ├ boundaries.md              외부 발송 · 계약 서명 금지
│  │  │  └ conventions.md             CEO 일일 리듬 · 선호 브리핑 포맷
│  │  └ tools.yaml                    Calendar / Gmail / Notion / 리더 멘션 권한
│  │
│  ├ cfo/                             재무/회계
│  │  ├ AGENT.md                      역할·권한·채널·예산 (YAML frontmatter + 본문)
│  │  ├ persona.md                    말투·의사결정 스타일
│  │  ├ skills/                       이 리더 전용 스킬 (있으면)
│  │  ├ memory-seed/
│  │  │  ├ role.md                    불변: 책임 범위
│  │  │  ├ boundaries.md              불변: 금지사항
│  │  │  └ conventions.md             회계 원칙, 결산 주기, 도구
│  │  ├ runbooks/                     월마감, 세금 신고 프로세스
│  │  └ tools.yaml                    접근 가능 MCP (회계 SaaS 등)
│  │
│  ├ cmo/                             ↓ cfo 와 동일 구조
│  ├ cpo/
│  ├ cdo/                             Chief Data Officer
│  ├ design-chief/                    Head of Design
│  │
│  └ cto/                             개발 리더 (유일한 계층형)
│     ├ AGENT.md
│     ├ persona.md
│     ├ delegates.yaml                위임 라우팅 규칙
│     ├ memory-seed/
│     │  └ repo-map.md                product-repo 구조·서비스 경계
│     └ sub-workers/
│        ├ backend-dev/
│        │  ├ AGENT.md
│        │  ├ persona.md
│        │  ├ scope.yaml              product-repo 내 관할 경로 (allowed / read-only / forbidden)
│        │  ├ memory-seed/
│        │  └ runbooks/
│        ├ frontend-dev/
│        ├ qa-dev/
│        ├ devops-dev/
│        └ infra-dev/
│
├ slack/                             Slack workspace 선언 (Infrastructure as Code)
│  ├ workspace.yaml                   채널·그룹·멤버십 선언
│  ├ manifests/                       자동 생성: 각 worker 의 Slack App Manifest
│  ├ templates/                       manifest 생성 템플릿
│  │  ├ leader.yaml.tmpl
│  │  └ sub-worker.yaml.tmpl
│  └ bootstrap.sh                     Slack 부트스트랩 엔트리포인트
│
├ deploy/
│  ├ local/                           Phase 0-1: 노트북/홈랩
│  │  ├ docker-compose.yaml
│  │  └ launchd/                      macOS LaunchAgent plist
│  ├ fly/                             Phase 1: Fly.io 무료 티어 (권장)
│  │  ├ fly.toml                      봇당 하나
│  │  └ Dockerfile
│  ├ cloud-run/                       Phase 2+: GCP Cloud Run 확장
│  │  └ terraform/
│  └ Dockerfile                       공통 worker 이미지
│
├ secrets/
│  └ schema.yaml                      1Password 아이템 네이밍 규약 (실제 값 X)
│
├ knowledge/                         Phase 3+ 시드 (ADR·runbook·postmortem)
│
├ scripts/
│  ├ install.sh                       12 Phase 오케스트레이터
│  ├ phases/
│  │  ├ 09-slack-bootstrap.sh         🔴 신규
│  │  ├ 10-worker-provision.sh        🔴 신규
│  │  └ 11-worker-launch.sh           🔴 신규
│  ├ worker-scaffold.sh               새 worker 템플릿 생성
│  ├ worker-run.sh                    로컬 디버그용
│  ├ worker-logs.sh                   audit.log tail
│  └ worker-retire.sh                 봇 회수 (컨테이너 정지, 토큰 archive)
│
├ docs/agent-platform/                이 문서 폴더
└ .cockpit/
   └ state.json                       설치 상태, 봇 ID, 마지막 기동 시각
```

## AGENT.md 스키마

한 봇의 모든 선언이 이 파일 하나에서 파생된다. 변경은 PR 리뷰 대상 = **봇의 "고용 조건" 수정은 감사 절차를 거친다.**

```yaml
---
name: cto
role: "개발 리더 — 코드 리뷰, 아키텍처 결정, PR 게이트"
model:
  leader: claude-opus-4-6
  delegates: claude-sonnet-4-6
  routing: claude-haiku-4-5

slack:
  app_id: A08XXXXX
  bot_user_id: U08XXXXX
  socket_mode: true
  home_channel: "#engineering"
  admin_channel: "#agent-admin"
  listen_channels: ["#engineering", "#eng-backend", "#eng-frontend",
                    "#eng-qa", "#eng-devops", "#eng-infra", "#leaders-lounge"]
  subscriptions: [app_mention, message.im, reaction_added]

interaction:
  can_initiate_thread: false          # 사람이 시작
  except_triggers: [github_event, cron]
  can_mention_other_agents: true      # CPO 등과 협업 가능
  max_turns_per_thread: 10
  ignore_other_bots: true             # @mention 시에만 예외
  mention_rate_per_minute: 5

permissions:
  inherits: core/baseline
  bash_allow_extra: ["gh pr *", "git *", "pytest *"]
  github_app: cto
  can_merge_pr: false                 # 사람 승인 필요
  can_push_to_main: false

budget:
  tokens_per_thread: 500000
  usd_per_day: 30
  usd_per_month: 600

hitl_gates:
  - condition: "pr.touches('ops/terraform/**')"
    action: "#infra 담당자 리액션 승인 필요"
  - condition: "pr.touches('**/migrations/**')"
    action: "CEO DM 승인 필요"

loop_guard:
  enable: true
  max_agent_turns_without_human: 5

delegates:
  path: ./delegates.yaml              # 서브워커 라우팅

memory:
  seed_dir: ./memory-seed
  mutable_dir: ~/.cockpit-agents/cto/memory/long-term
  max_mutable_mb: 50

commands:
  - /status
  - /pause
  - /resume
  - /budget
  - /trace <thread_ts>
  - /review <pr-number-or-url>
---

# 역할

당신은 CTO 입니다. 15년 경력의 백엔드 리더이며, product-repo 의 모든 코드 변경에
최종 책임이 있습니다. ...

# 업무 범위

- 코드 리뷰 (standards/ 위반, 보안, 논리 오류, 테스트 누락)
- 아키텍처 결정 (ADR 작성, 트레이드오프 분석)
- 서브워커 위임 (delegates.yaml 규칙)
- 장애 초기 대응 (infra 에스컬레이션)

# 경계

- 코드를 main 에 직접 push 하지 않습니다
- 머지는 항상 사람 승인을 기다립니다
- 프로덕션 배포는 infra + CEO 이중 승인 필요
- 고객 데이터가 담긴 예시 금지
```

## Slack Workspace 설계

### 채널 구조

```
# 경영 · 리더 레벨 (CEO 직접 접근)
#agent-admin           CEO 통제 센터 · 패닉 버튼
#agent-ops             봇 기동/에러/예산 자동 스트림
#leaders-lounge        6 명 리더 봇 간 협업 전용

# 리더별 홈
#finance               @CFO
#marketing             @CMO
#planning              @CPO
#design                @Design
#data                  @CDO
#engineering           @CTO

# 개발 하위 (CTO + 서브워커 + 사람 개발자)
#eng-backend           @backend-dev
#eng-frontend          @frontend-dev
#eng-qa                @qa
#eng-devops            @devops
#eng-infra             @infra

# 프로젝트 (동적 생성)
#proj-*

# 사람 전용 (봇 금지)
#general, #random, ...
```

### 통신 프로토콜

1. **CEO → 리더**: DM 또는 리더 홈 채널. 하위 서브워커 직접 명령 금지 (계층 존중)
2. **리더 → CEO**: DM 보고, 중요 결정은 홈 채널에 post 후 `:eyes:` 로 검토 요청
3. **리더 간**: `#leaders-lounge` 스레드에서만
4. **CTO → 서브워커**: `delegates.yaml` 규칙대로, DM 또는 `#eng-*` 채널
5. **서브워커 간**: `#eng-*` 채널 스레드에서만
6. **시스템 이벤트**: 전부 `#agent-ops` 로 자동 스트림
7. **패닉**: 사람이 `#agent-admin` 에서 `/agent stop-all`

### Slack App 설계 원칙

- **봇당 Slack App 하나** (공유 금지). 총 12 개: 비서 1 + 리더 6 + 서브워커 5
- 각 앱은 **App Manifest 로 선언적 생성** → cockpit 이 AGENT.md 에서 자동 생성
- **최소 OAuth scopes**: `chat:write`, `channels:read`, `im:write`, `reactions:read`, `commands`, `app_mentions:read` + 역할별 추가
- **Socket Mode 활성화**: public HTTPS 불필요, Fly.io 뒤에서도 OK
- **이벤트 구독**: `app_mention`, `message.im`, `reaction_added` 공통 + 역할별 추가

### 자동 프로비저닝 트릭

Slack 은 App 생성을 완전 자동화하지 않는다. 하지만 **Bootstrapper App** 트릭으로 수동 클릭을 1 회로 줄일 수 있다:

1. cockpit 에 **Bootstrapper Slack App** 을 포함. manifest 에 `channels:manage`, `admin.apps:write`, `users.profile:write` scope
2. CEO 가 첫 설치 때 **이 하나만** 수동 설치 (클릭 1 회)
3. 이후 12 개 봇 앱은 Bootstrapper 의 admin token 으로 `apps.manifest.create` API 호출 → 완전 자동 생성
4. 채널 생성·봇 초대·1Password 저장도 전부 Bootstrapper 가 수행

**총 수동 시간: 첫 설치 2~3 분, 이후 0.**

## 런타임 모델

### 두 층 구조

```
┌─────────────────────────────────────────────────┐
│ 상시 대기 — Slack listener (가벼운 컨테이너)      │
│                                                  │
│   • Socket Mode 로 Slack 에 상시 연결              │
│   • 멘션 수신 → 작업 큐에 enqueue                  │
│   • 가벼운 작업은 바로 응답                         │
│   • 무거운 작업은 worker runner 에 dispatch        │
│                                                  │
│   배포: Fly.io 무료 티어 (Phase 1)                │
│         Cloud Run min-instance=1 (Phase 2+)      │
└─────────────────────────────────────────────────┘
                   │
                   ↓ dispatch (무거운 작업)
                   │
┌─────────────────────────────────────────────────┐
│ 이벤트 잡 — Worker runner                         │
│                                                  │
│   • 이벤트마다 새로 기동, 완료 후 종료              │
│   • product-repo 를 신선 체크아웃                    │
│   • Claude Agent SDK 로 실제 작업                 │
│   • PR 생성, Slack 스레드에 결과 post             │
│                                                  │
│   배포: GitHub Actions (기본, 무료)                │
│         Cloud Run jobs (Phase 2+)                │
└─────────────────────────────────────────────────┘
```

### 왜 두 층인가

- **Slack Socket Mode 는 지속 연결이 필요** → 상시 대기 프로세스 필수
- **실제 작업은 무겁고 간헐적** → 이벤트 기반 잡이 경제적
- 두 층을 분리하면:
  - 상시 대기 비용 최소화 (Fly.io 무료)
  - 무거운 작업은 GHA 무료 한도 활용
  - 서로 영향 없이 독립 스케일링
  - 실패 격리 (잡이 터져도 listener 는 생존)

### 로컬 개발

`scripts/worker-run.sh <name>` — Docker 없이 직접 Python 프로세스로 기동. AGENT.md 읽고 Socket Mode 연결. 멘션 받으면 로컬에서 Claude 호출. 디버거 붙이기 쉬움.

## 실제 동작 시나리오

### `@CTO /review` → 수정 → 머지

```
#engineering, 09:42
────────────────────────────────────────────────
CEO:  @CTO /review PR #234 진행해

CTO:  [09:42] 확인. PR #234 리뷰 시작 · 약 2~3분 소요.
       (내부: backend-dev 에게 조사 위임)

      [09:44] 리뷰 완료:

             🔴 High (2건)
             1. services/auth/jwt.go:45 — exp claim 검증 누락
             2. platform/gateway/middleware.go:87 — SQL injection 우려

             🟡 Medium (1건)
             3. services/user/handler.go:120 — N+1 쿼리

             🟢 Low (1건)
             4. e2e/auth_test.go — expired token 실패 케이스 부재

             수정 원하시면 「수정해」 또는 「1, 3」 처럼 지정해주세요.

CEO:  1, 2, 4 만 수정해. 3번은 내가 직접 볼게.

CTO:  [09:45] 확인. backend-dev (1,2) · qa-dev (4) 에게 위임.

      [09:47] ✅ 1. jwt.go — exp 검증 추가 (commit: a3f21c8)
      [09:48] ✅ 2. middleware.go — prepared statement (commit: b8d4e01)
      [09:51] ✅ 4. auth_test.go — 케이스 3건 추가 (commit: c9f51a2)

      [09:51] 🎯 완료. PR #234 업데이트됨. CI 실행 중.
              머지는 ✅ 리액션으로 승인해주세요.

CEO:  ✅

CTO:  [09:52] 승인 감사합니다. CI 통과 후 머지는 사람이 직접 해주세요.
       (AGENT.md 에서 can_merge_pr: false)
```

**구현 요소**:

- **스레드 컨텍스트**: 봇이 매 턴마다 스레드 히스토리를 Claude 에 주입 → "수정해" 한 단어로도 앞 리뷰 결과 인지
- **명령 + 자연어 하이브리드**: `/review PR #234` 는 구조화, "수정해" 는 LLM 의도 추론
- **리더 → 서브워커 위임**: CTO(Opus) 가 Task 툴로 backend-dev(Sonnet) 호출 → 비용 절감
- **서브워커 코드 수정 파이프라인**:
  1. product-repo 체크아웃 (GHA runner 또는 캐시된 workspace)
  2. PR 브랜치로 switch
  3. Claude Edit tool 로 파일 수정
  4. 로컬 테스트 실행
  5. commit (Co-Authored-By: backend-dev bot)
  6. push 원격 브랜치
  7. 결과 리더에게 리턴
- **HITL 게이트**: `can_merge_pr: false` 로 봇 머지 금지. 리액션 승인은 "리뷰 요청 수락" 의미지 실제 머지는 사람이 클릭

### 지연 시간

| 단계 | 시간 |
|---|---|
| `/review` 첫 응답 | 2~5 초 (ack) |
| 리뷰 완료 | 1~3 분 (PR 크기에 비례) |
| "수정해" 첫 커밋 | 30~90 초 |
| 3 항목 수정 완료 | 3~7 분 |

즉시는 아니지만 "열심히 일하는 원격 직원" 느낌. 배치 잡 아님.

## 안전 장치 요약

### 코드 변경

- 항상 브랜치 위에서만 작업, main 직접 커밋 금지
- force-push 금지
- 10 개 이상 파일 수정 시 사전 승인
- 파괴적 동작 (`rm -rf`, `drop table`, `terraform destroy`) 는 deny 기본
- "되돌려" 명령 지원 — 이 스레드에서 만든 모든 커밋 revert PR

### 예산

- worker 별 일일·월별 USD 캡
- 초과 시 자동 정지 + `#agent-admin` 알림
- `/budget` 으로 누적 확인

### 감사

- JSONL audit log: `~/.cockpit-agents/<name>/audit.log`
- Slack 히스토리 = 자동 대화 감사
- 주 1 회 샘플 리뷰 (사람)

### 루프 방어

- 봇 자기 스레드 시작 금지 (cron 제외)
- 스레드당 봇 발화 최대 10 턴
- 체인 깊이 3 초과 거부
- 다른 봇 메시지 기본 무시
- 분당 rate limit
