---
name: review:performance
description: 성능 병목·쿼리·캐싱·동시성·관측성 심층 리뷰
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
enforcement: required
---

# 성능·관측성 리뷰

> ⚠️ **Standards 준수 필수** — 성능/관측성 판단 기준은 standards를 우선합니다.
> @standards/coding/coding-guidelines.md · @standards/CLAUDE.md

프로젝트의 성능 병목, 쿼리 패턴, 캐싱 전략, 동시성 처리, 관측성(로깅·메트릭·추적) 수준을 심층 점검합니다.

$ARGUMENTS
- `deep` — 심층 모드 (문제 코드 + 개선 코드)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체 요약
- 예: `/review:performance`, `/review:performance deep src/order`

## Step 1: 컨텍스트 파악

- 언어, 프레임워크, 런타임 (JVM, Node, Go 등)
- 데이터 접근 계층 (JPA, R2DBC, Prisma, ActiveRecord, 직접 SQL)
- 런타임 모델 (동기 블로킹 / 비동기 / 리액티브)
- 관측성 스택 (Micrometer, OpenTelemetry, Sentry, Datadog)

## Step 2: 체크리스트 (5개 카테고리)

### A. 데이터베이스·쿼리 (6)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | N+1 쿼리 | 연관 엔티티 반복 조회, `fetch = LAZY` + 루프 내 접근 | evidence | high |
| 2 | 페치 전략 | 과도한 eager fetch, 불필요한 조인 | evidence | medium |
| 3 | 인덱스 활용 | WHERE/ORDER BY 컬럼에 인덱스 존재 여부 (스키마 기반 추정) | evidence | medium |
| 4 | 페이징 | 전체 조회 후 메모리 슬라이싱, OFFSET 페이징의 성능 문제 | evidence | medium |
| 5 | 벌크 연산 | 단건 INSERT/UPDATE 루프, batch size 미설정 | evidence | medium |
| 6 | 트랜잭션 범위 | 읽기 전용 누락, 트랜잭션 내 외부 호출 | evidence | medium |

### B. 캐싱·메모리 (4)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 7 | 캐싱 전략 | 로컬/분산 캐시 적용 범위, TTL, 무효화 전략 | advisory | medium |
| 8 | 직렬화 비용 | 과도한 JSON 직렬화·역직렬화, Jackson 설정 | evidence | low |
| 9 | 메모리 누수 패턴 | 정적 컬렉션에 누적, Listener 미해제, ThreadLocal 정리 누락 | evidence | high |
| 10 | 대용량 처리 | 파일/이미지 전체 메모리 로드, 스트리밍 미사용 | evidence | medium |

### C. 동시성·I/O (5)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 11 | 블로킹 호출 | 리액티브/비동기 컨텍스트에서 `.block()`, 동기 DB 호출 (grep hit, 측정) | objective | high |
| 12 | 스레드 풀 | 적정 코어 수, 블로킹 작업 전용 풀 분리 | evidence | medium |
| 13 | 커넥션 풀 | DB/HTTP client 풀 크기, 누수 | evidence | medium |
| 14 | HTTP client | 타임아웃, 재시도, 서킷브레이커 | evidence | high |
| 15 | Backpressure | 비동기 파이프라인에서 역압 처리 | advisory | medium |

> ★ **자주 놓침(동시성)**: 전역/정적 **가변 상태**(변수·컬렉션·dict)를 락·원자성 없이 **read-modify-write** 하면 멀티스레드/코루틴에서 **data race·lost update**(high). 공유 상태를 수정하는 함수마다 동기화 여부를 반드시 확인.

### D. 관측성 (6)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 16 | 구조화 로깅 | JSON 로깅, 상관관계 ID(trace id), 레벨 일관성 | evidence | low |
| 17 | 로그 레벨 | 프로덕션에서 DEBUG/INFO 과다, 민감정보 로깅 | evidence | medium |
| 18 | 메트릭 | 비즈니스 KPI·기술 메트릭 수집(Micrometer/Prometheus) | advisory | low |
| 19 | 분산 추적 | OpenTelemetry/Zipkin, 주요 엔드포인트 span | advisory | low |
| 20 | Health check | liveness/readiness 구분, 의존성 포함 여부 (엔드포인트 존재 측정) | objective | low |
| 21 | 에러 모니터링 | Sentry 등 연동, 샘플링 전략 | advisory | low |

### E. 런타임 설정 (3)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 22 | JVM/런타임 옵션 | heap, GC, metaspace, Node cluster, GOMAXPROCS (설정값 측정) | objective | low |
| 23 | 빌드 최적화 | 트리 쉐이킹, 번들 크기, 네이티브 이미지 | evidence | low |
| 24 | 배치 설정 | Spring Batch chunk size, 병렬 step (설정값 측정) | objective | low |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

## Step 3: 에이전트 위임

`backend-development:backend-architect` 에이전트에게 위임. 프롬프트에 포함:
- Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 전체 체크리스트
- 런타임 모델(리액티브/블로킹)에 맞춘 판단 기준 강조
- Step 4 출력 형식 지시

**빌드/테스트/프로파일링 실행 금지, 코드 읽기만.** 실제 벤치마크는 범위 외이며, 정적 분석 수준에서 위험 패턴만 탐지합니다.

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
## 성능·관측성 리뷰 결과

### 요약
- **스캔 범위**: [경로]
- **런타임 모델**: [동기/비동기/리액티브]

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

### 발견된 병목 (우선순위순)
| # | 카테고리 | 파일:줄 | 설명 | 예상 영향 |

(심층 모드: 각 항목에 현재 코드 / 문제 / 개선 코드 또는 설정)

### 관측성 현황
| 항목 | 상태 | 권장 |

### 개선 로드맵
- Quick wins (설정 변경):
- 구조 개선 (코드 수정):
- 장기 과제 (아키텍처):
```

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(performance). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 트랜잭션 경계 문제 → `/review:architecture`
- 느린 테스트의 원인 → `/review:test`
- 의존성의 성능 이슈 → `/review:deps`
