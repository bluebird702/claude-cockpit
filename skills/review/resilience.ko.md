---
name: review:resilience
description: 회복탄력성·멱등성·동시성 심층 리뷰 — 타임아웃·재시도·서킷브레이커·캐시 스탬피드·race
type: slash-command
category: review
follows-brain:
  - brain/CLAUDE.md
  - brain/engineering/reliability.md
  - brain/hard-won-conventions.md
  - brain/api/api-design.md
enforcement: required
---

# 회복탄력성 리뷰

> ⚠️ **Brain 원칙 준수 필수** — 판단 기준은 standards를 우선합니다.
> @brain/engineering/reliability.md · @brain/hard-won-conventions.md(§아키텍처·회복탄력성 — 실사고 관례, 일반 표준과 긴장하면 이쪽 우선) · @brain/api/api-design.md(§멱등성) · @brain/CLAUDE.md

대규모 트래픽에서 서비스를 죽이는 시스템적 결함 — 타임아웃 부재, retry storm, 캐시 스탬피드,
비멱등 쓰기, data race — 를 심층 점검합니다. **hard-won 실사고 관례의 주 서식지**입니다.

$ARGUMENTS
- `deep` — 심층 모드 (문제 코드 + 개선 코드)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → 프로젝트 전체 요약
- 예: `/review:resilience`, `/review:resilience deep src/payment`

## Step 0: 스케일 티어 확인

`.claude/rules/scale.md` 의 `scale.tier` (또는 all.md RULESET 주입값) 확인.
- `prototype` → **hyperscale 전용 항목(#5·#6·#12)은 전부 `n/a`**, 나머지는 advisory 로만
- `production` / `hyperscale` → 아래 체크리스트 적용 (@brain/engineering/reliability.md 티어 열 기준)
- 미선언 → prototype 취급 + 리포트에 "티어 미선언" 1줄

## Step 1: 컨텍스트 파악

- 외부 의존 지도: HTTP 클라이언트, DB, 캐시(Redis), 큐(Kafka) 사용처
- 런타임 모델 (동기/비동기/리액티브), 멀티 인스턴스 여부
- 부수효과 있는 쓰기 엔드포인트 (결제·주문·포인트 등)

## Step 2: 체크리스트 (14항목)

### A. 타임아웃·재시도·차단 (5)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | 타임아웃 부재 | HTTP/DB/캐시 클라이언트 생성부에 timeout 미명시 (grep hit, 측정) — R7 | objective | high |
| 2 | retry storm | 백오프·지터 없는 즉시 재시도 루프 (grep hit, 측정) — R8 | objective | high |
| 3 | 서킷브레이커 | 핵심 외부 의존 CB 부재·수동 등록 시 인스턴스 누락 (hard-won §CB) — R9 | evidence | medium |
| 4 | fail-open/closed 방향 | **트래픽/가용성 경로**(rate-limit·캐시·폴백)의 fail-closed(self-DoS) — R13, hard-won §rate-limit. 보안 가드(인증·검증·차단)의 fail-open 은 `/review:security` 담당(중복 방출 금지) | evidence | high |
| 5 | 커넥션 풀 산술 | `풀 크기 × 인스턴스 수 > DB max_connections` (설정 산술, 측정) — R10 | objective | high |

### B. 캐시·자원 (3)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 6 | 캐시 스탬피드 | TTL 만료 시 단일 채움(single-flight/soft-TTL) 부재 — R11 | evidence | medium |
| 7 | 무효화 범위 | `invalidateAll`·전체 flush (grep hit, 측정) — R12, hard-won §캐시 | objective | medium |
| 8 | 무한정 축적 | unbounded 인메모리 컬렉션/큐 누적, 전체 메모리 로드 — R14 | evidence | medium |

### C. 멱등성·동시성 (4)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 9 | 비멱등 쓰기 | 결제·주문 등 부수효과 POST 에 Idempotency-Key/자연 키 dedup 부재 — R15 | evidence | high |
| 10 | check-then-act | 확인→변경이 원자적이지 않음 (DB 제약/원자 연산 대신 애플리케이션 검사) — R16 | evidence | high |
| 11 | 공유 상태 race | 전역/정적 가변 상태를 락·원자성 없이 read-modify-write — R17. **공유 상태를 수정하는 함수마다** 동기화 여부 확인 (자주 놓침 ★) | evidence | high |
| 12 | 트랜잭션 내 외부 호출 | 트랜잭션이 외부 I/O 를 품어 커넥션 점유 폭증 — R18 | evidence | medium |

### D. Backpressure·격리 (2)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 13 | Backpressure | 비동기 파이프라인 역압 처리 부재 | advisory | medium |
| 14 | Bulkhead | 블로킹 작업 전용 풀 미분리 (한 의존 장애가 전체 스레드 고갈) | evidence | medium |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-resilience`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 0 티어 + Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 전체 체크리스트
- Step 4 출력 형식 지시

**빌드/테스트/부하 측정 직접 실행 금지, 코드 읽기만.** 부하 수치는 all.md Step 0.5 METRICS 해석.

## 점수 산정 (all.md 가 계산)

이 스킬은 점수를 직접 매기지 않는다. 체크리스트 위반을 **findings 블록**으로 방출하고,
종합/영역 점수는 오케스트레이터(all.md)가 `100 − Σ(severity_penalty × confidence)` 로
결정적으로 계산한다.

- **objective 항목**: Step 0.5 METRICS 수치로 verdict 자동 결정 (LLM 재판정 금지)
- **evidence 항목**: file:line 증거가 있을 때만 발견으로 기록 (confidence 부여, 적대적 검증 대상)
- **advisory 항목**: 서술로만 노출, 점수에서 제외
- **N/A**: 티어·스택상 비해당 항목은 `n/a` (감점 아님, 재현성 위해 노출)

## Step 4: 출력 형식

```markdown
## 회복탄력성 리뷰 결과

### 요약
- **스캔 범위**: [경로] | **스케일 티어**: [prototype/production/hyperscale/미선언]
- **외부 의존**: [HTTP/DB/캐시/큐 목록]

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

### 발견된 문제 (우선순위순)
| # | 카테고리 | 파일:줄 | 설명 | 장애 시나리오 |

(심층 모드: 각 항목에 현재 코드 / 장애 시나리오 / 개선 코드)

### 멱등성 현황 (부수효과 엔드포인트별)
| 엔드포인트 | 멱등 보장 | 방식 |
```

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(resilience). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 쿼리·캐싱 성능 문제 → `/review:performance`
- 트랜잭션 경계가 구조 문제 → `/review:architecture`
- fail-open/closed 이 보안 경로 → `/review:security`
