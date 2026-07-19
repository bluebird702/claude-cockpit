# 사용자 전역 설정 (claude-cockpit)

> 이 파일은 `claude-cockpit/system/CLAUDE.md` 에 원본이 있고, `~/.claude/CLAUDE.md` 로 심볼릭 링크됩니다.
> 수정은 cockpit 레포에서만 하세요.

## 공통 개발 표준 자동 로드

모든 코드 작성·리뷰·문서화 작업은 아래 표준을 **반드시** 따릅니다.

@brain/CLAUDE.md

## 철학 vs 개인 선호 (포크 가이드)

- **철학·표준** (가져다 쓰거나, `brain/philosophy.md` 하나만 교체): `brain/**` — 규칙 충돌 시 philosophy.md 가 최종 심판.
- **개인 선호** (자유롭게 수정): 이 파일의 응답 언어·존댓말, Colima 같은 로컬 환경 항목.

## 응답 규칙 (Response Rules)

- **응답 언어 (Language)**: 사용자가 질문한 언어로 대답합니다. 명시되지 않은 경우 **영어(English)**를 기본값으로 사용합니다. (한국어 사용자는 한국어로 질문하면 됩니다.)
- **존댓말 사용**: 한국어로 응답할 때는 존댓말로 작성합니다.

## 에이전트 관리 규칙

- AI 에이전트 위임·검증·백그라운드 운영 기준은 **@brain/ai/agent-workflow.md** (자동 로드됨) 를 따릅니다 — 위임/직접 경계, 검증 게이트, 1분 간격 진행 확인 · 5분 자동 보고 · 10분 중단 확인 포함.

## 로컬 환경 표준

- **Docker 런타임은 Colima** 를 사용합니다. Docker Desktop 은 사용하지 않습니다. 상세: cockpit 레포 `docs/dev/local-environment.md`

## 코드 작성 규칙

- **파일 먼저, 빌드 나중**: 여러 파일을 작성할 때 모든 파일을 먼저 작성하고, 마지막에 한 번만 빌드/컴파일합니다.
- **빌드 실패 시**: 에러를 모두 확인한 뒤 한 번에 수정하고 재빌드합니다 (한 개씩 수정 → 재빌드 반복 금지).
- **기존 패턴 먼저 확인**: 코드 작성 전에 같은 디렉토리의 기존 파일 1-2개를 읽고 import, 생성자, 패턴을 파악한 뒤 작성합니다.

## 커밋 규칙

- **커밋 메시지는 커밋 표준(자동 로드됨)을 그대로 적용합니다**: `git commit` 을 실행하는 모든 경우(서브에이전트 포함), `brain/writing/commit-message.md` 의 형식을 따릅니다 — `<type>(<scope>): <subject>`(70자·명령형), "왜" 중심 본문(heredoc 작성), footer 에 `Co-Authored-By: <모델명> <noreply@anthropic.com>`. git `commit.template` 설정 여부와 무관하게 이 표준이 곧 템플릿입니다.

## 판단·평가 규칙

- **평가 전에 대상 내부를 읽는다**: 시스템·코드의 강점/약점/**부재**를 단언하기 전에 그 내부(구현·설정·테스트)를 직접 읽습니다. README·디렉토리 구조·이름만 보고 "없다/못한다"를 단정하지 않습니다. 안 읽고 말해야 하면 **"가설"로 명시**합니다. (근거 없는 부재 단언은 표준 위반)

## Slash Command 네임스페이스

cockpit 스킬은 역할을 기준으로 네임스페이스가 나뉩니다. 현재 엄선된 16개의 코어 스킬만 제공합니다.

### 🛠 개발 및 리뷰 (Engineering & Review)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/review/*` | `/review:all`, `/review:architecture`, `/review:code`, `/review:test`, `/review:security`, `/review:performance`, `/review:resilience`, `/review:deps`, `/review:promote`, `/review:cockpit` |
| `skills/dev/*`    | `/dev:refactor`, `/dev:reproduce` |

### 📐 기획 및 설계 (Planning & Design)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/plan/*` | `/plan:ideation`, `/plan:prd-draft` |
| `skills/design/*` | `/design:system-design` |

### 🎯 운영 및 사후분석 (Operations)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/prod/*` | `/prod:rca` |
