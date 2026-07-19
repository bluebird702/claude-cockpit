---
name: review:code
description: SOLID·가독성·네이밍·안티패턴 등 코드 품질 심층 리뷰
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
  - standards/hard-won-conventions.md
enforcement: required
---

# 코드 품질 리뷰

> ⚠️ **Standards 준수 필수** — 코드 판단 기준은 standards를 우선합니다.
> @brain/CLAUDE.md · @brain/coding/coding-guidelines.md · @brain/hard-won-conventions.md(일반 표준과 긴장하면 이쪽 우선)

SOLID 원칙, 가독성, 안티패턴, standards 위반 여부를 심층 점검합니다.

$ARGUMENTS
- `deep` — 심층 모드 (문제 코드 + 개선 코드 포함)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체 요약
- 예: `/review:code`, `/review:code deep src/account`

## Step 1: 컨텍스트 파악

- 언어, 프레임워크, 스타일 가이드 (ktlint, eslint, rubocop 등)
- standards 문서의 코딩 규칙
- 프로젝트의 지배적 패러다임 (OOP / FP / 하이브리드)

## Step 2: 체크리스트 (20항목)

### SOLID (5)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | SRP | 함수/클래스가 단일 변경 이유를 가지는가 | evidence | medium |
| 2 | OCP | 새 동작 추가 시 기존 코드 수정 없이 확장 가능한가 | evidence | medium |
| 3 | LSP | 하위 타입이 상위 타입 계약을 깨지 않는가 | evidence | high |
| 4 | ISP | 클라이언트가 사용하지 않는 메서드에 의존하지 않는가 | evidence | low |
| 5 | DIP | 고수준 모듈이 추상에 의존하는가 (구체 타입 직접 의존 금지) | evidence | medium |

### 가독성·네이밍 (5)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 6 | 의도 드러내는 이름 | 축약·모호 이름(`data`, `mgr`, `tmp`), Hungarian 표기 | evidence | low |
| 7 | 함수 길이 | 함수 LOC > 50 (절대선). **CC ≤ cc_max 이면 advisory**(길이는 복잡도의 프록시 — 아래 ★) | objective\* | low |
| 8 | 순환 복잡도 | 메서드당 CC > cc_max (기본 10 · 측정). **복잡도의 1급 지표** | objective | medium |
| 9 | 파라미터 개수 | 파라미터 ≥ 6. **CC ≤ cc_max 이면 advisory**(분기 없는 매핑·주입 생성자는 결함 아님) | objective\* | low |
| 10 | 깊은 중첩 | 중첩 깊이 ≥ 4 (측정), 조기 반환·가드 절로 해소 | objective | medium |

