# 커밋 메시지 표준

> 사람과 AI 에이전트 모두 커밋 작성 시 이 표준을 따릅니다. 세션 시작 시 자동 로드되므로
> 에이전트는 커밋할 때 별도 지시 없이 이 규칙을 적용합니다.
> git 에디터 템플릿: cockpit `system/git/gitmessage` (설치 시 `~/.gitmessage` 링크 + `commit.template` 설정).
> 배경 해설·확장 예시: cockpit `docs/writing/commit-message-guide.md`.

## 형식 — Conventional Commits + 한글 본문

```
<type>(<scope>): <subject>

<body>

<footer>
```

| 요소 | 규칙 |
|------|------|
| type | `feat` `fix` `refactor` `perf` `docs` `test` `chore` `ci` `build` `style` `revert` |
| scope | 모듈/서비스명, 선택 (예: `account`, `mcp`, `brain`) |
| subject | 명령형 · 마침표 없음 · **70자 이하** · 제목만 보고 "왜"가 떠오르게 |
| body | **"왜" 먼저**(문제·배경) → 무엇을(불릿) → 검증 방법(사소하면 생략) · 줄당 72자 |
| footer | `Refs: PROJ-123` · `Closes: #42` · `BREAKING CHANGE: …` |

## type 선택 기준 (요약)

- `feat` 새 기능 / `fix` 버그(의도↔동작 간극) / `refactor` 동작 불변 정리 / `perf` 성능
- `docs` 문서만 / `test` 테스트만 / `chore` 설정·의존성·잡일 / `ci` `build` `style` `revert`
- 애매하면: 사용자 눈에 보이는 변화면 `feat`/`fix`, 아니면 `refactor`/`chore`

## 원칙

1. **한 커밋 = 한 변경 의도** — 리팩터링과 기능 추가를 섞지 않는다
2. 제목은 "무엇"이 아니라 **"왜"가 떠오르게** — ❌ `fix: null 체크 추가` → ✅ `fix(account): 로그인 null 세션 처리 누락`
3. 명령형 현재형 — "추가한다"보다 "추가"로 간결하게

## AI 에이전트 커밋 규칙

- **요청 시에만 커밋** — 사용자가 커밋/푸시를 요청하지 않았으면 하지 않는다
- 커밋 전 `git status` + `git diff --staged` 확인 — 의도치 않은 파일 혼입 방지
- 본문은 heredoc 으로 작성 (개행 보존): `git commit -m "$(cat <<'EOF' … EOF)"`
- 서명 필수: `Co-Authored-By: <모델명> <noreply@anthropic.com>` (예: `Claude Fable 5`)

## 금지

- 무관 변경 여러 개 섞기
- `WIP` / `temp` / `fix typo` 단독 제목 (스쿼시 전 로컬 커밋은 예외)
- 민감값·시크릿·내부 절대경로 본문 기입
- 공유된 커밋 `--amend` 재작성 (별도 커밋으로)

---

**버전**: 1.0.0 | **최종 업데이트**: 2026-07-12
