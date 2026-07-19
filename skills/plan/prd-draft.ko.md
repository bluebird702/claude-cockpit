---
name: plan:prd-draft
description: 한 줄 아이디어를 1-페이지 PRD 초안으로 변환 (Out of Scope·롤백 기준 포함)
type: slash-command
category: plan
follows-standards:
  - brain/CLAUDE.md
  - brain/planning/prd-guidelines.md
  - brain/product/metrics.md
enforcement: required
---

# PRD 초안 생성기

> ⚠️ **Standards 준수 필수**
> - @brain/planning/prd-guidelines.md (1-페이지 형식, Out of Scope 필수)
> - @brain/product/metrics.md (Goal/Guardrail)

한 줄짜리 아이디어를 1-페이지 PRD 초안으로 변환합니다. **반드시** Out of Scope 와 숫자 롤백 기준을 포함합니다.

$ARGUMENTS
- `<한 줄 아이디어>` — 필수. 예: `/plan:prd-draft 사용자가 과거 대화를 검색할 수 있게`
- 인자 없음 → 현재 세션 컨텍스트에서 아이디어 추출 시도 (없으면 에러)

## 절차

### 1. 아이디어 파싱 및 되묻기

사용자 입력에서 다음을 추출. 모호하면 **1회만** 되묻습니다 (반복 질문 금지).

- **문제**: 누가, 무엇이 불편한가?
- **대상**: 전체 유저인가, 특정 세그먼트인가?
- **증거**: 사용자 피드백/지표/관찰 — 없으면 "가설" 로 명시

### 2. 맥락 수집 (병렬, 읽기 전용)

- 프로젝트 `docs/prd/` 디렉토리에서 최근 PRD 3개 읽기 → 형식·네이밍 맞추기
- 관련 기능의 현재 지표 있으면 확인 (`docs/metrics/` 또는 대시보드 링크)
- `memory/` 에서 관련 진행 중 프로젝트 정보

### 3. PRD 초안 생성

`@brain/planning/prd-guidelines.md` 의 1-페이지 형식을 **정확히** 따릅니다. 특히:

- **Out of Scope 섹션** 은 In Scope 보다 길어야 정상 (Feature creep 방지)
- **Goal Metric** 은 숫자 + 기간으로 — 숫자 못 찾으면 "TBD" 가 아니라 **제안값 2-3개** 를 적어 사용자가 고르게
- **롤백 기준** 도 숫자. "에러율 >1% OR p95 >2x" 형식
- **오픈 질문** 섹션에 본인이 판단 못 한 것 3-5개 나열

### 4. 파일 저장

- 위치: `docs/prd/NNNN-title-in-kebab.md` (NNNN 은 `docs/prd/` 내 최대값+1, 4자리)
- 상태: **Draft** 로 시작
- 저장 전 파일 경로를 사용자에게 제시하고 확인

## 출력 형식

1. 저장된 파일 경로
2. Goal Metric 과 롤백 기준 요약 (2-3줄)
3. 오픈 질문 리스트 — 사용자가 답해야 Approved 로 전환 가능

## 원칙

- **A4 1장 초과 금지** — 넘으면 Out of Scope 로 덜어냄
- **해결책 아닌 문제로 서술** — "검색 기능 추가" ❌ → "N주 전 대화를 찾지 못함" ✅
- **지표 없는 PRD 거부** — Goal Metric 이 "TBD" 뿐이면 사용자에게 제안값 제시 후 선택 요구
- **오픈 질문 > 3개면 쪼개기 신호** — PRD 를 여러 개로 분할 제안
