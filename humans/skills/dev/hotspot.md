---
name: dev:hotspot
description: git 히스토리에서 자주 변경되는 파일(핫스팟)을 찾아 리팩터링 후보 제안
type: slash-command
category: dev
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
enforcement: required
---

# 코드 핫스팟 분석

> ⚠️ **Standards 준수 필수**
> @standards/CLAUDE.md · @standards/coding/coding-guidelines.md

자주 수정되는 파일은 대개 **책임이 과중하거나 경계가 잘못** 잡힌 곳입니다. git 로그로 빈도 × 복잡도 를 곱해 리팩터링 ROI 가 높은 후보를 찾습니다.

$ARGUMENTS
- 기간: `30d` (기본), `90d`, `1y`
- 경로: `src/` 같은 부분 경로로 제한
- 예: `/dev:hotspot 90d src/payment`

## Step 1: 기간·경로 파싱
`$ARGUMENTS` 에서 기간과 경로를 추출. 없으면 30일 · 전체.

## Step 2: 변경 빈도 수집
```bash
git log --since="<기간>" --name-only --pretty=format: -- <경로> \
  | grep -v '^$' \
  | sort | uniq -c | sort -rn | head -20
```

## Step 3: 복잡도 수집
각 후보 파일에 대해:
- 라인 수: `wc -l`
- 저자 수: `git log --since=... --format='%ae' -- <file> | sort -u | wc -l`
- 최근 커밋: `git log --since=... --format='%ci %s' -- <file> | head -5`

## Step 4: 스코어 계산
```
score = changes * log2(lines) * sqrt(authors)
```
- changes 많고 lines 많으면 리스크 증가
- authors 많으면 지식 분산 (긍정적이지만 조율 비용 증가)

## Step 5: 출력

```markdown
## 🔥 핫스팟 분석 (최근 30일, src/)

| # | 파일 | 변경 | LoC | 작성자 | 스코어 | 비고 |
|---|------|------|-----|--------|--------|------|
| 1 | `src/payment/processor.ts` | 18회 | 612 | 5명 | 87 | 테스트 부재 |
| 2 | `src/auth/middleware.ts`   | 11회 | 248 | 3명 | 34 | |
| 3 | `src/api/router.ts`        | 9회  | 891 | 4명 | 52 | 파일 분할 후보 |

## Top 3 리팩터링 제안

### ① payment/processor.ts
- **증상**: 한 파일에 결제·환불·정산 책임 혼재 (Single Responsibility 위반)
- **근거**: 최근 커밋 메시지의 45%가 "fix" — 회귀 비율 높음
- **제안**: `processor/charge.ts`, `processor/refund.ts`, `processor/settlement.ts` 로 분리
- **선행 작업**: 테스트 커버리지 확보 (`/dev:reproduce` 로 최근 버그 재현 후)

### ② api/router.ts
- **증상**: 891 라인, 엔드포인트 42개
- **제안**: 도메인별 라우터로 쪼개기 (payment/auth/order)

## 안전망
리팩터링 전에 반드시:
- [ ] 영향 범위 파일의 테스트 커버리지 > 70%
- [ ] 단일 PR 에 기능 변경 혼합 금지
- [ ] `/review:architecture` 로 경계 먼저 확정
```

**원칙**: 코드 이동·수정 금지. 분석과 제안만.
