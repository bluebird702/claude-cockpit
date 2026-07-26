---
name: review:cockpit
description: claude-cockpit 레포 자체의 구조·규약·문서 일관성을 검증하는 메타 리뷰
type: slash-command
category: review
follows-brain:
  - brain/CLAUDE.md
  - brain/management/security.md
enforcement: recommended
---

# claude-cockpit 자가 검증 (메타 리뷰)

<!-- enforcement 주석: 이 스킬은 수동 호출 검증 도구입니다. `recommended` 는 "실행 시
     brain 기준으로 판정" 을 의미하며, 다른 스킬의 `required` (작업 시 반드시 준수)
     와 의미가 다릅니다. -->


> ⚠️ **Brain 원칙 준수 필수** — 판단 기준은 brain 가 우선합니다.
> @brain/CLAUDE.md · @brain/management/security.md

> 이 스킬은 cockpit 레포 **자체의** 품질(구조·규약·문서 일관성)을 확인하는 체크리스트입니다.
> 프로젝트 코드 품질 리뷰는 `/review:all` 을 사용하세요. 경계:
> - **`/review:all`** — 임의 프로젝트의 아키/코드/테스트/보안/성능/의존성 6도메인 리뷰
> - **`/review:cockpit`** — claude-cockpit 레포 한정, 리팩토링 이후 구조·링크·규약 일관성 검증

## 실행 방법

```
/review:cockpit                 # 전 섹션 검사
/review:cockpit 5                # §5 만 재검사
/review:cockpit --section 3,5,6  # 여러 섹션 선택
```

Claude 가 이 문서를 읽고 지정된 섹션을 순서대로 검사한 뒤, 마지막에 **종합 점수 + 실패 항목 + 권장 조치** 를 보고합니다. 자동 검사 커맨드는 § "자동 검사" 블록을 그대로 실행합니다.

**인자 규약** ($ARGUMENTS)
- 인자 없음 → 전 11 섹션 검사
- `N` 또는 `N,M` → 해당 섹션 번호만 부분 재검사 (수정 후 회귀 검증용)
- `--section N[,M…]` → 위와 동일, 명시 플래그 형태

## 레포 상위 구조 (2026-05 기준)

```
claude-cockpit/
├── install.sh                       # 단일 진입점
├── system/                            # Claude Code 전역 설정 원본
│   ├── CLAUDE.md  settings.json.template  keybindings.json
│   ├── hooks/                       # format, guard-bash, guard-secrets, guard-prompt-injection, session-*
│   ├── brain/                   # 철학 + 5도메인 표준 (philosophy/coding/testing/api/writing/ai/planning/product/management) + templates/
│   ├── mcp-shared/                  # servers.json, setup.sh, clean.sh, .env.example
│   └── memory-seed/                 # 초기 메모리 시드 (user/feedback/reference)
├── skills/
│   ├── skills/                      # 9카테고리: ci/design/dev/docs/mgmt/plan/prod/review/wiki
│   ├── subagents/                   # 5종 에이전트
│   └── review-fixtures/             # 리뷰어 골든셋 (QA 데이터 — 스킬 수집 대상 아님)
├── scripts/                         # global-install, project-link, configure, post-install-check, lib/
└── docs/                            # dev/examples/process/writing
```

## 검증 절차

### §1. 디렉토리 구조 (10점)

- [ ] `system/` — `CLAUDE.md`, `settings.json.template`, `keybindings.json` 존재
- [ ] `system/hooks/` — `format.sh`, `guard-bash.sh`, `guard-secrets.sh`, `guard-prompt-injection.sh`, `session-context.sh`, `session-end.sh` (6종)
- [ ] `brain/` — `CLAUDE.md`, `coding/`, `testing/`, `api/`, `planning/`, `product/`, `management/`, `templates/`
- [ ] `system/mcp-shared/` — `servers.json`, `setup.sh`, `clean.sh`, `README.md`, `.env.example`
- [ ] `skills/` — 9 카테고리 (`ci`, `design`, `dev`, `docs`, `mgmt`, `plan`, `prod`, `review`, `wiki`) + `_template.md`
- [ ] `system/subagents/` — 최소 5개 `*.md`
- [ ] `scripts/` — `global-install.sh`, `global-uninstall.sh`, `project-link.sh`, `project-unlink.sh`, `configure.sh`, `post-install-check.sh`
- [ ] `scripts/lib/` — `common.sh`, `tui.sh`, `jq_merge.sh`, `secrets.sh`
- [ ] `docs/` — `dev/`, `examples/`, `process/`, `writing/`
- [ ] `install.sh` 가 레포 루트에 존재하고 실행 권한 보유

