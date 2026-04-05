---
name: cockpit:review
description: claude-cockpit 프로젝트 자체를 검증하는 슬래시 커맨드
type: slash-command
category: meta
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# claude-cockpit 자가 검증

> ⚠️ 이 문서는 cockpit 레포 **자체의** 품질을 확인하는 체크리스트입니다.
> 실행하면 아래 항목을 순서대로 점검하고 리포트를 출력합니다.

## 실행 방법

```bash
# 로컬에서 직접
make review

# 또는 Claude Code 에서 슬래시 커맨드로
/cockpit:review
```

Claude 가 이 문서를 읽고 아래 각 섹션을 순서대로 검사한 뒤, 마지막에 **종합 점수 + 실패 항목 + 권장 조치** 를 보고합니다.

## 검증 절차

### 1. 디렉토리 구조

다음 디렉토리가 모두 존재하고 비어 있지 않은지 확인합니다.

- [ ] `global/` — CLAUDE.md, settings.json, keybindings.json
- [ ] `mcp/` — servers.json, setup.sh, clean.sh, README.md
- [ ] `scripts/` — global-install.sh, global-uninstall.sh, project-link.sh, project-unlink.sh
- [ ] `scripts/lib/` — common.sh, tui.sh, jq_merge.sh, secrets.sh
- [ ] `skills/` — `_template.md`, `dev/`, `docs/`, `ci/`, `jira/`, `wiki/`
- [ ] `standards/` — CLAUDE.md, coding/, testing/, api/, templates/
- [ ] `docs/dev/` · `docs/examples/` · `docs/process/` · `docs/writing/`

### 2. 심볼릭 링크 모델 점검

- [ ] `skills/<category>/` 가 카테고리 단위로 되어 있어 `~/.claude/commands/<category>` 디렉토리 링크로 노출 가능
- [ ] `global/*` 세 파일이 존재
- [ ] `scripts/global-install.sh` 가 `--force`, `--with-mcp` 옵션을 지원
- [ ] `scripts/project-link.sh` 가 `--with standards|skills/*|docs/*` 영역을 지원

### 3. Skills 의 Standards 강제 준수

각 `skills/**/*.md` 파일에 대해:

- [ ] YAML frontmatter 에 `follows-standards` 배열이 존재하고 실제 경로를 가리키는가
- [ ] `enforcement: required` 또는 `recommended` 가 명시되어 있는가
- [ ] 본문 상단에 "Standards 준수 필수" 블록이 존재하는가 (`⚠️` + `@standards/...` 참조)
- [ ] `name: <category>:<slug>` 형식이 파일 경로와 일치하는가

### 4. Global 및 Standards 자동 로드

- [ ] `global/CLAUDE.md` 가 `@standards/CLAUDE.md` 를 참조하는가
- [ ] `global/CLAUDE.md` 가 **존댓말 규칙**, **한글 응답**, **Colima** 규칙을 포함하는가
- [ ] `standards/CLAUDE.md` 의 `@` 참조 경로가 실제 파일과 매칭되는가 (coding, testing, api)
- [ ] `standards/templates/CLAUDE.md.template` 에 standards 자동 로드 안내가 있는가

### 5. MCP 설정

- [ ] `mcp/servers.json` 이 유효한 JSON 이고 `github`, `jira`, `confluence`, `playwright` 4종을 포함
- [ ] 각 서버에 `inputs` 배열이 있고 `secret: true` 항목은 모두 Keychain 대상
- [ ] `mcp/setup.sh` 가 3-Phase 구조 (점검 → 입력 → 적용) 를 따르는가
- [ ] `mcp/setup.sh` 가 입력을 **모두 먼저 받은 뒤** 적용 단계로 진입하는가
- [ ] `scripts/lib/secrets.sh` 가 Keychain / libsecret / 파일 폴백을 지원
- [ ] `mcp/clean.sh` 가 `--purge-env` 로 Keychain 항목, 로더, rc source 라인을 모두 제거
- [ ] 두 스크립트 모두 `bash -n` 문법 검사 통과
- [ ] `mcp/setup.sh --dry-run` 가 부수효과 없이 완료

### 6. 스크립트 품질

모든 `scripts/*.sh`, `mcp/*.sh` 파일:

- [ ] `set -euo pipefail` 로 시작
- [ ] 실행 권한 (`chmod +x`) 부여됨
- [ ] `scripts/lib/common.sh` 의 공통 함수 사용 (로그, 백업, link_idempotent)
- [ ] `--help` 옵션 제공
- [ ] 멱등성 — 같은 명령을 두 번 실행해도 동일 상태

### 7. Writing 가이드

- [ ] `docs/writing/` 에 5개 파일 존재: commit-message, pr-description, doc-style, korean-tone, adr-writing
- [ ] 모두 존댓말로 작성되어 있는가
- [ ] 상호 참조가 깨지지 않았는가

### 8. 깨진 링크 / 참조

- [ ] 모든 `@<path>` 참조가 실제 파일을 가리키는가
- [ ] 모든 마크다운 내부 링크 `[text](path)` 가 유효한가
- [ ] README, 각 폴더 README 의 목차가 실제 파일과 일치

### 9. 보안

- [ ] 레포에 실제 토큰·비밀값이 커밋되지 않음 (grep `ghp_`, `xoxb-`, `sk-`, `AKIA` 등)
- [ ] `mcp/.env.example` 은 예시 값만 포함
- [ ] `.gitignore` 에 `secrets.env`, `mcp.public.env`, `backups/` 포함 (로컬 폴백이 있을 경우)
- [ ] `settings.json` 에는 `${VAR}` 참조만 있고 실제 값이 없는가

### 10. 한글 톤 · 응답 규칙

- [ ] 모든 문서가 존댓말을 사용하는가 (반말 검출: "~해", "~하자", "~야" 어미)
- [ ] 변수·함수·파일명은 영어
- [ ] 이모지 남용 없음

## 출력 형식

```markdown
# claude-cockpit 자가 검증 결과

## 종합 점수: XX/100

| 영역 | 점수 | 상태 | 발견 |
|------|------|------|------|
| 디렉토리 구조 | X/10 | 🟢/🟡/🔴 | ... |
| 심볼릭 링크 모델 | X/10 | ... | ... |
| Skills Standards | X/15 | ... | ... |
| Global & Standards | X/10 | ... | ... |
| MCP 설정 | X/15 | ... | ... |
| 스크립트 품질 | X/10 | ... | ... |
| Writing 가이드 | X/10 | ... | ... |
| 깨진 링크 | X/10 | ... | ... |
| 보안 | X/5  | ... | ... |
| 한글 톤 | X/5  | ... | ... |

## 실패 항목

(항목별로 파일 경로와 수정 방안)

## 권장 조치 (우선순위순)

1. [P0] ...
2. [P1] ...
3. [P2] ...
```

## 자동 검사 명령 (Claude가 활용)

```bash
# 구조 확인
find . -type d -not -path '*/\.*' | sort

# frontmatter 확인
for f in skills/**/*.md; do
  head -20 "$f" | grep -q 'follows-standards' || echo "MISSING: $f"
done

# 스크립트 문법 검사
for s in scripts/**/*.sh mcp/*.sh; do bash -n "$s" && echo "OK $s"; done

# dry-run
mcp/setup.sh --dry-run

# 깨진 @ 참조
grep -rn '@[a-z]' --include='*.md' standards/ global/ skills/ docs/ | grep -v 'email\|atlassian' | sort -u
```
