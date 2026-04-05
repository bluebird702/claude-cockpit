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
| # | 항목 | 점검 내용 |
|---|------|----------|
| 1 | N+1 쿼리 | 연관 엔티티 반복 조회, `fetch = LAZY` + 루프 내 접근 |
| 2 | 페치 전략 | 과도한 eager fetch, 불필요한 조인 |
| 3 | 인덱스 활용 | WHERE/ORDER BY 컬럼에 인덱스 존재 여부 (스키마 기반 추정) |
| 4 | 페이징 | 전체 조회 후 메모리 슬라이싱, OFFSET 페이징의 성능 문제 |
| 5 | 벌크 연산 | 단건 INSERT/UPDATE 루프, batch size 미설정 |
| 6 | 트랜잭션 범위 | 읽기 전용 누락, 트랜잭션 내 외부 호출 |

### B. 캐싱·메모리 (4)
| # | 항목 | 점검 내용 |
|---|------|----------|
| 7 | 캐싱 전략 | 로컬/분산 캐시 적용 범위, TTL, 무효화 전략 |
| 8 | 직렬화 비용 | 과도한 JSON 직렬화·역직렬화, Jackson 설정 |
| 9 | 메모리 누수 패턴 | 정적 컬렉션에 누적, Listener 미해제, ThreadLocal 정리 누락 |
| 10 | 대용량 처리 | 파일/이미지 전체 메모리 로드, 스트리밍 미사용 |

### C. 동시성·I/O (5)
| # | 항목 | 점검 내용 |
|---|------|----------|
| 11 | 블로킹 호출 | 리액티브/비동기 컨텍스트에서 `.block()`, 동기 DB 호출 |
| 12 | 스레드 풀 | 적정 코어 수, 블로킹 작업 전용 풀 분리 |
| 13 | 커넥션 풀 | DB/HTTP client 풀 크기, 누수 |
| 14 | HTTP client | 타임아웃, 재시도, 서킷브레이커 |
| 15 | Backpressure | 비동기 파이프라인에서 역압 처리 |

### D. 관측성 (6)
| # | 항목 | 점검 내용 |
|---|------|----------|
| 16 | 구조화 로깅 | JSON 로깅, 상관관계 ID(trace id), 레벨 일관성 |
| 17 | 로그 레벨 | 프로덕션에서 DEBUG/INFO 과다, 민감정보 로깅 |
| 18 | 메트릭 | 비즈니스 KPI·기술 메트릭 수집(Micrometer/Prometheus) |
| 19 | 분산 추적 | OpenTelemetry/Zipkin, 주요 엔드포인트 span |
| 20 | Health check | liveness/readiness 구분, 의존성 포함 여부 |
| 21 | 에러 모니터링 | Sentry 등 연동, 샘플링 전략 |

### E. 런타임 설정 (3)
| # | 항목 | 점검 내용 |
|---|------|----------|
| 22 | JVM/런타임 옵션 | heap, GC, metaspace, Node cluster, GOMAXPROCS |
| 23 | 빌드 최적화 | 트리 쉐이킹, 번들 크기, 네이티브 이미지 |
| 24 | 배치 설정 | Spring Batch chunk size, 병렬 step |

## Step 3: 에이전트 위임

`backend-development:backend-architect` 에이전트에게 위임. 프롬프트에 포함:
- Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 전체 체크리스트
- 런타임 모델(리액티브/블로킹)에 맞춘 판단 기준 강조
- Step 4 출력 형식 지시

**빌드/테스트/프로파일링 실행 금지, 코드 읽기만.** 실제 벤치마크는 범위 외이며, 정적 분석 수준에서 위험 패턴만 탐지합니다.

## 점수 산정 규칙

| 카테고리 | 항목 수 | 배점 |
|---------|---------|------|
| A. DB·쿼리 | 6 | 25점 |
| B. 캐싱·메모리 | 4 | 15점 |
| C. 동시성·I/O | 5 | 20점 |
| D. 관측성 | 6 | 25점 |
| E. 런타임 설정 | 3 | 15점 |

- **N/A 처리**: 기술스택 비해당 항목은 N/A로 표시하고 해당 카테고리 분모에서 제외
  - JVM/Spring 아닌 프로젝트 → #22(JVM 옵션), #24(배치 설정) N/A 가능
  - 동기 블로킹 프로젝트 → #11(블로킹 호출), #15(Backpressure) N/A
- **카테고리 점수**: `(통과 항목 수 ÷ (카테고리 전체 − N/A)) × 카테고리 배점`
- **종합 점수**: 5개 카테고리 점수 합 (소수점 반올림)

## Step 4: 출력 형식

```markdown
## 성능·관측성 리뷰 결과

### 요약
- **스캔 범위**: [경로]
- **런타임 모델**: [동기/비동기/리액티브]
- **종합 점수**: XX/100

| 영역 | 점수 | 상태 |
|------|------|------|
| DB·쿼리 | XX | 🟢/🟡/🔴 |
| 캐싱·메모리 | XX | 🟢/🟡/🔴 |
| 동시성·I/O | XX | 🟢/🟡/🔴 |
| 관측성 | XX | 🟢/🟡/🔴 |
| 런타임 설정 | XX | 🟢/🟡/🔴 |

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

## Step 5: 드릴다운

- 트랜잭션 경계 문제 → `/review:architecture`
- 느린 테스트의 원인 → `/review:test`
- 의존성의 성능 이슈 → `/review:deps`
