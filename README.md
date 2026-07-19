# claude-cockpit

> **기획(Plan) ➡️ 설계(Design) ➡️ 코딩(Dev) ➡️ 리뷰(Review) ➡️ 문서화(Docs) ➡️ 운영(Prod)까지, IT 프로덕트 탄생의 전 주기를 AI와 함께 돌파하는 궁극의 'Full-Cycle AI 노하우 바이블'이자 오픈소스 플레이북.**

어디서든 노트북에 다운받으면 그 머신이 단순한 코딩 에이전트를 넘어, **"초지능 프로덕트 메이커"**로 거듭나는 범용 설정 + 표준 + 슬래시 커맨드 + 훅 묶음입니다.
이 레포지토리는 특정 실행 플랫폼에 종속되지 않는 순수 오픈소스 지식 저장소(Platform-Agnostic)로, 전 세계 누구나 기여하고 상속받을 수 있는 **단일 출처(SSOT)**입니다.

> **📌 공개 레포 안내 (Open Source Notice)**
>
> - **타겟 독자**: 1인 창업자 ~ 소규모 팀. 대기업 조직에는 그대로 맞지 않을 수 있습니다 — 승인 프로세스·리뷰 게이트는 직접 확장하세요.
> - **다국어 지원 (I18n)**: 모든 문서와 프롬프트는 한국어로 작성되어 있으나, AI는 **사용자가 질문하는 언어(기본값: 영어)**로 자동 번역하여 스마트하게 응답합니다. `core/CLAUDE.md`에서 글로벌 기본값을 변경할 수 있습니다.
> - **로컬 환경 전제**: macOS + Colima 를 권장 기본값으로 합니다. Linux·Docker Desktop·Podman 에서도 동작 가능하지만 일부 스크립트 경로는 검증되지 않았습니다.
> - **개인 설정 치환**: 설치 시 `scripts/global-install.sh` 가 `$HOME`, GitHub 사용자명, 레포 경로 등을 감지해 `~/.claude/*` 에 반영합니다. 레포에는 템플릿 형태로만 존재합니다.
> - **철학 교체 슬롯**: `core/standards/philosophy.md` 가 모든 표준의 최종 심판 기준입니다. 포크 시 이 파일 하나만 자신의 철학으로 교체하면 나머지 표준·스킬·훅 체계를 그대로 상속합니다.

## 레이어

```
claude-cockpit/
├── core/                  전사 baseline — 모든 사람·에이전트 공통
│   ├── CLAUDE.md           전역 지침 (→ ~/.claude/CLAUDE.md)
│   ├── settings.json       권한·훅 baseline
│   ├── keybindings.json
│   ├── standards/          philosophy / coding / engineering(reliability) / testing / api / writing / ai / planning / product / management
│   ├── hooks/              guard-bash, guard-secrets, guard-prompt-injection, format, session-context, session-end
│   ├── mcp-shared/         공통 MCP 설정 (GitHub / Jira / Confluence / Playwright / Slack / Figma / Context7)
│   └── memory-seed/        초기 메모리 시드
│
├── humans/                사람(CEO) 용 대화형 도구
│   ├── skills/             슬래시 커맨드 (4도메인: 개발 / 기획 / 프로덕트 / 경영)
│   ├── subagents/          Task 툴 서브에이전트 (리뷰 전담 review-* 8종 + 운영 5종)
│   └── review-fixtures/    리뷰어·검증자 골든셋 (QA 데이터 — 슬래시 커맨드 아님)
│
├── docs/                  레포 문서 (dev / process / examples / writing)
├── scripts/               설치·링크·진단 (lib/ 공통 라이브러리 포함)
├── secrets/               1Password 스키마만 (실제 값 없음)
├── install.sh             원클릭 래퍼
└── CLAUDE.md              cockpit 레포 작업 시 Claude 가 따르는 프로젝트 지침
```

## 빠른 시작

