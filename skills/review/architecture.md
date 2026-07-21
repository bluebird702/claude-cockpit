---
name: review:architecture
description: 아키텍처 구조·의존성 방향·DDD 경계·계층 분리 심층 리뷰
type: slash-command
category: review
follows-brain:
  - brain/CLAUDE.md
  - brain/coding/coding-guidelines.md
  - brain/hard-won-conventions.md
enforcement: required
---

> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

# 아키텍처 리뷰

> ⚠️ **Brain 원칙 준수 필수** — 아키텍처 판단 기준은 standards를 우선합니다.
> @brain/CLAUDE.md · @brain/coding/coding-guidelines.md · @brain/hard-won-conventions.md(§아키텍처·회복탄력성 — 일반 표준과 긴장하면 이쪽 우선)

프로젝트의 구조적 건전성을 심층 분석합니다. 계층 분리, 의존성 방향, DDD 경계, 모듈 응집도를 점검합니다.

$ARGUMENTS
- `deep` — 심층 모드 (문제 코드 + 개선 방향 포함)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체 요약 모드
- 예: `/review:architecture`, `/review:architecture deep platform/account`

## Step 1: 컨텍스트 파악

- 언어, 프레임워크, 빌드 도구
- 선언된 아키텍처 스타일 (Layered / Hexagonal / Clean / DDD / Feature-based)
- 모듈·패키지 구조
- brain 문서 경로

## Step 2: 체크리스트 (16항목)

| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | 계층 분리 | presentation / application / domain / infrastructure 경계 명확성 | evidence | medium |
| 2 | 의존성 방향 | 외부 → 내부 (도메인은 어떤 것에도 의존하지 않는가) | evidence | high |
| 3 | 의존성 역전 | 도메인이 인프라 추상화(포트)에 의존하는가 | evidence | medium |
| 4 | 순환 의존 | 패키지/모듈 간 순환 참조 존재 여부 (import 사이클 탐지, 측정) | objective | high |
| 5 | Bounded Context | DDD 경계 설정, 컨텍스트 간 명확한 계약 | evidence | medium |
| 6 | Aggregate 경계 | 트랜잭션 단위와 일치하는가, 루트를 통한 접근 | evidence | high |
| 7 | 포트/어댑터 | Hexagonal 적용 시 포트 인터페이스 위치, 어댑터 구현 분리 | evidence | medium |
| 8 | 안티 부패 계층 | 외부 시스템 연동 시 도메인 보호 레이어 존재 여부 | evidence | medium |
| 9 | 프레임워크 누수 | 도메인 계층 패키지에 Spring/JPA/HTTP 등 인프라 어노테이션 혼입 (grep hit, 측정) | objective | medium |
| 10 | 모듈 응집도 | 같은 이유로 변경되는 코드가 같은 모듈에 있는가 | evidence | medium |
| 11 | 인터페이스 분리 | 비대한 인터페이스, 사용처별 역할 분리 | evidence | low |
| 12 | 트랜잭션 경계 | 애플리케이션 서비스에서만 시작, 도메인/인프라 혼재 금지 | evidence | high |
| 13 | 이벤트 vs 직접 호출 | 도메인 이벤트 발행 위치, 사이드이펙트 커플링 | advisory | low |
| 14 | 공유 커널 | 모듈 간 공유 모델 과다, 중복 vs 결합 트레이드오프 | advisory | low |
| 15 | 패키지 구조 일관성 | Feature vs Layer 혼용, 네이밍 규칙 | evidence | low |
| 16 | 설정 외부화 | 환경별 설정, 비밀 관리, 프로파일 분리 | evidence | medium |

> ★ **언어 불문 계층 규칙**: `*/domain/*`·`*-domain` 경로의 파일이 웹/ORM/프레임워크를 **import**(Spring/JPA·FastAPI·SQLAlchemy·Django 등)하면 의존성 방향(#2)·프레임워크 누수(#9) 위반 — 어노테이션뿐 아니라 **import 문**(Python·Kotlin·TS 공통).

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-architecture`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 체크리스트 16항목 (그대로 전달)
- brain 문서 경로
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
## 아키텍처 리뷰 결과

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

### 강점 (2-3개)
- ...

### 문제 (최대 5개)
| # | 항목 | 파일:줄 | 설명 |

### 한 줄 요약
```

**심층 모드:** 요약 모드 + 각 문제에 대해 아래 블록 추가
```markdown
> *위치*: [파일:줄]
> *현재*: (문제 코드 스니펫)
> *문제*: (왜 체크리스트를 위반하는지)
> *개선*: (개선 코드 또는 방향)
```

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(architecture). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 코드 품질 문제 동반 → `/review:code`
- 의존성 방향 문제가 라이브러리 레벨 → `/review:deps`
- 전체 점검 → `/review:all`
