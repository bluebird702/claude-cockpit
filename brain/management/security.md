# 보안 기준 (1인 창업 에디션)

> 1인 창업 컨텍스트에서 최소한으로 지켜야 할 보안 원칙. 과정이 아니라 **실패하지 않을 최소선**을 정의합니다.

## 보안 원칙 (Foundations)

> 아래 원칙이 아래 실무 규칙의 **"왜"** 다.

- **심층 방어(Defense in Depth)**: 한 겹이 뚫려도 다음 겹이 막는다 — 게이트웨이 + 서비스 + DB 각 층에서 검증(단일 방어선 금지).
- **최소 권한(Least Privilege)**: 토큰·키·DB 계정은 **필요한 범위만**. 기본 거부, 예외만 허용.
- **안전 기본값 · Fail-closed**: 미설정·장애 시 **안전한 쪽으로** 실패(운영 오설정은 **기동 실패**). silent fallback 금지. (가용성 우선 경로의 fail-open 은 **로컬 보호가 있을 때만**, 판단은 ADR)
- **외부 입력 불신(Zero Trust)**: 클라이언트 주입 헤더·`X-Forwarded-For`·프롬프트는 신뢰 경계 **밖** — 검증·정화 후 사용. (프롬프트 인젝션: @ai/ai-usage.md)
- **PII 최소화**: 수집·로깅·전송을 최소로. 로그·에러·이벤트에 이메일/이름/전화/토큰 금지.
- **경량 위협 모델(STRIDE)**: 새 기능마다 "누가·무엇을·어떻게 악용?" 1분 체크 — **S**poofing·**T**ampering·**R**epudiation·**I**nfo-disclosure·**D**oS·**E**levation.
- **공급망**: 버전 핀·의존성 감사(§의존성)·신뢰 저장소만. 빌드 산출물 출처 관리(가능하면 SLSA 지향).

## 시크릿 관리

- **저장소**: macOS Keychain / Linux libsecret. 파일 폴백은 마지막 수단 (`chmod 600`).
  - MCP 토큰은 `system/mcp-shared/setup.sh` 가 자동으로 Keychain 에 저장합니다.
- **커밋 금지**: `.env`, `credentials.json`, `*.pem`, `service-account*.json` — 실수 방지를 위해 `system/hooks/guard-secrets.sh` 가 PreToolUse 훅으로 차단합니다.
- **리포에 올리는 것**: `.env.example` 만 (실제 값 없음).
- **쉘 rc 로딩 금지**: 토큰을 `~/.zshrc` 에 `source` 하지 않습니다. MCP 프로세스에만 전달되도록 설계돼 있습니다 (`system/mcp-shared/setup.sh --export-rc` 는 기본 OFF).

## 의존성

- **감사 주기**: 활성 프로젝트는 **월 1회** `/review:deps` 실행. 새 PR 에도 의존성 변경이 있으면 즉시.
- **대응 기준**:
  - `critical` / `high` — 24시간 내 픽스 또는 대안.
  - `moderate` — 1주일 내.
  - `low` — 다음 정기 감사까지.
- **버전 핀**: `system/mcp-shared/servers.json` 처럼 `npx -y pkg@x.y.z` 형태로 고정 (공급망 공격 완화).

## 로그·에러

- **PII 금지**: 이메일, 전화, 주민등록, 토큰, 비밀번호는 **어떤 로그에도** 출력 금지. 디버깅 중이라도.
- **스택트레이스 외부 전송 전** 마스킹 확인 (Sentry/Slack 웹훅).
- **예외 메시지에 사용자 입력 원문 포함 금지** — `Invalid email format` 은 OK, `Invalid email: foo@bar.com` 는 NG.

## 인증·인가

- **토큰은 URL 에 싣지 않음** — Body/Header 만. (자세한 이유는 `@brain/api/api-design.md` § 보안)
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

> 실행 도구: `/mgmt:security-monthly` — 아래 항목을 명령 실행 결과로 판정합니다.

- [ ] `.env` 류 파일이 커밋되지 않았는지 `git log --all -p | grep -iE 'password|token|secret'` 샘플링
- [ ] `/review:deps` 실행, moderate 이상 처리
- [ ] MCP 토큰 만료 확인 (GitHub PAT 90일, Jira 토큰 1년)
- [ ] 사용하지 않는 MCP 서버 / API 키 제거

---

**버전**: 1.1.0 | **최종 업데이트**: 2026-07-05

> 변경(1.1.0): **보안 원칙(Foundations)** 추가 — 심층 방어·최소 권한·안전 기본값(fail-closed)·Zero Trust(외부 입력 불신)·PII 최소화·경량 STRIDE·공급망.