### 옵션 A. 새 장비 — 1줄 부트스트랩 (권장)

```bash
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash
```

인자 전달이 필요하면 `bash -s --` 패턴:

```bash
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --no-mcp --no-plugins
```

환경변수로 위치·브랜치 조정:

```bash
COCKPIT_HOME=$HOME/.cockpit COCKPIT_REF=v1.0 \
  curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash
```

**재실행 / 제거**도 같은 1줄 패턴을 따릅니다:

```bash
# 재실행: 멱등 (clone → fetch/pull → install.sh, link_idempotent 로 기존 링크 보존)
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash

# 제거: ~/.claude 의 cockpit 링크만 해제 (cockpit 레포·유저 메모리는 보존)
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --clean

# MCP·메모리까지 함께 제거
curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --clean --all
```

**이미 설치된 머신의 최신화**는 전체 재설치 대신 업데이트 스크립트를 사용하세요 (doctor·대화형 MCP 없이 pull → 재렌더 → 링크·시드 동기화, settings.json 실파일 드리프트도 자동 머지 복구):

```bash
cd <cockpit 경로>
./scripts/update.sh              # git pull + 동기화
./scripts/update.sh --no-pull    # pull 은 직접 했을 때
./scripts/update.sh --reseed     # 메모리 시드를 백업 후 렌더본으로 교체 (이름 오검출 교정 등)
```

> 📌 부트스트랩은 git HTTPS 로 클론 후 `install.sh` (또는 `--clean` 시 `uninstall.sh`) 를 위임 실행합니다. cockpit 레포 자체는 자동 삭제되지 않습니다 — 완전 초기화는 `rm -rf $COCKPIT_HOME` 으로 명시적으로. 스크립트는 80 줄 미만이라 [`scripts/bootstrap.sh`](./scripts/bootstrap.sh) 직접 검토를 권장합니다.

### 옵션 B. 수동 (이미 클론한 경우)

```bash
git clone git@github.com:bluebird702/claude-cockpit.git ~/Work/claude-cockpit
cd ~/Work/claude-cockpit
./install.sh                    # 전역 링크 + MCP + 플러그인 설치
./install.sh --force            # 기존 실제 파일도 백업 후 덮어씀
./install.sh --no-mcp           # MCP 단계 건너뜀
./install.sh --no-plugins       # 플러그인 설치 건너뜀 (오프라인)
```

내부적으로 `scripts/global-install.sh --with-mcp` 가 실행되며 다음 Phase 를 거칩니다:

1. **doctor** — 필수·권장 도구 진단 (`scripts/check-deps.sh`)
2. **global link** — `core/CLAUDE.md`, `settings.json`, `keybindings.json` → `~/.claude/`
3. **skills link** — `humans/skills/<cat>` → `~/.claude/commands/<cat>`
4. **agents link** — `humans/subagents/` → `~/.claude/agents`
5. **hooks verify** — `core/hooks/*.sh` 실행 권한·구문 검사
6. **memory seed** — `core/memory-seed/*.md` → `~/.claude/memory/` (최초 1회만)
7. **MCP** — `core/mcp-shared/setup.sh` (대화형 TUI)
8. **plugins** — GitHub 플러그인 다운로드·설치 (claude-hud 등)
9. **post-install check** — 전체 검증 (`scripts/post-install-check.sh`)

### 설치 후: 슬래시 커맨드

설치 후 Claude Code 에서 즉시 호출할 수 있는 스킬은 **4도메인** 으로 나뉩니다:

**🛠 개발 및 검증 (Dev & Review)**
```
/review:all /review:architecture /review:code /review:test
/review:security /review:performance /review:resilience /review:deps
/review:cockpit /review:promote
/dev:hotspot /dev:reproduce /dev:refactor
/ci:pr-enhance /ci:release-notes /ci:flaky
/docs:api-spec /docs:claude-docs-review /docs:migrate-standards
/wiki:capture
```