> ★ **복잡도는 CC 로 잰다 — 길이·파라미터는 CC 종속 (2026-07-19 승격)**: 함수 LOC(#7)·
> 파라미터 수(#9)는 **복잡도의 프록시**이지 복잡도 자체가 아니다. CC 가 임계 이내인데 길기만
> 한 함수(플랫한 문자열 빌더 CC 8·190줄, 컬럼 매핑 CC 1·파라미터 7개)는 읽기 어렵지 않다 —
> 이때 #7·#9 는 **advisory**(점수 제외)로 강등하고, 실제 복잡한 함수는 #8(CC)이 이미 잡는다.
> **이중 계상 방지 + 큰-단순 코드 편향 제거**. cc_max(기본 5, 없으면 10)는 RULESET override 가능.
> provenance: abillity-ai 실리뷰(2026-07-19)에서 CC>10 함수 7개가 code 영역을 1점으로 눌러
> "리팩터 없이는 못 넘는 false 과락" 발생 — 크기 정규화 부재의 증상(§all.md 점수 규칙 참조).

### 안티패턴 (10)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 11 | 중복 코드(DRY) | 유사 블록 3회 이상 (측정) | objective | medium |
| 12 | 매직 넘버/문자열 | 리터럴 상수 미추출 (grep hit, 측정) | objective | low |
| 13 | Boolean 파라미터 | 플래그 인자 → enum/메서드 분리 (grep hit, 측정) | objective | low |
| 14 | 가변성 남용 | var / mutable 컬렉션 기본 사용 (불변 우선 원칙) | evidence | low |
| 15 | null/Optional 남용 | `!!`, `get()` 직접 호출, Optional 체이닝 누락 (grep hit, 측정) | objective | high |
| 16 | 예외 삼키기 | `catch {}`, `catch { log }` 후 복구 없음 | evidence | high |
| 17 | 죽은 코드 | 미사용 import, 미호출 private, 주석된 코드 (lint hit, 측정) | objective | low |
| 18 | 주석 부채 | 코드와 어긋난 주석, 자명한 주석, TODO 방치 | advisory | low |
| 19 | 조기 추상화 | 1회 사용되는 인터페이스·제네릭 | advisory | low |
| 20 | God Object | 클래스 LOC 수백 / 필드 수십 개 (측정), 공용 유틸 덤프 | objective | medium |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

### 프로젝트 표준 규칙 (@brain/coding/coding-guidelines.md — **standards 우선**)

standards 에만 있는 고유 규칙. 아래 표의 임계값이 위 일반 항목과 충돌하면 **standards 채택**
(예: #8 CC≤10 → standards `CC<5` 로 덮어씀). 각 위반은 반드시 발견으로 방출한다.

| # | 항목 | 점검 내용 (판정 기준) | Tier | Sev |
|---|------|----------------------|------|-----|
| 21 | 인자 개행 규칙 | 인자 **2개 이상**인 호출/생성은 named argument + **인자별 개행** 필수. 한 줄 다중 인자·positional 다중 인자는 위반 (grep: `(\w+\s*,\s*\w+.*)` 한 줄 호출) | objective | low |
| 22 | Cyclomatic Complexity | **CC < 5** (standards, #8보다 엄격 — 이 값 우선). when/if 분기 최소화 | objective | medium |
| 23 | Null 체크 스타일 | `if (x != null)` 대신 scope function(`x?.let`)·Elvis(`?:`). `if (x != null)` grep hit = 위반 | objective | low |
| 24 | 검증 로직 위치 | 도메인 검증이 UseCase/Service에 분산되지 않고 **엔티티/VO에 캡슐화**됐는가 (UseCase에 `if(...)throw` 반복 = 위반) | evidence | medium |
| 25 | Controller 반환 타입 | 200 OK는 도메인/DTO **직접 반환**, `ResponseEntity.ok()` 금지 (201/204만 ResponseEntity). grep `ResponseEntity.ok` = 위반 | objective | low |
| 26 | UseCase 명명 | UseCase 인터페이스 함수명이 `execute()` 아닌 **실제 행동 이름**인가 (grep `fun execute(` in usecase = 위반) | objective | low |
| 27 | Expression-body 선호 | 단순 위임 함수는 expression-body(`fun f() = ...`) 선호 | advisory | low |

> 이 표는 언어별(Kotlin/Python) idiom 을 포함하므로 **비해당 언어 항목은 `n/a`**. Python 프로젝트면 #21(인자 개행)·#22·#23(Elvis→`or`/`?.`) 은 유효, #25·#26(Kotlin Controller/UseCase) 은 n/a.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-code`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 체크리스트 20항목
- standards 문서의 규칙 우선 적용 지시
- Step 4 출력 형식 지시

**빌드/테스트 실행 금지, 코드 읽기만.**

## 점수 산정 (all.md 가 계산)

이 스킬은 점수를 직접 매기지 않는다. 체크리스트 위반을 **findings 블록**으로 방출하고,
종합/영역 점수는 오케스트레이터(all.md)가 `100 − Σ(severity_penalty × confidence)` 로
결정적으로 계산한다.

- **objective 항목**: Step 0.5 METRICS 수치로 verdict 자동 결정 (LLM 재판정 금지)
- **evidence 항목**: file:line 증거가 있을 때만 발견으로 기록 (confidence 부여, 적대적 검증 대상)
- **advisory 항목**: 서술로만 노출, 점수에서 제외
- **N/A**: 언어·스택상 비해당 항목은 `n/a` (감점 아님, 재현성 위해 노출)

## Step 4: 출력 형식

**요약 모드:**
```markdown
## 코드 품질 리뷰 결과

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

### 강점 (2-3개)

### 문제 (최대 5개, 심각도순)
| # | 카테고리 | 파일:줄 | 설명 |

### 한 줄 요약
```

**심층 모드:** 요약 + 각 문제마다 아래 블록
```markdown
> *위치*: [파일:줄]
> *카테고리*: [SRP / 가독성 / 중복 / ...]
> *현재*: (문제 코드)
> *문제*: (원칙/규칙 위반 이유)
> *개선*: (개선 코드)
```

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(code). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 테스트가 없어 리팩토링 불가 → `/review:test`
- 구조적 문제(계층 혼재) → `/review:architecture`
- 예외 처리 관련 문제 다수 → `/review:security`
