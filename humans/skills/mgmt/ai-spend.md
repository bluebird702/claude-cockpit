---
name: mgmt:ai-spend
description: Claude 토큰·비용 일/주/월 회고 (ccusage 기반)
type: slash-command
category: mgmt
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# AI Spend 회고

> ⚠️ **Standards 준수 필수** · @standards/CLAUDE.md

1인 창업에서 AI 는 가장 큰 변동비입니다. statusline 은 *지금* 만 보여주므로, 이 스킬은 *추세와 비정상* 을 잡습니다.

$ARGUMENTS
- 없음 (기본): **이번 주** (월~오늘) + 오늘 단독
- `week`: 지난 7일 (요일별)
- `month`: 이번 달 (일별)
- `last-week`: 지난주 (월~일)

## 사전 조건

`ccusage` 가 설치돼 있어야 합니다. 없으면 다음을 안내하고 종료:
```bash
brew install ccusage   # 또는: npm i -g ccusage
```

## Step 1: 기간 산정

| 인자 | --since | --until |
|------|---------|---------|
| 없음 | 이번 주 월요일 | 오늘 |
| `week` | 7일 전 | 오늘 |
| `month` | 이번 달 1일 | 오늘 |
| `last-week` | 지난주 월요일 | 지난주 일요일 |

## Step 2: 데이터 수집 (병렬, 읽기 전용)

JSON 으로만 받아서 파싱. 표를 직접 만들기 위함.

```bash
# 메인: 일별
ccusage daily --json --breakdown --since YYYYMMDD --until YYYYMMDD

# 모델 mix 확인 용
ccusage daily --json --breakdown --since YYYYMMDD --until YYYYMMDD -q '.daily[] | {date, models: .modelBreakdowns}'

# 인스턴스(프로젝트) 별 비용
ccusage daily --json --instances --since YYYYMMDD --until YYYYMMDD
```

기본 인자(이번 주)면 추가로:
```bash
# 직전 동일 기간 비교 — 지난주 같은 요일들
ccusage daily --json --since <지난주 월요일> --until <지난주 같은 요일>
```

## Step 3: 비정상 신호 감지

다음 중 하나라도 해당하면 ⚠️ 로 표시:

- **캐시 hit 비율 < 50%** — cacheReadTokens / (cacheReadTokens + cacheCreationTokens + inputTokens) 기준. 컨텍스트 재사용 실패.
- **하루 비용 > 7일 평균 × 2** — 비정상 스파이크
- **이번 주 비용 > 지난 주 동기간 × 1.5** — 추세 이탈
- **단일 프로젝트가 비용의 70% 초과** — 한 작업에 쏠림

해당 없으면 "비정상 신호 없음" 으로 명시.

## Step 4: 출력 (고정 포맷)

```markdown
# 💸 AI Spend — 2026-05-23 (이번 주)

## 요약
| 기간 | Cost | 변화 |
|------|------|------|
| 오늘 (지금까지) | $XX.XX | — |
| 이번 주 (월~오늘) | $XXX.XX | 지난주 동기간 대비 **+12%** |
| 일평균 | $XX.XX | — |

## 모델 mix (이번 주)
- Opus 4.7: 68% ($XXX) — 주력
- Sonnet 4.6: 25% ($XX) — 보조
- Haiku 4.5: 7% ($X) — 자동화

## 프로젝트 분포
- `abillity-ai`: 60%
- `claude-cockpit`: 25%
- 기타: 15%

## ⚠️ 비정상 신호
- 5/22 비용 $YY — 평균 대비 2.3배 (어떤 세션이었는지 확인 권장)
- 캐시 hit 41% — 50% 미만. 긴 세션에서 컨텍스트 분할이 일어났을 가능성

(또는 "비정상 신호 없음")

## 액션 후보 (최대 2개)
- [ ] Opus 비중이 68% 인데 단순 작업까지 Opus 면 Sonnet 로 전환 검토
- [ ] cockpit 작업에서 캐시 hit 낮음 → SessionStart 컨텍스트가 너무 크지 않은지 점검
```

## 원칙

- **숫자만 던지지 말 것**: 매 출력에 "그래서 뭐?" 한 줄 (비정상 신호 또는 액션 후보) 포함.
- **5개 이상 액션 금지**: 1-2개로 압축. 1인 창업의 인지 부담 절약.
- **PII 금지**: ccusage 출력에 프로젝트명·경로가 있어도, 외부 공유 시 익명화 (`@standards/management/ai-usage.md`).
- **저장 옵션**: 출력 끝에 "이번 회차를 `~/.claude/briefings/spend-YYYY-MM-DD.md` 에 저장할지" 사용자 승인 한 줄.