### §2. 설치·링크 모델 (10점)

- [ ] `install.sh` 가 단일 진입점으로 동작 (Phase 구조 + `--help` 지원)
- [ ] `scripts/configure.sh` 와 `scripts/post-install-check.sh` 가 존재하고 `bash -n` 통과
- [ ] `scripts/global-install.sh` 가 `--force`, `--with-mcp` 옵션 지원
- [ ] `scripts/project-link.sh` 가 `--with brain|skills/*|docs/*` 영역 지원
- [ ] `skills/<category>/` 가 카테고리 단위로 `~/.claude/commands/<category>` 디렉토리 링크 가능
- [ ] `system/subagents/` 가 `~/.claude/agents/` 로 링크 가능
- [ ] `scripts/global-install.sh` 와 `scripts/project-link.sh` 에 `[ -L ]` 또는 `readlink` 기반 중복 링크 방지 로직 존재

### §3. Skills 의 brain 강제 준수 (15점)

각 `skills/**/*.md` (단 `_template.md` 제외) 에 대해:

- [ ] YAML frontmatter 에 `follows-brain` 배열이 존재함. **경로 규약**: 설치 후 관점의 `brain/…` 로 기입하고, 검증 시 `brain/…` 로 resolve 하여 실제 파일 존재 확인 (이중 허용 금지)
- [ ] `enforcement: required` 또는 `recommended` 명시
- [ ] 본문 상단에 "Brain 원칙 준수 필수" 블록 존재 (`⚠️` + `@brain/...` 참조)
- [ ] `name: <category>:<slug>` 형식이 파일 경로(`skills/<category>/<slug>.md`)와 일치
- [ ] `type: slash-command` 또는 그에 준하는 type 명시
- [ ] 9 카테고리 각각에 최소 1개 스킬 존재

### §4. Global 및 brain 자동 로드 (10점)

- [ ] `system/CLAUDE.md` 가 `@brain/CLAUDE.md` 를 참조
- [ ] `system/CLAUDE.md` 가 **존댓말 규칙**, **한글 응답**, **Colima** 규칙을 포함
- [ ] `brain/CLAUDE.md` 의 `@` 참조 경로가 실제 파일과 매칭 (philosophy/coding/testing/api/writing/ai/planning/product/management)
- [ ] `brain/templates/CLAUDE.md.template` 에 brain 자동 로드 안내 존재
- [ ] `brain/` 의 5도메인(개발·기획·프로덕트·경영·AI) + 철학 구조가 README 와 일치

### §5. MCP 설정 (15점)

- [ ] `system/mcp-shared/servers.json` 이 유효한 JSON
- [ ] **핵심 4종 필수 등록**: `github`, `jira`, `confluence`, `playwright`
- [ ] **선택 등록 서버**(`servers.json` 의 핵심 4종 이외 나머지) 는 등록 여부는 자유지만 **등록 시 동일 규칙**(inputs 배열 · secret flag · 버전 핀) 을 전부 준수
- [ ] 등록된 **모든 서버**에 `inputs` 배열이 있고 `secret: true` 항목은 Keychain 대상
- [ ] 등록된 **모든 서버**의 `npx` 실행 인자가 **버전 핀** (`@x.y.z`) 되어 있음 (공급망 리스크 방어)
- [ ] `system/mcp-shared/setup.sh` 에 `# Phase 1`, `# Phase 2`, `# Phase 3` 주석이 이 순서로 존재하고, Phase 3 앞에 `OPT_DRY_RUN` 분기 종료 로직 포함
- [ ] `system/mcp-shared/setup.sh` 가 `--dry-run` 옵션을 파싱하고 `OPT_DRY_RUN` 변수로 분기 처리
- [ ] `system/mcp-shared/clean.sh` 가 `--purge-env` 옵션을 파싱하고 `security delete-generic-password` 또는 `secret-tool` 포함
- [ ] `scripts/lib/secrets.sh` 에 `security`(macOS Keychain), `secret-tool`(libsecret), 파일 폴백 3가지 분기 모두 존재
- [ ] `setup.sh` 와 `clean.sh` 모두 `bash -n` 통과

