# claude-cockpit

개인용 Claude Code 설정·스킬·문서·표준을 한 곳에서 관리하는 레포입니다. 모든 설정은 `~/.claude` 와 프로젝트에 **심볼릭 링크**로 연결되어, cockpit 에서 수정한 내용이 즉시 반영됩니다.

## 구성

```
claude-cockpit/
├── global/            # ~/.claude/* 로 링크 (CLAUDE.md, settings.json, keybindings.json)
├── mcp/               # MCP 서버 설정 (GitHub · Jira · Confluence · Playwright)
├── skills/            # /dev:review, /ci:pr-enhance 형태의 슬래시 커맨드
│   ├── dev/ docs/ ci/ jira/ wiki/
├── standards/         # 공통 개발 표준 (coding / testing / api / templates)
├── docs/
│   ├── dev/           # project-structure, new-service-checklist, local-environment (Colima)
│   ├── process/       # review-exclusions, doc-sync
│   ├── examples/      # 실제 CLAUDE.md 샘플
│   └── writing/       # commit / PR / doc-style / 한글 톤 / ADR 가이드
├── scripts/           # 설치·링크·공통 라이브러리
│   └── lib/           # common / tui / jq_merge / secrets
└── cockpit-review.md  # 이 레포 자체를 검증하는 슬래시 커맨드
```

## 빠른 시작

### 1. 클론

```bash
git clone git@github.com:bluebird702/claude-cockpit.git ~/Work/claude-cockpit
cd ~/Work/claude-cockpit
```

### 2. 전역 설치 (`~/.claude` 에 링크)

```bash
./scripts/global-install.sh
# 또는 MCP 설정까지 이어서:
./scripts/global-install.sh --with-mcp
```

설치 후 Claude Code 에서 즉시 호출 가능:

```
/dev:review           # 프로젝트 종합 리뷰
/dev:analyze-tests    # 테스트 품질 분석
/dev:design-api       # API 설계 제안
/ci:pr-enhance        # PR 설명 초안 + 점검
/ci:security-scan     # OWASP Top 10 스캔
/ci:deps-audit        # 의존성 감사
/docs:claude-docs-review
/docs:migrate-standards
```

### 3. MCP 설치 (선택, TUI 대화형)

```bash
./mcp/setup.sh
```

- **Phase 1 · 사전 점검** — node, npx, jq, settings.json
- **Phase 2 · 입력 수집** — 선택한 서버의 모든 값을 **먼저** 한 번에 입력받음
- **Phase 3 · 일괄 적용** — 백업 → Keychain 저장 → settings.json 머지 → 로더 생성

비밀값(GitHub 토큰, Jira API 토큰 등)은 **macOS Keychain** (Linux 는 libsecret) 에 저장됩니다. 평문으로 남지 않습니다.

```bash
./mcp/clean.sh --purge-env    # Keychain 항목까지 모두 제거
```

### 4. 소비 프로젝트에 연결 (선택적 노출)

cockpit 을 submodule 로 추가한 뒤, 필요한 영역만 링크합니다.

```bash
cd my-project
git submodule add git@github.com:bluebird702/claude-cockpit.git .cockpit
.cockpit/scripts/project-link.sh \
  --with standards \
  --with skills/dev \
  --with skills/ci \
  --with docs/process \
  --with docs/writing
```

결과:

```
my-project/
├── .cockpit/                            # submodule (cockpit 전체)
├── .claude/commands/
│   ├── dev  → ../../.cockpit/skills/dev
│   └── ci   → ../../.cockpit/skills/ci
├── docs/
│   ├── standards → ../.cockpit/standards
│   ├── process   → ../.cockpit/docs/process
│   └── writing   → ../.cockpit/docs/writing
```

### 5. 업데이트

```bash
cd ~/Work/claude-cockpit
git pull

# 소비 프로젝트
cd my-project
git submodule update --remote .cockpit
.cockpit/scripts/project-link.sh --reapply --with standards --with skills/dev ...
```

## Standards 강제 준수

모든 `skills/**/*.md` 는 다음 3중 장치로 standards 준수를 강제합니다:

1. **Frontmatter** — `follows-standards: [standards/CLAUDE.md, ...]`, `enforcement: required`
2. **본문 상단 블록** — ⚠️ "Standards 준수 필수" + `@standards/*` 참조
3. **Global CLAUDE.md** — `@standards/CLAUDE.md` 전역 자동 로드

`cockpit-review.md` (또는 `/cockpit:review`) 가 이 규칙 준수를 자동 검증합니다.

## 자가 검증

```bash
make review      # cockpit-review.md 체크리스트 실행
```

## 사용자 전역 정책 (요약)

- **응답**: 한글, 존댓말 (코드 식별자는 영어)
- **Docker 런타임**: Colima 사용 (Docker Desktop 금지) → `@docs/dev/local-environment.md`
- **비밀값**: macOS Keychain / libsecret 저장, 레포에 평문 금지
- **표준**: `standards/` 가 모든 규칙의 원본, skills 와 projects 는 자동 로드

## 라이선스

개인 설정 레포. 내부용.
