---
name: mgmt:security-monthly
description: security.md 가 요구하는 월 1회 보안 체크리스트 실행 (시크릿 샘플링·의존성·토큰 만료·미사용 키)
type: slash-command
category: mgmt
follows-standards:
  - standards/CLAUDE.md
  - standards/management/security.md
enforcement: required
---

# 월간 보안 체크

> ⚠️ **Standards 준수 필수**
> - @standards/management/security.md (§체크리스트 (월 1회) — 이 스킬이 그 체크리스트의 실행 도구)
> - @standards/philosophy.md (측정 없으면 주장 없음 — 각 항목은 명령 실행 결과로만 판정)

`security.md` 의 월 1회 체크리스트를 실제 명령으로 실행하고, 통과/실패/측정불가를 판정합니다. 눈대중 판정 금지 — 측정 못 한 항목은 `n/a` 로 표기합니다.

$ARGUMENTS
- 없음 → 현재 디렉토리의 프로젝트 대상
- **경로** → 해당 레포 대상
- `all` → 홈 아래 활성 레포 목록을 먼저 제시하고 사용자가 고른 것만

## 절차

### 1. 시크릿 커밋 이력 샘플링 (읽기 전용)

```bash
# 최근 3개월 커밋에서 시크릿 의심 패턴 샘플링 (전체 -p 덤프는 대형 레포에서 과도 — 기간 한정)
git log --all --since='3 months ago' -p -- . ':(exclude)*.lock' | grep -inE 'password|passwd|secret|token|api_key|BEGIN (RSA|EC|OPENSSH) PRIVATE' | head -30
```
- 적중 시 각 건을 열어 **실값인지 변수명/문서인지** 구분. 실값이면 **즉시 사고 대응 절차** (security.md §사고 발생 시: 로테이션 → 포스트모템 → 재발 방지 룰).

### 2. 의존성 감사

- `/review:deps` 를 실행하거나, 이미 이번 달 실행 이력이 있으면 그 결과를 인용.
- **대응 SLA 확인**: critical/high 24시간 · moderate 1주 · low 다음 정기 감사 (security.md §의존성).
- 열린 moderate+ 가 SLA 를 넘겼으면 실패로 표기.

### 3. 토큰·키 수명 점검

- MCP 토큰 만료: GitHub PAT(90일), Jira(1년) — 발급일 기록이 없으면 `n/a — 발급일 미기록` 로 표기하고 기록 시작을 액션으로.
- `~/.claude/`, Keychain 항목 중 **90일 이상 미사용** 키 후보 나열 (마지막 사용 확인 가능한 것만).

### 4. 미사용 MCP 서버/API 키

- `core/mcp-shared/servers.json` 의 서버 vs 최근 세션에서 실제 호출된 서버 대조.
- 3개월 미사용 서버는 제거 후보로 제시 (제거는 사용자 승인).

## 출력 형식

```markdown
# 🔒 월간 보안 체크 — YYYY-MM

| # | 항목 | 판정 | 근거 (명령/측정값) |
|---|------|------|---------------------|
| 1 | 시크릿 커밋 이력 | ✅/❌/n/a | grep 적중 N건 중 실값 0건 |
| 2 | 의존성 SLA | ✅/❌ | moderate 2건, 최장 경과 4일 |
| 3 | 토큰 만료 | ✅/❌/n/a | GitHub PAT D-30 |
| 4 | 미사용 키/서버 | ✅/❌ | figma 서버 3개월 미호출 |

## 액션 (최대 5개, 우선순위순)
1. ...

_측정 불가 항목_: <이유와 함께 명시 — 추측으로 채우지 않음>
```

**원칙**:
- 판정은 **명령 실행 결과로만**. 실행 못 했으면 `n/a` + 이유.
- 액션 5개 초과 금지 — 1인 인지 부담 절약.
- 실값 시크릿 발견 시 이 리포트보다 **로테이션이 먼저**.
- 마지막에 "이번 회차를 `docs/security/monthly-YYYY-MM.md` 에 저장할지" 사용자 승인 한 줄.