### §6. Hooks (5점)

- [ ] `system/hooks/` 에 6종(format, guard-bash, guard-secrets, guard-prompt-injection, session-context, session-end) 모두 존재
- [ ] 모두 `set -euo pipefail` 시작 + 실행 권한 + `bash -n` 통과
- [ ] `system/settings.json` 의 hook 등록이 실제 파일 경로와 일치
- [ ] `guard-secrets.sh` 가 `ghp_`, `xoxb-`, `sk-`, `AKIA`, `glpat-` 등 주요 시크릿 패턴 차단 (§10 과 동일 목록)
- [ ] `guard-prompt-injection.sh` 가 `WebFetch|WebSearch|Bash` 결과에서 영·한 prompt injection 패턴을 스캔 (§ ai-usage.md 외부 컨텍스트 신뢰 등급)

### §7. Subagents (5점)

- [ ] `system/subagents/` 에 최소 5개 에이전트 존재
- [ ] 각 파일에 YAML frontmatter(`name`, `description`, `tools` 또는 동등 필드) 존재
- [ ] `name` 이 파일명과 일치
- [ ] `~/.claude/agents/` 로 링크 가능한 구조

### §8. 스크립트 품질 (10점)

**대상 범위 2종**:
- **(A) 진입점 스크립트**: `install.sh`, `scripts/*.sh` (lib 제외), `system/mcp-shared/setup.sh`, `system/mcp-shared/clean.sh`
- **(B) 라이브러리·훅**: `scripts/lib/*.sh`, `system/hooks/*.sh`

체크 항목:
- [ ] (A+B) `set -euo pipefail` 로 시작
- [ ] **(A 한정)** 실행 권한(`chmod +x`) 부여됨 — 라이브러리(`scripts/lib/*.sh`) 는 `source` 전용이므로 실행권한 면제. 훅(`system/hooks/*.sh`) 은 Claude Code 가 직접 실행하므로 실행권한 필수
- [ ] **(B 훅 한정)** `system/hooks/*.sh` 도 실행 권한 부여됨
- [ ] (A+B) 전부 `bash -n` 통과
- [ ] **(A 한정)** `scripts/lib/common.sh` 의 공통 함수 사용 (로그, 백업, `link_idempotent`) — 라이브러리 자신 및 `install.sh` (위임 래퍼, 자체 파일 조작 없음)는 제외
- [ ] **(A 한정)** `--help` 옵션 제공
- [ ] **(A 한정)** 링크 생성 스크립트(`global-install.sh`, `project-link.sh`)에서 `[ -L ]` 또는 `readlink` 기반 중복 방지 로직 사용

### §9. Writing 가이드 · 깨진 링크 (10점 = 9a 4점 + 9b 6점)

**§9a. Writing 가이드 (4점)**
- [ ] `docs/writing/` 에 필수 5종 존재: `commit-message-guide.md`, `pr-description-guide.md`, `doc-style-guide.md`, `korean-tone-guide.md`, `adr-writing-guide.md`
- [ ] 상호 참조(@/상대경로)가 깨지지 않음 (존댓말 검증은 §11 반말 검출로 커버)

**§9b. 깨진 링크 (6점)**
- [ ] 모든 `@<path>` 참조가 실제 파일을 가리킴. **resolve 규칙**: `@brain/...` → `brain/...`, `@docs/...` → `docs/...`, `@skills/...` → `skills/...`
- [ ] 모든 마크다운 내부 링크 `[text](path)` 가 유효
- [ ] 최상위 `README.md` 와 각 하위 README 의 목차가 실제 파일과 일치

### §10. 보안 (5점)

