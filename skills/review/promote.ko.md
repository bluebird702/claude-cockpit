---
name: review:promote
description: 원장·골든셋의 반복 발견을 표준·픽스처·체크리스트 수정안으로 승격(초안화). 적용은 사람 승인.
type: slash-command
category: review
follows-standards:
  - brain/CLAUDE.md
  - brain/hard-won-conventions.md
enforcement: required
---

# 승격 (Promote) — 플라이휠 ④

> ⚠️ **Standards 준수 필수** — @brain/CLAUDE.md · @brain/hard-won-conventions.md
> **사람 게이트 필수** — 이 스킬은 승격 후보를 **초안(draft)** 으로만 만든다.
> enforced 표준(`brain/**`)에 **자동 병합 금지**. 무인 자기수정 금지.

`/review:all`이 쌓은 원장·골든셋에서 **반복되는 발견을 영구 자산으로 승격**한다. 즉 일회성 발견을
표준 규칙·골든 픽스처·체크리스트 항목으로 **박아** 재발 불가능하게 만든다. `all`이 측정(①)이면 이건 정제(④).

> **cockpit에서 실행**한다 — 승격 대상(표준·픽스처)이 cockpit에 있기 때문. 프로젝트 원장은 `--ledger` 로 가리킨다.

## $ARGUMENTS
- 인자 없음 → 원장·골든셋에서 자동 후보 수집
- `--ledger <경로>` — 프로젝트 원장(`docs/review/ledger.jsonl`) 추가 (반복 가능, cross-project 신호)
- `--from-golden` — 골든셋 `eval.py`를 돌려 miss/FP를 후보로
- `"<발견 설명>"` — 명시 승격(실사고·High+ 는 1회로 즉시 자격)
- `--apply <번호…>` — **승인 후** 해당 번호만 실제 적용 (기본은 초안까지만)

## Step 0: 컨텍스트
- 표준 경로 `brain/`, 골든셋 `system/review-fixtures/`, `RULESET_VERSION` 읽기
- 원장 소스 확정: cockpit `docs/review/ledger.jsonl`(있으면) + `--ledger` 인자들
- **원장이 없으면 경고**하고 명시 인자·`--from-golden` 경로로만 진행 (추측 금지)

## Step 1: 후보 수집 (게이트 트리거)
아래 **자격 하나 이상**을 만족하는 것만 후보:
| 소스 | 자격 트리거 |
|------|------------|
| 원장 | 같은 안정 키가 **3개↑ 스냅샷 연속 `open`** |
| 원장(다중) | **2개↑ 프로젝트** 원장에 같은 키 등장 |
| 골든셋 | `eval.py`의 `misses`(리뷰어 갭) / `false_positives`(과탐) |
| 명시 | 실사고·**High+** (1회로 즉시) |

> 자격 미달(1~2회 open, 저severity 일회성)은 **후보 아님** — 게이트가 bloat를 막는다.

## Step 2: 중복 제거 (재승격 금지)
각 후보를 기존 자산과 대조해 **이미 있으면 skip**:
- `brain/**`·`hard-won-conventions.md`에 해당 규칙이 이미 있나
- `fixtures/expected.jsonl`에 해당 결함 유형 케이스가 이미 있나
- 있으면 "이미 반영됨"으로 표시하고 제외

## Step 3: 타겟 라우팅 (발견 → 자산)
| 후보 성격 | 승격 대상 |
|-----------|----------|
| 일반화 가능한 반복 결함 | `brain/*` 규칙 강화 **+ 골든 픽스처 + expected.jsonl 줄** |
| 실사고발·비자명 | `hard-won-conventions.md` (**provenance 포함**) |
| 골든셋 miss (리뷰어 갭) | sub-skill **체크리스트 항목** + 골든 케이스 |
| 골든셋 FP (과탐) | **precision 가드** 픽스처 |
| 오케스트레이터 행동 결함 | `all.md` 공통 지시 |

## Step 4: 초안 생성
후보마다 **실제 수정안**을 만든다 (설명이 아니라 diff/파일):
- 표준/체크리스트: 해당 `.md`의 최소 diff
- 픽스처: `fixtures/cases/**` 파일 + `expected.jsonl` 한 줄 (**정답 누설 주석 금지** — 라벨은 expected.jsonl에만)
- hard-won: provenance 한 줄 포함 엔트리

## Step 5: 안전 검사 (자동 승격 차단 게이트)
- **오버피팅 가드**: 제안 규칙이 **픽스처 1개만** 매칭 → "너무 구체적" 경고, 일반화 요구
- **거짓양성 시뮬**: 새 규칙을 기존 **clean 픽스처들**에 대입 → 하나라도 걸리면 반려
- **submodule 영향**: `brain/` 변경은 **전 프로젝트 배포**임을 명시
- **fire-rate 프로젝션**: 이 규칙이 과거 원장에서 걸렸을 발견 수 추정 → 0이면 보류

## Step 6: 게이트 출력 (사람 승인)
- **main·enforced 표준에 직접 쓰지 않는다.** `chore/promote-<날짜>` 브랜치에 draft 커밋(또는 미커밋 diff 제시).
- 아래 **승인 표**를 출력하고 멈춘다:

```markdown
## 승격 제안 (N건)
| # | 발견 (근거) | 대상 | 위험 | 안전검사 | 초안 |
|---|------------|------|------|---------|------|
| 1 | perf race miss (골든 miss) | performance.md 체크 + 픽스처 | 낮음 | ✅ | [diff] |
승인: `/review:promote --apply 1,3` 처럼 번호 지정 (미승인분은 폐기)
```

- `--apply <번호>` 재실행 시: 승인분만 적용 → **`RULESET_VERSION` bump**(골든셋 관련 시) →
  **`eval.py` 재실행으로 퇴행 0 확인** → 커밋. 퇴행 있으면 롤백하고 보고.

## 원칙 (요약)
- **수고는 자동**(수집·진단·초안), **판단은 사람**(무엇을 enforced로 할지).
- `all`은 이 스킬을 **호출하지 않는다** — 넛지만 남기고, 실행은 사람이 결정.
- 관련: cockpit 레포 `docs/process/cockpit-flywheel.md` · `all.md`(원장) · `fixtures/README.md`(골든셋)