**📐 기획 및 설계 (Plan & Design)**
```
/plan:ideation /plan:prd-draft
/design:system-design /design:api
```

**🎯 프로덕트 운영 (Product & Prod)**
```
/prod:metrics-define /prod:metrics-verdict /prod:rca
```

**🏢 경영 (Management)**
```
/mgmt:standup /mgmt:ceo-briefing /mgmt:ai-spend
/mgmt:security-monthly /mgmt:adr-review
```

> Claude Code slash 는 1단계 네임스페이스만 지원하므로 `humans/skills/` 하위는 플랫 구조로 유지합니다. 상세 규칙은 [`core/CLAUDE.md`](./core/CLAUDE.md) 의 "Slash Command 네임스페이스" 절 참조.

### MCP 설치 (대화형)

원클릭 설치를 건너뛰었거나 나중에 추가·재설정하려면:

```bash
./core/mcp-shared/setup.sh          # 3-Phase TUI: 사전 점검 → 입력 수집 → 일괄 적용
./core/mcp-shared/setup.sh --help
```

비밀값(GitHub PAT, Jira API 토큰 등)은 **macOS Keychain** (Linux 는 libsecret) 에 저장되며, 레포에는 평문으로 남지 않습니다. 토큰 회수는:

```bash
./core/mcp-shared/setup.sh --purge-env    # Keychain 항목까지 모두 제거
```

### 소비 프로젝트에 연결

cockpit 을 submodule 로 추가한 뒤 필요한 영역만 링크합니다.

```bash
cd my-project
git submodule add git@github.com:<YOUR_ORG>/claude-cockpit.git .cockpit
.cockpit/scripts/project-link.sh \
  --with core/standards \
  --with humans/skills/dev \
  --with humans/skills/ci \
  --with docs/process \
  --with docs/writing
```

업데이트:

```bash
cd my-project
git submodule update --remote .cockpit
.cockpit/scripts/project-link.sh --reapply ...
```

### 제거

```bash
./scripts/global-uninstall.sh     # ~/.claude 링크 해제 (cockpit 레포는 유지)
```

## 표준 강제 준수

모든 `humans/skills/**/*.md` 는 3중 장치로 `core/standards/` 준수를 강제합니다:

1. **Frontmatter** — `follows-standards: [...]`, `enforcement: required`
2. **본문 상단** — ⚠️ "Standards 준수 필수" 블록 + `@standards/*` 참조
3. **전역 CLAUDE.md** — `core/CLAUDE.md` 가 `@standards/CLAUDE.md` 자동 로드

이 레포 자체의 규약 준수는 `/review:cockpit` 으로 검증합니다.

리뷰어 자체의 품질(탐지 P/R·검증자 confirm/refute recall)은 `humans/review-fixtures/` 골든셋으로
측정하며, 리뷰 체계(스킬·`review-*` 에이전트·룰셋·픽스처)를 바꾸는 PR 은
`.github/workflows/goldenset-eval.yml` 이 LLM 골든셋 평가를 자동 실행해 머지 게이트로 잡습니다.

## 사용자 전역 정책 (요약)

- **응답**: 한글, 존댓말 (코드 식별자는 영어)
- **Docker 런타임**: Colima 사용 (Docker Desktop 금지) → `docs/dev/local-environment.md`
- **시크릿**: macOS Keychain / libsecret, 레포에 평문 금지 → `core/standards/management/security.md`
- **표준 원본**: `core/standards/` 가 모든 규칙의 원본. 스킬·프로젝트는 자동 로드만 하고 복사본을 만들지 않음.

상세 규칙은 [`core/CLAUDE.md`](./core/CLAUDE.md) 와 [`core/standards/CLAUDE.md`](./core/standards/CLAUDE.md) 참조.

## 라이선스

MIT License — [`LICENSE`](./LICENSE) 참조. 자유롭게 포크·수정·재배포하세요.
