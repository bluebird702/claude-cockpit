> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

---
name: review:performance
description: 성능 병목·쿼리·캐싱·관측성 심층 리뷰 (회복탄력성·동시성은 review:resilience)
type: slash-command
category: review
follows-standards:
  - brain/CLAUDE.md
  - brain/coding/coding-guidelines.md
  - brain/engineering/reliability.md
enforcement: required
---

# 성능·관측성 리뷰

> ⚠️ **Standards 준수 필수** — 성능/관측성 판단 기준은 standards를 우선합니다.
> @brain/engineering/reliability.md(§데이터 접근·§관측성) · @brain/coding/coding-guidelines.md · @brain/CLAUDE.md
> 타임아웃·재시도·서킷브레이커·멱등성·race 는 **`/review:resilience` 담당** (중복 발견 금지).

프로젝트의 성능 병목, 쿼리 패턴, 캐싱 전략, 관측성(로깅·메트릭·추적) 수준을 심층 점검합니다.

$ARGUMENTS
- `deep` — 심층 모드 (문제 코드 + 개선 코드)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체 요약
- 예: `/review:performance`, `/review:performance deep src/order`

## Step 0: 스케일 티어 확인

`.claude/rules/scale.md` 의 `scale.tier` (또는 all.md RULESET 주입값) 확인 — hyperscale 전용
항목(#3 EXPLAIN 판정)은 티어 미달 시 evidence 로 강등. 미선언 → prototype 취급 + 리포트에 1줄.

## Step 1: 컨텍스트 파악

- 언어, 프레임워크, 런타임 (JVM, Node, Go 등)
- 데이터 접근 계층 (JPA, R2DBC, Prisma, ActiveRecord, 직접 SQL)
- 런타임 모델 (동기 블로킹 / 비동기 / 리액티브)
- 관측성 스택 (Micrometer, OpenTelemetry, Sentry, Datadog)

## Step 2: 체크리스트 (5개 카테고리)

### A. 데이터베이스·쿼리 (7)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | N+1 쿼리 | 연관 엔티티 반복 조회, `fetch = LAZY` + 루프 내 접근 — R3 | evidence | high |
| 2 | 무한정 쿼리 | LIMIT/페이지네이션 없는 목록 조회, `findAll()` 후 메모리 슬라이싱 (grep hit, 측정) — R1·R2 | objective | high |
| 3 | 인덱스 활용 | WHERE/ORDER BY/JOIN 컬럼 인덱스 존재 — R4. hyperscale 이면 `EXPLAIN` 측정(objective), 아니면 스키마 기반 추정(evidence) | evidence | medium |
| 4 | 페치 전략 | 과도한 eager fetch, 불필요한 조인 | evidence | medium |
| 5 | OFFSET 페이징 | 깊은 페이지 성능 저하 — 대규모 목록은 커서 기반 (@api/api-design.md) | evidence | medium |
| 6 | 벌크 연산 | 단건 INSERT/UPDATE 루프, batch size 미설정 — R5 | evidence | medium |
| 7 | 읽기 전용 트랜잭션 | 읽기 경로 readOnly 누락 (트랜잭션 내 외부 호출은 `/review:resilience`) | evidence | medium |

### B. 캐싱·메모리 (3)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 8 | 캐싱 전략 | 로컬/분산 캐시 적용 범위, TTL 설계 (스탬피드·무효화 범위는 `/review:resilience`) | advisory | medium |
| 9 | 직렬화 비용 | 과도한 JSON 직렬화·역직렬화, Jackson 설정 | evidence | low |
| 10 | 메모리 누수 패턴 | 정적 컬렉션에 누적, Listener 미해제, ThreadLocal 정리 누락 | evidence | high |

### C. I/O·스레드 (2)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 11 | 블로킹 호출 | 리액티브/비동기 컨텍스트에서 `.block()`, 동기 DB 호출 (grep hit, 측정) | objective | high |
| 12 | 스레드 풀 | 적정 코어 수, 블로킹 작업 전용 풀 분리 (커넥션 풀 산술·타임아웃은 `/review:resilience`) | evidence | medium |

### D. 관측성 (7)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 13 | 구조화 로깅 | JSON 로깅, 상관관계 ID(trace id), 레벨 일관성 — R19·R21 | evidence | medium |
| 14 | 고카디널리티 라벨 | 메트릭 라벨에 user_id·email·URL 원문 (grep hit, 측정) — R20. 대규모에선 메트릭 시스템이 먼저 죽는다 | objective | high |
| 15 | 로그 레벨 | 프로덕션에서 DEBUG/INFO 과다, 민감정보 로깅 | evidence | medium |
| 16 | 메트릭 | 비즈니스 KPI·기술 메트릭 수집(Micrometer/Prometheus) — R19 | evidence | medium |
| 17 | 분산 추적 | OpenTelemetry/Zipkin, 주요 엔드포인트 span | advisory | low |
| 18 | Health check | liveness/readiness 구분, 의존성 포함 여부 (엔드포인트 존재 측정) | objective | low |
| 19 | 에러 모니터링 | Sentry 등 연동, 샘플링 전략 | advisory | low |

### E. 런타임 설정 (3)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 20 | JVM/런타임 옵션 | heap, GC, metaspace, Node cluster, GOMAXPROCS (설정값 측정) | objective | low |
| 21 | 빌드 최적화 | 트리 쉐이킹, 번들 크기, 네이티브 이미지 | evidence | low |
| 22 | 배치 설정 | Spring Batch chunk size, 병렬 step (설정값 측정) | objective | low |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-performance`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 0 티어 + Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 전체 체크리스트
- 런타임 모델(리액티브/블로킹)에 맞춘 판단 기준 강조
- Step 4 출력 형식 지시

**빌드/테스트/프로파일링 실행 금지, 코드 읽기만.** 실제 벤치마크는 범위 외이며, 부하 수치는
all.md Step 0.5 METRICS(k6 스모크 등)를 해석만 합니다.

## 점수 산정 (all.md 가 계산)

이 스킬은 점수를 직접 매기지 않는다. 체크리스트 위반을 **findings 블록**으로 방출하고,
종합/영역 점수는 오케스트레이터(all.md)가 `100 − Σ(severity_penalty × confidence)` 로
결정적으로 계산한다.

- **objective 항목**: Step 0.5 METRICS 수치로 verdict 자동 결정 (LLM 재판정 금지)
- **evidence 항목**: file:line 증거가 있을 때만 발견으로 기록 (confidence 부여, 적대적 검증 대상)
- **advisory 항목**: 서술로만 노출, 점수에서 제외
- **N/A**: 언어·스택·티어상 비해당 항목은 `n/a` (감점 아님, 재현성 위해 노출)

## Step 4: 출력 형식

```markdown
## 성능·관측성 리뷰 결과

### 요약
- **스캔 범위**: [경로] | **스케일 티어**: [prototype/production/hyperscale/미선언]
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

- 타임아웃·재시도·멱등성·race → `/review:resilience`
- 트랜잭션 경계 문제 → `/review:architecture`
- 느린 테스트의 원인 → `/review:test`
- 의존성의 성능 이슈 → `/review:deps`
