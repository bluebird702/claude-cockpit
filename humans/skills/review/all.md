---
name: review:all
description: 프로젝트 품질을 6개 영역(아키텍처/코드/테스트/보안/성능/의존성)으로 병렬 분석
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# 프로젝트 리뷰 (오케스트레이터)

> ⚠️ **Standards 준수 필수** — 모든 sub-skill의 판단 기준은 standards를 우선합니다.
> @standards/CLAUDE.md · @standards/coding/coding-guidelines.md · @standards/testing/testing-guidelines.md

6개 sub-skill을 병렬 호출하여 프로젝트 품질 스냅샷을 생성합니다. 각 영역의 상세 기준과 체크리스트는 **sub-skill 파일이 단일 출처(SSOT)** 이며, 이 오케스트레이터는 얇은 래퍼입니다.

$ARGUMENTS
- `deep` — 각 sub-skill을 심층 모드로 실행 (코드 예시 + 개선안 포함)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체를 요약 모드로 분석
- 예: `/review:all`, `/review:all account`, `/review:all deep platform/account`

## Step 0: 프로젝트 컨텍스트 파악

분석 전에 아래를 한 번만 파악하고, **모든 sub-skill 호출에 동일한 한 줄 요약으로 전달**합니다.
- 언어, 프레임워크, 빌드 도구
- 디렉토리 구조 및 아키텍처 패턴
- standards 문서 경로 (`docs/standards/` 또는 cockpit의 `@standards/*`)

## Step 1: 모드 판별

`$ARGUMENTS`에 `deep` 포함 → **심층 모드** / 아니면 **요약 모드**.

## Step 2: 6개 sub-skill 병렬 호출

**반드시 하나의 메시지에서 6개 Agent tool을 동시에 호출**합니다. 각 sub-skill의 **Step 2 체크리스트와 Step 4 출력 형식**을 해당 sub-skill 파일에서 그대로 사용합니다 (중복 정의 금지).

| # | 영역 | Sub-skill | 위임 에이전트 |
|---|------|-----------|--------------|
| 1 | 아키텍처 | @skills/review/architecture.md | `code-review-ai:architect-review` |
| 2 | 코드 품질 | @skills/review/code.md | `pr-review-toolkit:code-reviewer` |
| 3 | 테스트 | @skills/review/test.md | `backend-development:tdd-orchestrator` |
| 4 | 보안 | @skills/review/security.md | `pr-review-toolkit:silent-failure-hunter` |
| 5 | 성능·관측성 | @skills/review/performance.md | `backend-development:backend-architect` |
| 6 | 의존성 | @skills/review/deps.md | `backend-development:backend-architect` |

### 공통 에이전트 지시

- **빌드/테스트 실행 금지** — 코드 읽기만
- **결과는 1000자 이내** (요약 모드) / **1800자 이내** (심층 모드)
- sub-skill 파일의 Step 2 체크리스트를 기준으로 판단
- sub-skill 파일의 Step 4 출력 형식만 반환 (다른 설명 금지)

### 분석 깊이 가이드
- 소규모 (≤30 파일): 전체 분석
- 중규모 (30~100): 도메인/비즈니스 로직 전체 + 인프라 샘플링
- 대규모 (>100): 구조 파악 후 모듈별 대표 파일 심층

## 점수 산정 규칙

**종합 점수 = 6개 영역 가중 평균**

| 영역 | 가중치 | 근거 |
|------|--------|------|
| 보안 | 25% | 취약점은 즉시 영향 |
| 코드 품질 | 20% | 유지보수성·가독성 |
| 아키텍처 | 20% | 구조적 건전성 |
| 테스트 | 15% | 변경 안전망 |
| 성능·관측성 | 15% | 운영 가시성 |
| 의존성 | 10% | 외부 리스크 |

- **계산**: `종합 점수 = 보안×0.25 + 코드×0.20 + 아키텍처×0.20 + 테스트×0.15 + 성능×0.15 + 의존성×0.10` (소수점 반올림)
- **각 영역 점수**: 해당 sub-skill의 점수 산정 규칙을 따름 (보안은 감점제, 나머지는 통과율 기반)
- **상태**: 🟢 80+ / 🟡 60-79 / 🔴 <60 (영역별 및 종합 모두 동일 기준)

## Step 3: 통합 보고서 출력

6개 결과를 수집한 뒤 아래 형식으로 **직접** 작성합니다. 취합 에이전트를 추가로 실행하지 않습니다.

```markdown
# 프로젝트 리뷰 결과

**프로젝트**: [이름] | **범위**: [경로] | **스택**: [언어/FW] | **모드**: 요약/심층

## 종합 점수: XX/100
> 가중 평균: 보안(25%) + 코드(20%) + 아키텍처(20%) + 테스트(15%) + 성능(15%) + 의존성(10%)

| 영역 | 점수 | 상태 | 핵심 발견 |
|------|------|------|----------|
| 아키텍처 | XX | 🟢/🟡/🔴 | [1줄] |
| 코드 품질 | XX | 🟢/🟡/🔴 | [1줄] |
| 테스트 | XX | 🟢/🟡/🔴 | [1줄] |
| 보안 | XX | 🟢/🟡/🔴 | [1줄] |
| 성능·관측성 | XX | 🟢/🟡/🔴 | [1줄] |
| 의존성 | XX | 🟢/🟡/🔴 | [1줄] |

상태: 🟢 80+ / 🟡 60-79 / 🔴 <60

## 영역별 요약
### 1. 아키텍처 / 2. 코드 / 3. 테스트 / 4. 보안 / 5. 성능 / 6. 의존성
(각 sub-skill 결과를 3~5줄로 압축)

## Top 5 액션 아이템
| # | 영역 | 문제 | 영향도 | 권장 조치 |

## 드릴다운 추천
- 점수 낮은 영역 → `/review:<영역>` 단독 실행 안내
- 예: 테스트 65점 → `/review:test deep platform/account`
```
