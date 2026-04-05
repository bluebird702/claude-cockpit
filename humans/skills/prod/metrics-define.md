---
name: prod:metrics-define
description: 기능/PRD 에 대한 Goal/Guardrail 지표 초안과 측정 이벤트 스키마를 제안
type: slash-command
category: prod
follows-standards:
  - standards/CLAUDE.md
  - standards/product/metrics.md
enforcement: required
---

# 성공 지표 정의기

> ⚠️ **Standards 준수 필수**
> - @standards/product/metrics.md (North Star / Goal / Guardrail 프레임, 활성화·리텐션 정의)

기능 하나에 대한 **Goal Metric + Guardrail Metric + 측정 이벤트 스키마**를 제안합니다. 지표 없이 런치하지 않는 규칙을 자동화.

$ARGUMENTS
- `<기능명 또는 PRD 파일 경로>` — 필수
- 예: `/prod:metrics-define 대화 검색 기능`
- 예: `/prod:metrics-define docs/prd/0007-search.md`

## 절차

### 1. 기능 이해

- 입력이 PRD 파일 경로면 해당 파일 전체 읽기
- 입력이 자유 텍스트면 맥락 되묻기 (1회): "누가 이 기능을 쓸 것인가? 성공이란 어떤 모습인가?"

### 2. 기존 지표 체계 확인

- `docs/metrics/` 또는 `@standards/product/metrics.md` 에서 프로젝트의 North Star / Core Action 정의 확인
- 기존 이벤트 스키마 파일 (`analytics/events.yaml`, `telemetry/schema.ts` 등) 탐색 → 네이밍 컨벤션 맞추기

### 3. 지표 제안 생성

각 항목은 **반드시** 다음을 포함:

**Goal Metric** (1개)
- 이름 (예: "검색 사용률")
- 정의 (어떤 액션을 어떻게 세는가)
- 타겟 값 + 기간 (예: "런치 2주 내 WAU 의 30%")
- 선행 지표인지 후행 지표인지 명시 (선행 선호)

**Guardrail Metric** (1-2개)
- 성능 (p95 응답시간) — 거의 항상 포함
- 상위 퍼널 지표 (가입/활성화)
- 에러율

**측정 이벤트 스키마**
```yaml
event_name: search_executed
properties:
  query_length: integer
  result_count: integer
  clicked_result: boolean
  source: enum [header, empty_state, keyboard_shortcut]
# PII 금지: query 원문, user_email 등은 포함하지 않음
```

### 4. 대시보드 위치 제안

- 기존 대시보드 URL 이 있으면 어느 패널에 추가할지 제안
- 없으면 "대시보드 신규 생성 필요" 로 플래그

### 5. 롤백 기준 체크

PRD 에 롤백 기준이 없거나 숫자가 아니면 **경고** + 제안값 제시.

## 출력 형식

```markdown
## 📊 제안 지표

**Goal**: <이름>
- 정의: ...
- 타겟: <숫자> (<기간>)
- 선행/후행: ...

**Guardrail**:
1. <이름> — 해치면 안 되는 임계값
2. ...

## 📡 이벤트 스키마
<yaml 블록>

## ⚠️ PII 체크
- [ ] 페이로드에 이메일/이름/전화 없음
- [ ] user_id 는 해시 또는 내부 ID
- [ ] 쿼리 원문·업로드 파일명 없음

## 🚨 롤백 기준 (PRD 에 없으면 추가 필요)
<숫자 조건>

## 📍 대시보드 배치
<기존 URL 또는 "신규 생성">
```

## 원칙

- **숫자 없는 지표 금지** — "많이" "잘" 같은 표현 거부
- **이벤트 네이밍**: `<object>_<verb_past>` (예: `search_executed`, `message_sent`). 프로젝트 기존 규칙이 있으면 그것을 우선
- **선행 지표 선호** — "다음달 리텐션" 보다 "첫날 액션 수"
- **PII 차단** — 이벤트 페이로드에 이메일/이름이 보이면 즉시 경고
