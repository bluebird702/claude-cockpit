---
name: dev:analyze-tests
description: 테스트 구조·커버리지·피라미드·품질·효율성 종합 분석
type: slash-command
category: dev
follows-standards:
  - standards/CLAUDE.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# 테스트 품질 분석

> ⚠️ **Standards 준수 필수** — 테스트 판단 기준은 아래 문서를 우선합니다.
> @standards/testing/testing-guidelines.md · @standards/CLAUDE.md

프로젝트의 테스트 코드를 종합 분석하여 구조, 커버리지, 품질, 효율성을 점검합니다.

$ARGUMENTS
- 인자가 **서비스명 또는 경로**이면 → 해당 범위만 분석
- 인자가 없으면 → 프로젝트 전체 테스트 분석

## 절차

### 1. 프로젝트 프로파일링

분석 전에 자동 감지합니다:
- 언어, 빌드 도구, 테스트 프레임워크
- 아키텍처 패턴 (디렉토리 구조 기반)
- 커버리지 도구 설정 (있는 경우)
- 테스트 가이드라인 문서 위치 (`@standards/testing/testing-guidelines.md` 우선)

### 2. 에이전트 위임

프로파일링 결과와 분석 대상 경로를 포함하여 `backend-development:tdd-orchestrator` 에이전트에게 아래 3~6단계 분석을 위임합니다.

### 3. 테스트 구조 분석

| 항목 | 분석 내용 |
|------|----------|
| 파일 조직 | 프로덕션↔테스트 파일 매칭률, 테스트/프로덕션 비율 |
| 네이밍 | 테스트 메서드 네이밍 패턴 (BDD/서술형), 일관성 |
| 테스트 패턴 | Given-When-Then(AAA) 준수율, 단일 Act 원칙 |
| 독립성 | 공유 상태, 테스트 간 의존성, 실행 순서 의존 |

### 4. 테스트 피라미드 분석

- **단위 테스트**: 외부 의존성 없이 순수 로직
- **통합 테스트**: DB, 외부 서비스 등 실제 의존성
- **E2E 테스트**: 전체 시스템 통합

권장 비율: 70% Unit / 20% Integration / 10% E2E

### 5. 커버리지 갭 분석

**목표: 라인 커버리지 90%+, 도메인 계층 95%+**

- 테스트가 없는 프로덕션 파일 식별
- 핵심 비즈니스 로직(도메인 계층) 테스트 존재 여부
- 분기 커버리지 미커버 지점
- Fixture 중복 여부

### 6. 테스트 품질 점검

| 항목 | 점검 내용 |
|------|----------|
| Mock 사용 | 과도한 mock, any() 남용, verify 누락 |
| Assertion | 과다 assertion (>5개), 불명확한 assertion |
| Fixture | 중복 생성, 공유 fixture 활용률 |
| 안티패턴 | 로직이 있는 테스트, sleep 사용, 플레이키 징후 |

### 7. 테스트 효율성 및 속도

| 항목 | 점검 내용 |
|------|----------|
| Testcontainer Singleton | 컨테이너가 테스트 클래스 간 공유되는지 |
| `@DirtiesContext` | 불필요한 classMode 사용 여부 |
| `maxParallelForks` | Unit (CPU 수), Integration (CPU/2) |
| `gradle.properties` | parallel, caching, workers.max, configuration-cache |
| cleanup 전략 | beforeEach / afterEach 중복 |
| Thread.sleep / delay | 하드코딩된 대기 |
| R2DBC 커넥션 풀 | 병렬 실행 시 풀 크기 |
| Pitest 범위 | DTO, Config, Port 등 제외 여부 |

## 출력 형식

```markdown
## 테스트 품질 분석 결과

### 프로파일
- **기술 스택**: [언어/프레임워크/테스트FW]
- **프로덕션 파일**: X개 (Y줄)
- **테스트 파일**: X개 (Y줄)
- **테스트/프로덕션 비율**: X:1

### 종합 점수: XX/100
| 영역 | 점수 | 상태 |
|------|------|------|
| 구조 | XX/100 | 🟢/🟡/🔴 |
| 피라미드 | XX/100 | 🟢/🟡/🔴 |
| 커버리지 | XX/100 | 🟢/🟡/🔴 |
| 품질 | XX/100 | 🟢/🟡/🔴 |
| 효율성 | XX/100 | 🟢/🟡/🔴 |

### 테스트 피라미드
| 유형 | 파일 수 | 비율 | 권장 | 상태 |

### 커버리지 갭
| 파일 | 중요도 | 사유 |

### 발견된 문제 (우선순위순)
#### High / Medium / Low Priority

### 속도 최적화 현황
### 개선 로드맵
```
