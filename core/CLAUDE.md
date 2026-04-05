# 사용자 전역 설정 (claude-cockpit)

> 이 파일은 `claude-cockpit/core/CLAUDE.md` 에 원본이 있고, `~/.claude/CLAUDE.md` 로 심볼릭 링크됩니다.
> 수정은 cockpit 레포에서만 하세요.

## 공통 개발 표준 자동 로드

모든 코드 작성·리뷰·문서화 작업은 아래 표준을 **반드시** 따릅니다.

@standards/CLAUDE.md

## 응답 규칙

- **응답 언어**: 모든 응답은 **한글** (코드 변수명/함수명은 영어)
- **존댓말 사용**: 모든 응답은 존댓말로 작성합니다.

## 에이전트 관리 규칙

- **백그라운드 에이전트 진행 상황**: 에이전트를 백그라운드로 실행할 때, output 파일을 1분 간격으로 확인하여 사용자에게 현재 진행 상황(작성 중인 파일, 빌드 결과, 남은 작업)을 보고합니다.
- **장시간 에이전트 감지**: 에이전트가 5분 이상 걸리면 자동으로 진행 상황을 확인하고 보고합니다. 10분 이상이면 중단 여부를 사용자에게 확인합니다.

## 로컬 환경 표준

- **Docker 런타임은 Colima** 를 사용합니다. Docker Desktop 은 사용하지 않습니다. 상세: @docs/dev/local-environment.md

## 코드 작성 규칙

- **파일 먼저, 빌드 나중**: 여러 파일을 작성할 때 모든 파일을 먼저 작성하고, 마지막에 한 번만 빌드/컴파일합니다.
- **빌드 실패 시**: 에러를 모두 확인한 뒤 한 번에 수정하고 재빌드합니다 (한 개씩 수정 → 재빌드 반복 금지).
- **기존 패턴 먼저 확인**: 코드 작성 전에 같은 디렉토리의 기존 파일 1-2개를 읽고 import, 생성자, 패턴을 파악한 뒤 작성합니다.

## Slash Command 네임스페이스

cockpit 스킬은 **4도메인**(개발 / 기획 / 프로덕트 / 경영) 기준으로 네임스페이스가 나뉩니다. 단, Claude Code slash 는 1단계 네임스페이스만 지원하므로 디렉토리는 플랫 구조로 유지합니다.

### 🛠 개발 (Engineering)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/review/*` | `/review:all`, `/review:architecture`, `/review:code`, `/review:test`, `/review:security`, `/review:performance`, `/review:deps` |
| `skills/dev/*`    | `/dev:hotspot`, `/dev:reproduce` |
| `skills/ci/*`     | `/ci:pr-enhance`, `/ci:release-notes`, `/ci:flaky` |
| `skills/design/*` | `/design:api` (API 설계, 엔지니어링 영역) |
| `skills/docs/*`   | `/docs:claude-docs-review`, `/docs:migrate-standards` |
| `skills/wiki/*`   | `/wiki:capture` |

### 📐 기획 (Planning)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/plan/*` | `/plan:prd-draft` (추가 예정: `spec-review`, `user-story`) |

### 🎯 프로덕트 (Product)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/prod/*` | `/prod:metrics-define` (추가 예정: `discovery`, `competitor-scan`) |

### 🏢 경영 (Management)

| 카테고리 | 호출 예시 |
|---------|----------|
| `skills/mgmt/*` | `/mgmt:standup`, `/mgmt:ceo-briefing` (추가 예정: `weekly-metrics`) |

> **참고**: `skills/jira/` 는 `skills/mgmt/` 로 리네임됐습니다. 기존 `/jira:*` 명령어는 더 이상 동작하지 않습니다.
