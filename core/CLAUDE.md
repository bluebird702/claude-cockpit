# 사용자 전역 설정 (claude-cockpit)

> 이 파일은 `claude-cockpit/core/CLAUDE.md` 에 원본이 있고, `~/.claude/CLAUDE.md` 로 심볼릭 링크됩니다.
> 수정은 cockpit 레포에서만 하세요.

## 공통 개발 표준 자동 로드

모든 코드 작성·리뷰·문서화 작업은 아래 표준을 **반드시** 따릅니다.

@standards/CLAUDE.md

## 철학 vs 개인 선호 (포크 가이드)

- **철학·표준** (가져다 쓰거나, `standards/philosophy.md` 하나만 교체): `core/standards/**` — 규칙 충돌 시 philosophy.md 가 최종 심판.
- **개인 선호** (자유롭게 수정): 이 파일의 응답 언어·존댓말, Colima 같은 로컬 환경 항목.

## 응답 규칙

- **응답 언어**: 모든 응답은 **한글** (코드 변수명/함수명은 영어)
- **존댓말 사용**: 모든 응답은 존댓말로 작성합니다.

## 에이전트 관리 규칙

- AI 에이전트 위임·검증·백그라운드 운영 기준은 **@standards/ai/agent-workflow.md** (자동 로드됨) 를 따릅니다 — 위임/직접 경계, 검증 게이트, 1분 간격 진행 확인 · 5분 자동 보고 · 10분 중단 확인 포함.

## 로컬 환경 표준

- **Docker 런타임은 Colima** 를 사용합니다. Docker Desktop 은 사용하지 않습니다. 상세: cockpit 레포 `docs/dev/local-environment.md`

## 코드 작성 규칙

- **파일 먼저, 빌드 나중**: 여러 파일을 작성할 때 모든 파일을 먼저 작성하고, 마지막에 한 번만 빌드/컴파일합니다.
- **빌드 실패 시**: 에러를 모두 확인한 뒤 한 번에 수정하고 재빌드합니다 (한 개씩 수정 → 재빌드 반복 금지).
- **기존 패턴 먼저 확인**: 코드 작성 전에 같은 디렉토리의 기존 파일 1-2개를 읽고 import, 생성자, 패턴을 파악한 뒤 작성합니다.

## 커밋 규칙

- **커밋 메시지는 커밋 표준(자동 로드됨)을 그대로 적용합니다**: `git commit` 을 실행하는 모든 경우(서브에이전트 포함), `core/standards/writing/commit-message.md` 의 형식을 따릅니다 — `<type>(<scope>): <subject>`(70자·명령형), "왜" 중심 본문(heredoc 작성), footer 에 `Co-Authored-By: <모델명> <noreply@anthropic.com>`. git `commit.template` 설정 여부와 무관하게 이 표준이 곧 템플릿입니다.

## 판단·평가 규칙

- **평가 전에 대상 내부를 읽는다**: 시스템·코드의 강점/약점/**부재**를 단언하기 전에 그 내부(구현·설정·테스트)를 직접 읽습니다. README·디렉토리 구조·이름만 보고 "없다/못한다"를 단정하지 않습니다. 안 읽고 말해야 하면 **"가설"로 명시**합니다. (근거 없는 부재 단언은 표준 위반)

## Slash Command 네임스페이스

cockpit 스킬은 **4도메인**(개발 / 기획 / 프로덕트 / 경영) 기준으로 네임스페이스가 나뉩니다. 단, Claude Code slash 는 1단계 네임스페이스만 지원하므로 디렉토리는 플랫 구조로 유지합니다.
(표준은 여기에 **AI** 를 더한 5도메인 — `standards/ai/` 는 아직 전용 슬래시 커맨드 없이 표준만 존재합니다.)

### 🛠 개발 (Engineering)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/review/*` | `/review:all`, `/review:architecture`, `/review:code`, `/review:test`, `/review:security`, `/review:performance`, `/review:deps`, `/review:promote` |
| `skills/dev/*`    | `/dev:hotspot`, `/dev:reproduce` |
| `skills/ci/*`     | `/ci:pr-enhance`, `/ci:release-notes`, `/ci:flaky` |
| `skills/design/*` | `/design:api` (API 설계, 엔지니어링 영역) |
| `skills/docs/*`   | `/docs:claude-docs-review`, `/docs:migrate-standards` |
| `skills/wiki/*`   | `/wiki:capture` |

### 📐 기획 (Planning)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/plan/*` | `/plan:prd-draft` |

### 🎯 프로덕트 (Product)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/prod/*` | `/prod:metrics-define`, `/prod:metrics-verdict` |

### 🏢 경영 (Management)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/mgmt/*` | `/mgmt:standup`, `/mgmt:ceo-briefing`, `/mgmt:ai-spend`, `/mgmt:security-monthly`, `/mgmt:adr-review` |

> **참고**: `skills/jira/` 는 `skills/mgmt/` 로 리네임됐습니다. 기존 `/jira:*` 명령어는 더 이상 동작하지 않습니다.
