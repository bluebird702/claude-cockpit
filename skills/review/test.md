---
name: review:test
description: 테스트 구조·피라미드·커버리지·품질·효율성 종합 리뷰
type: slash-command
category: review
follows-brain:
  - brain/CLAUDE.md
  - brain/testing/testing-guidelines.md
enforcement: required
---

> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

# 테스트 품질 리뷰

> ⚠️ **Brain 원칙 준수 필수** — 테스트 판단 기준은 standards를 우선합니다.
> @brain/testing/testing-guidelines.md · @brain/CLAUDE.md

테스트 코드의 구조, 피라미드 균형, 커버리지 갭, 품질, 실행 효율성을 종합 점검합니다.

$ARGUMENTS
- `deep` — 심층 모드 (문제 코드 + 개선안)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체
- 예: `/review:test`, `/review:test deep platform/account`

## Step 1: 프로젝트 프로파일링

자동 감지:
- 언어, 빌드 도구, 테스트 프레임워크
- 아키텍처 패턴 (디렉토리 구조)
- 커버리지 도구 (Jacoco, Istanbul, Coverage.py 등)
- 테스트 가이드라인 문서 위치 (`@brain/testing/testing-guidelines.md`)

## Step 2: 체크리스트 (5개 카테고리)

### A. 테스트 구조
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | 파일 조직 | 프로덕션↔테스트 파일 매칭률, 테스트/프로덕션 비율 (측정) | objective | medium |
| 2 | 네이밍 | BDD/서술형 패턴, 일관성 | evidence | low |
| 3 | AAA 패턴 | Given-When-Then 준수율, 단일 Act 원칙 | evidence | medium |
| 4 | 독립성 | 공유 상태, 테스트 간 의존, 실행 순서 의존성 | evidence | high |

### B. 테스트 피라미드 (권장 70/20/10)
| # | 유형 | 기준 | Tier | Sev |
|---|------|------|------|-----|
| 5 | 단위 | 외부 의존 없는 순수 로직 (분류·비율 측정) | objective | low |
| 6 | 통합 | DB, 외부 서비스 등 실제 의존 포함 (분류·비율 측정) | objective | low |
| 7 | E2E | 전체 시스템 통합 (분류·비율 측정) | objective | low |

### C. 커버리지 갭
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 8 | 테스트 누락 파일 | 프로덕션 파일 중 대응 테스트 없음 (파일 매칭률 측정) | objective | medium |
| 9 | 도메인 커버리지 | 핵심 비즈니스 로직(domain/service 계층) 파일 커버리지 < 임계 (측정) | objective | medium |
| 10 | 분기·예외 경로 | 주요 도메인 분기(if/when)·예외 경로에 대응 테스트 케이스 존재 여부 (코드 읽기로 추정) | evidence | medium |
| 11 | Fixture 중복 | 동일 픽스처 여러 곳에서 재생성 | evidence | low |

### D. 테스트 품질
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 12 | Mock 남용 | 도메인 Port mock > 3개 / `any()` 남발 / verify 누락 (측정) | objective | medium |
| 13 | Assertion 품질 | 과다 assertion > 5 (측정), 불명확 assertion | objective | low |
| 14 | 로직 있는 테스트 | 반복문·조건문 포함 테스트 (grep hit, 측정) | objective | medium |
| 15 | 플레이키 징후 | Thread.sleep, 시간 의존, 랜덤 없는 시드 (grep hit, 측정) | objective | high |
| 16 | Fixture 재사용 | 공유 fixture 활용률 | advisory | low |

### E. 테스트 효율성/속도 ⚠️ JVM/Gradle 전용 — 비해당 기술스택은 전 항목 N/A
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 17 | Testcontainer Singleton | 컨테이너를 테스트 클래스 간 공유하는가 (grep hit, 측정) | objective | low |
| 18 | `@DirtiesContext` | 불필요한 classMode 사용 (grep hit, 측정) | objective | low |
| 19 | `maxParallelForks` | Unit=CPU, Integration=CPU/2 (설정값 측정) | objective | low |
| 20 | gradle.properties | parallel, caching, workers.max, configuration-cache (설정값 측정) | objective | low |
| 21 | cleanup 전략 | beforeEach/afterEach 중복 | evidence | low |
| 22 | R2DBC 풀 크기 | 병렬 실행 시 커넥션 풀 (설정값 측정) | objective | low |
| 23 | Pitest 범위 | DTO, Config, Port 등 제외 여부 (설정값 측정) | objective | low |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

### 프로젝트 표준 규칙 (@brain/testing/testing-guidelines.md — **brain 우선**)

testing-guidelines 의 원칙(Foundations)에만 있는 고유 규칙. 위 항목과 겹치면 brain 채택.

| # | 항목 | 점검 내용 (판정 기준) | Tier | Sev |
|---|------|----------------------|------|-----|
| 24 | Tautological 금지 | `verifyComplete()`·"예외 없음"만 확인하고 **실제 행위(반환·상태·마스킹) 단언이 없는** 테스트 = 위반. "로직을 지워도 통과"하면 무의미 | evidence | high |
| 25 | 행위 검증(구현 아님) | 내부 호출 순서·private 상호작용을 단언하는 취약 테스트 = 위반. 관찰 가능한 결과만 단언 | evidence | medium |
| 26 | 결정성(F.I.R.S.T) | `Instant.now()`·`LocalDate.now()`·`Math.random()`·실제 `Thread.sleep` 직접 사용 = 위반(주입/고정 clock). grep hit | objective | high |
| 27 | 커버리지 게이밍 | `*CoverageTest` 네이밍, getter·상수만 검증하는 테스트 = 위반 (grep hit) | objective | medium |
| 28 | 중복 스펙 금지 | 동일 대상을 여러 스펙에서 거의 같은 시나리오로 반복 검증 = 위반(Fixture/Builder로 통합) | evidence | low |
| 29 | 변이 점수(Pitest) | 도메인 mutation score < 임계(권장 90%) = 위반. Pitest 리포트 있을 때만 판정 | objective | medium |

> #26·#27·#29 는 objective(grep/측정), #24·#25·#28 은 evidence. Pitest·커버리지 도구 없으면 해당 항목 `n/a`.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-test`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 1 프로파일링 결과
- Step 2 전체 체크리스트
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

```markdown
## 테스트 품질 리뷰 결과

### 프로파일
- **기술 스택**: [언어/FW/테스트FW]
- **프로덕션 파일**: X개 (Y줄)
- **테스트 파일**: X개 (Y줄)
- **테스트/프로덕션 비율**: X:1

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

### 테스트 피라미드
| 유형 | 파일 수 | 비율 | 권장 | 상태 |

### 커버리지 갭 (Top 10)
| 파일 | 중요도 | 사유 |

### 발견된 문제 (우선순위순)
#### High / Medium / Low Priority
(심층 모드: 각 항목에 파일:줄 + 현재/문제/개선 블록)

### 속도 최적화 현황
### 개선 로드맵 (Quick wins → 구조 개선)
```

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(test). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 테스트 없는 코드가 구조 때문에 테스트 불가 → `/review:architecture`
- 느린 테스트 원인이 N+1/쿼리 → `/review:performance`
- 테스트 가능한 코드 품질 점검 → `/review:code`
