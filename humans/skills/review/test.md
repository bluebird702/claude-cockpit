---
name: review:test
description: 테스트 구조·피라미드·커버리지·품질·효율성 종합 리뷰
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# 테스트 품질 리뷰

> ⚠️ **Standards 준수 필수** — 테스트 판단 기준은 standards를 우선합니다.
> @standards/testing/testing-guidelines.md · @standards/CLAUDE.md

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
- 테스트 가이드라인 문서 위치 (`@standards/testing/testing-guidelines.md`)

## Step 2: 체크리스트 (5개 카테고리)

### A. 테스트 구조
| # | 항목 | 점검 내용 |
|---|------|----------|
| 1 | 파일 조직 | 프로덕션↔테스트 파일 매칭률, 테스트/프로덕션 비율 |
| 2 | 네이밍 | BDD/서술형 패턴, 일관성 |
| 3 | AAA 패턴 | Given-When-Then 준수율, 단일 Act 원칙 |
| 4 | 독립성 | 공유 상태, 테스트 간 의존, 실행 순서 의존성 |

### B. 테스트 피라미드 (권장 70/20/10)
| # | 유형 | 기준 |
|---|------|------|
| 5 | 단위 | 외부 의존 없는 순수 로직 |
| 6 | 통합 | DB, 외부 서비스 등 실제 의존 포함 |
| 7 | E2E | 전체 시스템 통합 |

### C. 커버리지 갭
| # | 항목 | 점검 내용 |
|---|------|----------|
| 8 | 테스트 누락 파일 | 프로덕션 파일 중 대응 테스트 없음 |
| 9 | 도메인 커버리지 | 핵심 비즈니스 로직(domain/service 계층) 파일에 테스트 파일 존재 여부 |
| 10 | 분기·예외 경로 | 주요 도메인 분기(if/when)·예외 경로에 대응 테스트 케이스 존재 여부 (코드 읽기로 추정) |
| 11 | Fixture 중복 | 동일 픽스처 여러 곳에서 재생성 |

### D. 테스트 품질
| # | 항목 | 점검 내용 |
|---|------|----------|
| 12 | Mock 남용 | 과도한 mock, `any()` 남발, verify 누락 |
| 13 | Assertion 품질 | 과다 assertion(>5), 불명확 assertion |
| 14 | 로직 있는 테스트 | 반복문·조건문 포함 테스트 |
| 15 | 플레이키 징후 | Thread.sleep, 시간 의존, 랜덤 없는 시드 |
| 16 | Fixture 재사용 | 공유 fixture 활용률 |

### E. 테스트 효율성/속도 ⚠️ JVM/Gradle 전용 — 비해당 기술스택은 전 항목 N/A
| # | 항목 | 점검 내용 |
|---|------|----------|
| 17 | Testcontainer Singleton | 컨테이너를 테스트 클래스 간 공유하는가 |
| 18 | `@DirtiesContext` | 불필요한 classMode 사용 |
| 19 | `maxParallelForks` | Unit=CPU, Integration=CPU/2 |
| 20 | gradle.properties | parallel, caching, workers.max, configuration-cache |
| 21 | cleanup 전략 | beforeEach/afterEach 중복 |
| 22 | R2DBC 풀 크기 | 병렬 실행 시 커넥션 풀 |
| 23 | Pitest 범위 | DTO, Config, Port 등 제외 여부 |

## Step 3: 에이전트 위임

`backend-development:tdd-orchestrator` 에이전트에게 위임. 프롬프트에 포함:
- Step 1 프로파일링 결과
- Step 2 전체 체크리스트
- standards 문서 경로
- Step 4 출력 형식 지시

**빌드/테스트 실행 금지, 코드 읽기만.**

## 점수 산정 규칙

| 카테고리 | 항목 수 | 배점 |
|---------|---------|------|
| A. 구조 | 4 | 20점 |
| B. 피라미드 | 3 | 15점 |
| C. 커버리지 갭 | 4 | 25점 |
| D. 품질 | 5 | 25점 |
| E. 효율성 | 7 | 15점 |

- **N/A 처리**: 기술스택 비해당 항목은 N/A로 표시하고 해당 카테고리 분모에서 제외
  - JVM/Kotlin/Java 아닌 프로젝트 → E 카테고리(#17~#23) 전체 N/A (E 배점 15점은 가장 가까운 다른 카테고리로 재배분)
  - E가 전부 N/A이면 → A(24점) + B(18점) + C(30점) + D(28점) = 100점으로 재배분
- **커버리지 갭(C)**: 도구 실행 없이 **파일 매칭률**(프로덕션 파일 대비 테스트 파일 존재율)과 **코드 읽기**로 판단
- **카테고리 점수**: `(통과 항목 수 ÷ (카테고리 전체 − N/A)) × 카테고리 배점`
- **종합 점수**: 5개 카테고리 점수 합 (소수점 반올림)

## Step 4: 출력 형식

```markdown
## 테스트 품질 리뷰 결과

### 프로파일
- **기술 스택**: [언어/FW/테스트FW]
- **프로덕션 파일**: X개 (Y줄)
- **테스트 파일**: X개 (Y줄)
- **테스트/프로덕션 비율**: X:1

### 종합 점수: XX/100
| 영역 | 점수 | 상태 |
|------|------|------|
| 구조 | XX | 🟢/🟡/🔴 |
| 피라미드 | XX | 🟢/🟡/🔴 |
| 커버리지 | XX | 🟢/🟡/🔴 |
| 품질 | XX | 🟢/🟡/🔴 |
| 효율성 | XX | 🟢/🟡/🔴 |

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

## Step 5: 드릴다운

- 테스트 없는 코드가 구조 때문에 테스트 불가 → `/review:architecture`
- 느린 테스트 원인이 N+1/쿼리 → `/review:performance`
- 테스트 가능한 코드 품질 점검 → `/review:code`
