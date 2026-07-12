# claude-cockpit (프로젝트 전용 지침)

> 이 파일은 **cockpit 레포 자체를 편집할 때** Claude 가 따라야 할 지침입니다.
> 전역 지침(`core/CLAUDE.md`)은 `~/.claude/CLAUDE.md` 로 심링크되어 별도로 자동 로드됩니다 — 여기서 중복하지 않습니다.

## 이 레포의 정체성

claude-cockpit 은 **단일 출처(SSOT)** 입니다. `~/.claude/` 하위의 모든 파일(`CLAUDE.md`, `settings.json`, `keybindings.json`, `commands/`, `agents/`)은 이 레포의 심볼릭 링크입니다. 따라서:

- **수정은 반드시 cockpit 레포에서만** 합니다. `~/.claude/*` 를 직접 편집하지 않습니다.
- 장비별/개인 오버라이드가 필요하면 `~/.claude/settings.local.json` (레포 밖) 을 사용합니다.
- **정체성**: "어디서든 노트북에 다운받으면 그 머신이 좋은 퀄리티의 Claude Code 환경이 되는 dotfiles + 표준 + 슬래시 커맨드 + 훅 + MCP". Slack 상주 AI 워커 런타임 같은 프로젝트별 자산은 *cockpit 을 submodule 로 가져다 쓰는 별도 레포* (예: 비공개 abillity-ai) 에서 운영합니다.

## 레이어 구조

```
claude-cockpit/
├── core/                전사 baseline — 모든 사람·에이전트가 상속
│   ├── CLAUDE.md         전역 지침 (→ ~/.claude/CLAUDE.md 로 링크)
│   ├── settings.json     권한·훅 baseline
│   ├── keybindings.json
│   ├── git/              커밋 메시지 템플릿 (→ ~/.gitmessage 링크 + commit.template)
│   ├── standards/        coding / testing / api / writing / planning / product / management
│   ├── hooks/            guard-bash, guard-secrets, format, session-context, session-end
│   ├── mcp-shared/       공통 MCP (GitHub / Jira / Confluence / Playwright) + setup.sh
│   └── memory-seed/      초기 메모리 시드 (user_profile, feedback_style, reference_cockpit)
│
├── humans/              사람(CEO) 용 대화형 도구
│   ├── skills/           슬래시 커맨드 — review/ design/ dev/ ci/ docs/ wiki/ plan/ prod/ mgmt/
│   ├── subagents/        Task 툴 서브에이전트 (ceo-briefing, flaky-test-hunter, ...)
│   └── review-fixtures/  리뷰어 골든셋 (QA 데이터 — 스킬로 노출되면 안 됨)
│
├── docs/                레포 문서
│   ├── dev/              project-structure, local-environment (Colima), ...
│   ├── process/          review-exclusions, doc-sync
│   ├── examples/         실제 프로젝트 CLAUDE.md 샘플
│   └── writing/          commit / PR / ADR / 한글 톤 가이드
│
├── scripts/             설치·링크·진단
│   ├── global-install.sh    ~/.claude 에 링크 (install.sh 가 래퍼)
│   ├── global-uninstall.sh
│   ├── check-deps.sh        환경 진단 (구 phase-doctor)
│   ├── claude-plugins.sh    플러그인 설치 (구 phase-plugins)
│   ├── post-install-check.sh
│   ├── project-link.sh / project-unlink.sh   소비 프로젝트용
│   └── lib/                 common · tui · jq_merge · secrets
│
├── secrets/             1Password 스키마만 (실제 값 X)
└── install.sh           원클릭 래퍼 → scripts/global-install.sh --with-mcp
```

## 작업 시 규칙

### 편집 대상 식별

- **슬래시 커맨드 고치기** → `humans/skills/<namespace>/<name>.md`. 네임스페이스는 전역 지침의 4도메인 표 참조.
- **서브에이전트 고치기** → `humans/subagents/*.md`.
- **전역 권한·훅 조정** → `core/settings.json.template`(설치 시 렌더→`~/.claude/settings.json`) + `core/hooks/*.sh`. 훅 추가/변경 시 `bash -n` 구문 검사와 실행 권한 확인 필수.
- **공통 표준 변경** → `core/standards/**`. 여기가 원본이고 다른 문서에서 `@standards/...` 로 참조합니다. 복사본 만들지 말 것.
- **워커 런타임·페르소나·회사 지식**: cockpit 에 들어가지 않습니다. cockpit 을 submodule 로 가져다 쓰는 *비공개 회사 레포* 에서 관리합니다.

### 하지 말 것

- `~/.claude/` 심링크 대상 직접 편집 (변경사항이 추적되지 않음).
- `core/standards/` 내용을 다른 파일에 복사. 반드시 `@standards/...` 로 참조.
- 평문 시크릿 커밋. `core/hooks/guard-secrets.sh` 가 PreToolUse 로 차단하지만, 그 전에 본인이 먼저 체크.
- `skills/` 의 네임스페이스 규칙(4도메인: 개발 / 기획 / 프로덕트 / 경영) 위반. 새 스킬을 어디 둘지 애매하면 먼저 질문.
- 과거 네이밍 복원: `skills/jira/` (→ `mgmt/`), `phase-doctor` (→ `check-deps`), `phase-plugins` (→ `claude-plugins`) 는 모두 리네이밍됐습니다.

### 쉘 스크립트 작성

- 모든 스크립트는 `set -euo pipefail` 시작.
- `scripts/lib/common.sh`, `scripts/lib/tui.sh` 의 공통 함수 재사용. 새 로깅/TUI 유틸리티 중복 작성 금지.
- macOS(Darwin) / Linux 둘 다 동작해야 함 — `sed -i` 같은 BSD/GNU 차이 주의.

## 검증

- 설치·링크 상태: `./scripts/post-install-check.sh`
- 이 레포 자체 메타 리뷰: `/review:cockpit`
- 표준 준수: `/review:all` (프로젝트 대상일 때만 — cockpit 자체엔 `/review:cockpit` 가 맞음)

## 참고 문서

- 표준 인덱스: `core/standards/CLAUDE.md`
- 설치·링크 상태: `scripts/post-install-check.sh`