- [ ] 레포에 실제 토큰·비밀값이 커밋되지 않음 (`ghp_`, `xoxb-`, `sk-`, `AKIA`, `glpat-` 등)
- [ ] `system/mcp-shared/.env.example` 은 예시 값만 포함
- [ ] `.gitignore` 에 `secrets.env`, `mcp.public.env`, `backups/`, `secrets/*.local*` 포함
- [ ] `system/settings.json` 에는 `${VAR}` 참조만 있고 실제 값 없음
- [ ] `system/memory-seed/` 중 민감정보가 포함된 파일 없음

### §11. 한글 톤 · 응답 규칙 (5점)

- [ ] 모든 문서가 존댓말 사용 — 반말 종결어미(`다$` 이외의 `~해.`, `~하자.`, `~야.` 등 **구두점 직전** 패턴) 가 사용되지 않음. `~지` 는 오탐이 심해(가지/유지/금지/지금 등) 자동 검사에서 제외
- [ ] 변수·함수·파일명은 영어
- [ ] 이모지는 섹션 헤더 수준에서만 사용 (본문 과다 사용 금지)
- [ ] `system/CLAUDE.md` 와 `brain/CLAUDE.md` 의 한글 정책이 일치

## 출력 형식

```markdown
# claude-cockpit 자가 검증 결과

**날짜**: YYYY-MM-DD | **커밋**: <short-sha> | **브랜치**: <branch>

## 종합 점수: XX/100

**근거 표기**: 🤖 = 자동 검사 블록으로 입증, 👤 = Claude 의 코드 판독·추론

| 영역 | 점수 | 상태 | 근거 | 핵심 발견 |
|------|------|------|------|----------|
| §1 디렉토리 구조        | X/10 | 🟢/🟡/🔴 | 🤖 | ... |
| §2 설치·링크 모델        | X/10 | ... | 🤖+👤 | ... |
| §3 Skills brain     | X/15 | ... | 🤖+👤 | ... |
| §4 Global & brain   | X/10 | ... | 🤖+👤 | ... |
| §5 MCP 설정             | X/15 | ... | 🤖+👤 | ... |
| §6 Hooks                | X/5  | ... | 🤖 | ... |
| §7 Subagents            | X/5  | ... | 🤖+👤 | ... |
| §8 스크립트 품질         | X/10 | ... | 🤖+👤 | ... |
| §9 Writing · 링크       | X/10 | ... | 🤖+👤 | ... |
| §10 보안                | X/5  | ... | 🤖 | ... |
| §11 한글 톤             | X/5  | ... | 🤖+👤 | ... |

상태: 🟢 80+ / 🟡 60-79 / 🔴 <60 (영역 내 퍼센트 기준)

## 실패 항목
(항목별로 파일 경로와 수정 방안)

## 권장 조치 (우선순위순)
1. [P0] ...
2. [P1] ...
3. [P2] ...
```

## 자동 검사

Claude 가 아래 커맨드를 실행해 근거 데이터를 수집한 뒤 체크리스트에 매핑합니다. 모든 명령은 cockpit 레포 루트에서 실행합니다.

### 자동 검사 → 섹션 매핑 (부분 실행용)

`$ARGUMENTS` 로 특정 섹션만 재검증할 때 아래 표의 해당 번호만 실행하면 됩니다.

| 섹션 | 자동 검사 번호 | 비고 |
|---|---|---|
| §1 디렉토리 구조 | #1 | find 로 구조 스냅샷 |
| §2 설치·링크 | #2a, #2b | 진입점 옵션 grep + 멱등성 가드 grep |
| §3 Skills brain | #3, #3b | frontmatter + 본문 ⚠️ 블록 |
| §4 Global & brain | #7 | 깨진 @ 참조 검증 |
| §5 MCP | #5, #5b | JSON 검증 + setup/clean/secrets 정적 분석 |
| §6 Hooks | #9 | 양방향 차집합 |
| §7 Subagents | #11 | frontmatter + name/파일 일치 |
| §8 스크립트 품질 | #3c, #4, #8b | bash -n + set -euo + 멱등성 가드 grep |
| §9b 깨진 링크 | #7 | |
| §10 보안 | #8 | git grep 시크릿 패턴 |
| §11 한글 톤 | #10 | PCRE 반말 검출 |

