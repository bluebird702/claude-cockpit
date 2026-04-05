# 보안 기준 (1인 창업 에디션)

> 1인 창업 컨텍스트에서 최소한으로 지켜야 할 보안 원칙. 과정이 아니라 **실패하지 않을 최소선**을 정의합니다.

## 시크릿 관리

- **저장소**: macOS Keychain / Linux libsecret. 파일 폴백은 마지막 수단 (`chmod 600`).
  - MCP 토큰은 `core/mcp-shared/setup.sh` 가 자동으로 Keychain 에 저장합니다.
- **커밋 금지**: `.env`, `credentials.json`, `*.pem`, `service-account*.json` — 실수 방지를 위해 `core/hooks/guard-secrets.sh` 가 PreToolUse 훅으로 차단합니다.
- **리포에 올리는 것**: `.env.example` 만 (실제 값 없음).
- **쉘 rc 로딩 금지**: 토큰을 `~/.zshrc` 에 `source` 하지 않습니다. MCP 프로세스에만 전달되도록 설계돼 있습니다 (`core/mcp-shared/setup.sh --export-rc` 는 기본 OFF).

## 의존성

- **감사 주기**: 활성 프로젝트는 **월 1회** `/review:deps` 실행. 새 PR 에도 의존성 변경이 있으면 즉시.
- **대응 기준**:
  - `critical` / `high` — 24시간 내 픽스 또는 대안.
  - `moderate` — 1주일 내.
  - `low` — 다음 정기 감사까지.
- **버전 핀**: `core/mcp-shared/servers.json` 처럼 `npx -y pkg@x.y.z` 형태로 고정 (공급망 공격 완화).

## 로그·에러

- **PII 금지**: 이메일, 전화, 주민등록, 토큰, 비밀번호는 **어떤 로그에도** 출력 금지. 디버깅 중이라도.
- **스택트레이스 외부 전송 전** 마스킹 확인 (Sentry/Slack 웹훅).
- **예외 메시지에 사용자 입력 원문 포함 금지** — `Invalid email format` 은 OK, `Invalid email: foo@bar.com` 는 NG.

## 인증·인가

- **토큰은 URL 에 싣지 않음** — Body/Header 만. (자세한 이유는 `@standards/api/api-design.md` § 보안)
- **민감 작업 재인증**: 이메일·비밀번호 변경, 결제 수단 변경은 현재 비밀번호 재확인.
- **최소 권한**: GitHub PAT 은 `repo, read:org` 수준까지만. Slack Bot Token 은 필요한 채널 scope 만.

## 백업·복구

- **코드**: push 즉시 GitHub 에 존재하는 것으로 간주. 로컬만 있는 브랜치 > 2일 금지.
- **문서·메모리**: cockpit `memory/` 는 레포에 포함. 개인 노트는 iCloud/Notion.
- **DB**: 프로덕션 DB 는 일 1회 자동 백업 + 주 1회 복구 리허설.

## 사고 발생 시

1. 노출된 시크릿 **즉시 로테이션** (GitHub · Jira · Slack · DB 등).
2. 노출 범위 기록 → `docs/adr/` 에 포스트모템 (간단히 1페이지).
3. 같은 실수 재발 방지 룰 추가 → 이 문서 또는 훅.

## 체크리스트 (월 1회)

- [ ] `.env` 류 파일이 커밋되지 않았는지 `git log --all -p | grep -iE 'password|token|secret'` 샘플링
- [ ] `/review:deps` 실행, moderate 이상 처리
- [ ] MCP 토큰 만료 확인 (GitHub PAT 90일, Jira 토큰 1년)
- [ ] 사용하지 않는 MCP 서버 / API 키 제거

---

**버전**: 1.0.0 | **최종 업데이트**: 2026-04-05
