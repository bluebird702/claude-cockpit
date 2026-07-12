---
name: wiki:capture
description: 현재 세션에서 배운 내용·결정·아키텍처 스케치를 문서 초안으로 포착
type: slash-command
category: wiki
follows-standards:
  - standards/CLAUDE.md
  - standards/management/decision-log.md
enforcement: required
---

# 세션 학습 포착

> ⚠️ **Standards 준수 필수** · @standards/CLAUDE.md · @standards/management/decision-log.md · (문체: cockpit 레포 `docs/writing/`)

대화·디버깅·설계 세션에서 얻은 **재사용 가능한 지식**을 휘발되기 전에 문서 초안으로 남깁니다.

$ARGUMENTS
- `adr` — Architecture Decision Record 포맷
- `runbook` — 운영 런북
- `howto` — 튜토리얼성 가이드
- 없음 → 자동 판정 (대화 성격 기반)

## Step 1: 세션 스캔
현재 대화 기록에서 다음을 추출:
- **결정**: "X 대신 Y 를 쓰기로 함" 류 문장
- **근거**: 결정의 이유
- **대안**: 거절된 선택지와 이유
- **사이드 이펙트**: 이 결정이 영향을 주는 다른 시스템

## Step 2: 포맷 선택
- ADR: 결정이 하나 명확하고 근거가 있을 때
- 런북: 운영 절차가 정리되었을 때
- HowTo: 누가 따라 하면 재현 가능한 절차
- 메모: 위 셋에 해당 안 함 (가장 가벼움)

## Step 3: 초안 생성

### ADR — 표준 템플릿 사용 (여기 복사하지 않음, SSOT)
- **골격**: `@standards/templates/adr-template.md` 를 그대로 사용합니다.
- **작성 기준** (언제 ADR 인가 · 상태 라이프사이클 · 체크리스트): `@standards/management/decision-log.md` 를 따릅니다.
- Alternatives 최소 1개, Consequences 에 Negative 포함 — 없으면 초안 반려.

### 런북 템플릿
```markdown
# Runbook: [증상/작업]

**트리거**: 언제 이 런북을 사용하는가
**예상 시간**: N분

## 사전 조건
- [ ] ...

## 절차
1. ...
2. ...

## 검증
- [ ] ...

## 실패 시
- 상황 A → ...
```

## Step 4: 저장 위치 제안
- ADR: `docs/adr/NNN-<slug>.md` (기존 최대 번호 +1)
- 런북: `docs/runbooks/<slug>.md`
- HowTo: `docs/howto/<slug>.md`
- Confluence MCP 가 있으면 업로드 옵션 제안 (사용자 승인 후)

## Step 5: 사용자에게 확인
```markdown
## 포착할 내용
[본문]

## 저장 제안
- 경로: `docs/adr/012-colima-over-docker-desktop.md`
- 또는 Confluence 페이지로 (MCP 사용)

저장할까요? (yes / 경로 수정 / 취소)
```

**금지**: 사용자 승인 없이 파일 생성 금지. 세션에 없던 내용 추측해서 채우지 말 것.