### 스크립트 블록

```bash
# ============================================================
# 1) §1 — 디렉토리 구조 스냅샷
# ============================================================
find . -maxdepth 3 -type d \
  -not -path '*/\.*' -not -path '*/node_modules*' | sort

# ============================================================
# 2a) §2 — install.sh / global-install / project-link 옵션 지원 검사
# ============================================================
grep -q -- '--help'     install.sh                     || echo "MISSING --help: install.sh"
grep -q -- '--force'    scripts/global-install.sh       || echo "MISSING --force: global-install.sh"
grep -q -- '--with-mcp' scripts/global-install.sh       || echo "MISSING --with-mcp: global-install.sh"
grep -qE -- '--with[= ]' scripts/project-link.sh         || echo "MISSING --with: project-link.sh"

# ============================================================
# 2b) §2 — 멱등성 가드: [ -L ] 또는 readlink 기반 중복 링크 방지
# ============================================================
grep -qE '\[ -L \]|readlink' scripts/global-install.sh || echo "MISSING idempotent guard: global-install.sh"
grep -qE '\[ -L \]|readlink' scripts/project-link.sh   || echo "MISSING idempotent guard: project-link.sh"

# ============================================================
# 3) §3 — skills frontmatter 검사 (awk 로 YAML 블록 정확 추출)
# ============================================================
find skills -type f -name '*.md' ! -name '_template.md' ! -name '_template.ko.md' | while read -r f; do
  fm=$(awk '/^---$/{c++; if(c==2) exit; next} c==1' "$f")
  echo "$fm" | grep -q 'follows-brain'                         || echo "MISSING follows-brain: $f"
  echo "$fm" | grep -Eq 'enforcement: (required|recommended)'      || echo "MISSING enforcement: $f"
  echo "$fm" | grep -Eq '^name: [a-z-]+:[a-z0-9-]+'                || echo "MISSING name:<cat>:<slug>: $f"
done

# 3b) §3 — 본문 "Brain 원칙 준수 필수" 블록 (⚠️ + @brain/…) 존재 검사
find skills -type f -name '*.md' ! -name '_template.md' ! -name '_template.ko.md' | while read -r f; do
  body=$(awk '/^---$/{c++; next} c==2' "$f" | head -10)
  echo "$body" | grep -q '⚠️'               || { echo "MISSING ⚠️ block: $f"; continue; }
  echo "$body" | grep -q '@brain/'       || echo "MISSING @brain/ in ⚠️ block: $f"
done

# 3c) §8 — 모든 쉘 스크립트 문법 검사 (실패 파일 개별 식별)
fail=0
while IFS= read -r -d '' f; do
  bash -n "$f" || { echo "FAIL: $f"; fail=1; }
done < <(find scripts system/hooks system/mcp-shared -type f -name '*.sh' -print0)
bash -n install.sh || { echo "FAIL: install.sh"; fail=1; }
[ $fail -eq 0 ] && echo "bash -n: OK"

# ============================================================
# 4) §8 — set -euo pipefail 누락 검사 (파일 전체 검색)
# ============================================================
find scripts system/hooks system/mcp-shared -type f -name '*.sh' | while read -r s; do
  grep -q 'set -euo pipefail' "$s" || echo "MISSING set -euo: $s"
done
grep -q 'set -euo pipefail' install.sh || echo "MISSING set -euo: install.sh"

# ============================================================
# 8b) §8 — 멱등성 가드: 링크 생성 스크립트에 [ -L ] 또는 readlink 존재
# ============================================================
grep -qE '\[ -L \]|readlink' scripts/global-install.sh || echo "MISSING idempotent guard: global-install.sh"
grep -qE '\[ -L \]|readlink' scripts/project-link.sh   || echo "MISSING idempotent guard: project-link.sh"

# ============================================================
# 5) §5 — MCP servers.json 유효성 + 필수/선택 서버 검증 + 버전 핀
# ============================================================
python3 <<'PY'
import json, re
d = json.load(open('system/mcp-shared/servers.json'))
servers = d.get('mcpServers', d.get('servers', {}))
required = {'github','jira','confluence','playwright'}
missing = required - set(servers)
print('MCP system missing:', missing or 'none')
for name, cfg in servers.items():
    args = cfg.get('args', [])
    if cfg.get('command','') == 'npx':
        # -y 와 그 외 플래그를 건너뛴 첫 번째 패키지 스펙
        pkg = next((a for a in args if not a.startswith('-') and a != 'y'), '')
        if not re.search(r'@\d', pkg):
            print(f'UNPINNED: {name} ({pkg!r})')
    inputs = cfg.get('inputs', None)
    if inputs is None:
        print(f'NO inputs: {name}')
    else:
        # secret:true 가 없는 inputs 가 있을 때는 모두 secret:false 로 명시됐는지 확인
        for inp in inputs:
            if isinstance(inp, dict) and 'secret' not in inp:
                print(f'MISSING secret flag in inputs[{inp.get("name","")}]: {name}')
PY

# ============================================================
# 5b) §5 — setup.sh / clean.sh / secrets.sh 정적 분석
# ============================================================
# setup.sh: Phase 1·2·3 순서 + OPT_DRY_RUN 분기
python3 <<'PY'
import re
txt = open('system/mcp-shared/setup.sh').read()
phases = [m.start() for m in re.finditer(r'#\s*Phase [123]', txt)]
if len(phases) < 3:
    print(f'setup.sh: Phase 주석 부족 ({len(phases)}개 발견, 3개 필요)')
elif not (phases[0] < phases[1] < phases[2]):
    print('setup.sh: Phase 1·2·3 순서 이상')
else:
    print('setup.sh Phase 순서: OK')
if 'OPT_DRY_RUN' not in txt:
    print('setup.sh: OPT_DRY_RUN 변수 없음')
else:
    print('setup.sh OPT_DRY_RUN: OK')
if '--dry-run' not in txt:
    print('setup.sh: --dry-run 옵션 없음')
else:
    print('setup.sh --dry-run: OK')
PY

# clean.sh: --purge-env + security delete-generic-password 또는 secret-tool
grep -q -- '--purge-env' system/mcp-shared/clean.sh     || echo "clean.sh: MISSING --purge-env"
grep -qE 'secrets_delete|security delete-generic-password|secret-tool' system/mcp-shared/clean.sh \
  || echo "clean.sh: MISSING Keychain/libsecret 삭제 커맨드 (secrets_delete 또는 직접 호출)"

# secrets.sh: security(macOS) + secret-tool(Linux) + 파일 폴백 3가지 분기
grep -q 'security'    scripts/lib/secrets.sh || echo "secrets.sh: MISSING macOS Keychain (security)"
grep -q 'secret-tool' scripts/lib/secrets.sh || echo "secrets.sh: MISSING libsecret (secret-tool)"
grep -qE 'file|fallback' scripts/lib/secrets.sh || echo "secrets.sh: MISSING 파일 폴백"

# ============================================================
# 7) §4, §9b — 깨진 @ 참조 검증 (source:line 표시 포함)
#     resolve 규칙:
#       @brain/... → brain/...
#       @skills/...    → skills/...
#       @subagents/... → system/subagents/...
#       @docs/... · @system/... · @skills/... · @system/subagents/... → 그대로
#       그 외 상대 참조 → 참조 원본 파일 기준 디렉토리 · brain/ · docs/ 3곳 시도
# ============================================================
grep -rnoE '@[a-zA-Z][a-zA-Z0-9/_.-]*\.md' --include='*.md' system/ brain/ skills/ docs/ \
  | while IFS=: read -r src line ref; do
      p="${ref#@}"
      case "$p" in
        skills/*) real="$p" ;;
        subagents/*) real="system/$p" ;;
        docs/*|system/*|brain/*) real="$p" ;;
        *)
          # 컨텍스트 인식 fallback: 원본 파일 디렉토리 → brain → docs
          src_dir=$(dirname "$src")
          if   [ -f "$src_dir/$p"        ]; then real="$src_dir/$p"
          elif [ -f "brain/$p"  ]; then real="brain/$p"
          elif [ -f "docs/$p"            ]; then real="docs/$p"
          else real="brain/$p"  # 실패 시 표시용 경로
          fi
          ;;
      esac
      [ -f "$real" ] || echo "BROKEN: $src:$line  $ref → $real"
    done | sort -u

# ============================================================
# 8) §10 — 커밋된 시크릿 패턴 스캔
# ============================================================
git grep -nE '(ghp_[A-Za-z0-9]{20,}|xoxb-[A-Za-z0-9-]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|glpat-[A-Za-z0-9_-]{20,})' \
  -- ':!*.example' ':!skills/review/cockpit.md' \
  || echo "secrets: clean"

# ============================================================
# 9) §6 — Hooks 등록 vs 실제 파일 일치 (양방향 차집합)
# ============================================================
python3 <<'PY'
import json, os, re
s = json.load(open('system/settings.json.template'))
files = {f for f in os.listdir('system/hooks') if f.endswith('.sh')}
referenced = set()
def walk(x):
    if isinstance(x, dict):
        for v in x.values(): walk(v)
    elif isinstance(x, list):
        for v in x: walk(v)
    elif isinstance(x, str):
        for m in re.findall(r'system/hooks/([\w.-]+\.sh)', x): referenced.add(m)
        for m in re.findall(r'(?<!system/)hooks/([\w.-]+\.sh)', x): referenced.add(m)
walk(s.get('hooks', {}))
print('registered-but-missing:', sorted(referenced - files) or 'none')
print('file-but-unregistered :', sorted(files - referenced) or 'none')
PY

# ============================================================
# 10) §11 — 반말 종결어미 검출 (rg 우선, BSD grep 환경 폴백)
#      종결어미만 매칭: 구두점(.!?) 직전 패턴
#      앞글자 부정 선행: 위해/대해/이해/통해/의해/견해/아해/름해/빠해 제외
# ============================================================
BANMAL_RE='(?<![이위대통의견아름빠])해[.!?]|(?<!말)하자[.!?]|(?<![가-힣])야[.!?]'
# 자기 참조 오탐(체크리스트 본문에 예시 포함) 회피를 위해 cockpit.md 자신 제외
if command -v rg >/dev/null 2>&1; then
  rg -nP "$BANMAL_RE" system/ brain/ skills/ docs/ \
    --glob '*.md' --glob '!skills/review/cockpit.md' --glob '!skills/review/cockpit.ko.md' | head -30
elif grep -rnP '' --include='*.md' system/ >/dev/null 2>&1; then
  grep -rnP "$BANMAL_RE" --include='*.md' \
    --exclude='cockpit.md' --exclude='cockpit.ko.md' system/ brain/ skills/ docs/ 2>/dev/null | head -30
else
  echo "반말 검출: rg / grep -P 모두 미지원 환경입니다. 'brew install ripgrep' 권장."
fi

# ============================================================
# 11) §7 — Subagents frontmatter · 이름·파일 일치 검사
# ============================================================
find system/subagents -type f -name '*.md' | while read -r f; do
  fm=$(awk '/^---$/{c++; if(c==2) exit; next} c==1' "$f")
  echo "$fm" | grep -q '^name: '        || { echo "MISSING name: $f"; continue; }
  echo "$fm" | grep -q '^description: ' || echo "MISSING description: $f"
  name=$(echo "$fm" | awk '/^name: /{print $2; exit}')
  base=$(basename "$f" .md)
  base=${base%.ko}
  [ "$name" = "$base" ] || echo "name/file mismatch: $f (name=$name)"
done
```

## 점수 환산 규칙

- 각 섹션의 체크박스 통과율 × 섹션 배점 = 섹션 점수 (소수점 반올림)
- 🟢 = 섹션 내 통과율 ≥ 80%, 🟡 = 60~79%, 🔴 = <60%
- 종합 점수 = 11개 섹션 합 (100점 만점)
- P0/P1/P2 우선순위:
  - **P0**: 보안·설치·링크 깨짐 (§5 / §6 / §10 실패)
  - **P1**: 규약 위반으로 신규 사용자 혼란 초래 (§3 / §4 / §9 실패)
  - **P2**: 품질·일관성 개선 (§1 / §2 / §7 / §8 / §11 실패)
