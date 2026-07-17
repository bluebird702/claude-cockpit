# Reliability & Scalability 기준

> **2000만 사용자급 서비스를 전제로 한 코드 기준.** 그 규모에서 서비스를 죽이는 것은
> 네이밍이 아니라 **시스템적 결함**(무한정 쿼리·타임아웃 부재·캐시 스탬피드·비멱등 쓰기·관측 불가)이다.
> hard-won-conventions 의 실사고 관례(rate-limit fail-open, CB 명시 등록, 캐시 범위 무효화)가
> 전부 이 영역에서 나왔다는 것이 근거다. 이 문서는 그 교훈을 **사전 체크리스트**로 일반화한다.

## 스케일 티어 (Scale Tier) — 기준은 선언한다

프로젝트는 `.claude/rules/scale.md` 에 `scale.tier` 를 선언한다. 리뷰(`/review:all`)와
코드 작성 에이전트는 **선언된 티어의 규칙만** 적용한다 — 프로토타입을 과잉 규제하지 않고,
하이퍼스케일을 감으로 봐주지 않기 위함.

| 티어 | 대상 | 적용 범위 |
|------|------|----------|
| `prototype` | 검증 전 실험·내부 도구 | 이 문서 **미적용** (기본 표준만) |
| `production` | 유료 사용자 있는 서비스 | §데이터 접근 + §회복탄력성 + §관측성 |
| `hyperscale` | 대규모(수백만↑) 지향 | **전체** + §launch-readiness 게이트 |

선언이 없으면 `prototype` 으로 간주한다 (미선언 = 과잉 경보 없음, 단 리뷰 리포트에 "티어 미선언" 명시).

## 1. 데이터 접근 (Data Access)

| # | 규칙 | 판정 | Tier | Sev |
|---|------|------|------|-----|
| R1 | **무한정 쿼리 금지** — LIMIT/페이지네이션 없는 목록 조회, `findAll()` 후 메모리 슬라이싱 금지 | grep/코드 (objective) | production | high |
| R2 | **목록 API 는 페이지네이션 필수** — 무페이징 컬렉션 반환 금지 (@api/api-design.md §페이징) | 코드 (objective) | production | high |
| R3 | **N+1 금지** — 루프 내 쿼리 호출·LAZY 연관 반복 접근 | 코드 (evidence) | production | high |
| R4 | **쿼리 조건절마다 인덱스** — WHERE/ORDER BY/JOIN 컬럼 인덱스 존재. 대형 테이블 seq scan = 결함 | `EXPLAIN` (objective) | hyperscale | high |
| R5 | **벌크는 배치로** — 단건 INSERT/UPDATE 루프 금지, batch size 명시 | 코드 (evidence) | production | medium |
| R6 | **마이그레이션 무중단** — expand→backfill→migrate→contract, `CREATE INDEX CONCURRENTLY` | 파일 (evidence) | production | high |

## 2. 회복탄력성 (Resilience)

| # | 규칙 | 판정 | Tier | Sev |
|---|------|------|------|-----|
| R7 | **모든 외부 호출에 타임아웃** — HTTP/DB/캐시 클라이언트 생성부에 timeout 명시. 무한 대기 = 스레드 고갈 → 연쇄 장애 | grep (objective) | production | high |
| R8 | **retry 는 지수 백오프 + 지터** — 즉시 재시도 루프는 장애 시 retry storm 으로 자기 DoS | grep (objective) | production | high |
| R9 | **핵심 외부 의존에 서킷브레이커** — 수동 등록 시 어댑터가 쓰는 **모든** CB 명시 config (hard-won §CB) | 코드 (evidence) | hyperscale | medium |
| R10 | **커넥션 풀 산술** — `풀 크기 × 인스턴스 수 ≤ DB max_connections` (여유율 포함) | 설정 산술 (objective) | hyperscale | high |
| R11 | **캐시 스탬피드 방지** — TTL 만료 시 단일 채움(single-flight/lock/soft-TTL). 동시 재계산 폭주 금지 | 코드 (evidence) | hyperscale | medium |
| R12 | **캐시 무효화는 범위 한정** — `invalidateAll` 금지, 패턴 스코프 evict (hard-won §캐시) | 코드 (evidence) | production | medium |
| R13 | **fail-open/closed 는 의도적으로** — 가용성 경로(rate-limit)는 로컬 floor 있을 때 fail-open, 보안 경로(블랙리스트·인증)는 fail-closed (hard-won §rate-limit) | 코드 (evidence) | production | high |
| R14 | **무한정 인메모리 축적 금지** — unbounded 컬렉션/큐 누적, 파일 전체 메모리 로드 (스트리밍 사용) | 코드 (evidence) | production | medium |

## 3. 동시성·멱등성 (Concurrency & Idempotency)

| # | 규칙 | 판정 | Tier | Sev |
|---|------|------|------|-----|
| R15 | **부수효과 있는 쓰기는 멱등** — 결제·주문 등 POST 는 Idempotency-Key 또는 자연 키 dedup. 네트워크 재시도는 정상 경로다 (@api/api-design.md §멱등성) | 코드 (evidence) | production | high |
| R16 | **check-then-act 는 원자적으로** — 잔액 확인 후 차감, 중복 확인 후 삽입은 DB 제약/원자 연산/락으로. 분산 환경에서 로컬 락은 무효 | 코드 (evidence) | production | high |
| R17 | **공유 가변 상태 read-modify-write 금지** — 전역/정적 상태 수정은 락·원자성 필수 (data race·lost update) | 코드 (evidence) | production | high |
| R18 | **트랜잭션 내 외부 호출 금지** — 커넥션 점유 시간 폭증 → 풀 고갈 | 코드 (evidence) | hyperscale | medium |

## 4. 관측성 (Observability)

| # | 규칙 | 판정 | Tier | Sev |
|---|------|------|------|-----|
| R19 | **핫패스에 메트릭 + traceId** — 핵심 엔드포인트에 latency/error 메트릭과 상관관계 ID 전파 | 코드 (evidence) | production | medium |
| R20 | **메트릭 라벨 고카디널리티 금지** — user_id·email·URL 원문을 라벨로 쓰면 메트릭 시스템이 먼저 죽는다 | grep (objective) | production | high |
| R21 | **에러 로그에 컨텍스트** — 재현에 필요한 식별자(요청 ID·엔티티 ID)를 구조화 필드로. 단 PII 금지 (@management/security.md) | 코드 (evidence) | production | medium |
| R22 | **SLO 는 숫자로** — p95/p99 latency·에러율 예산이 문서/설정에 존재 | 문서 (objective) | hyperscale | medium |

## 5. Launch-Readiness 게이트 (hyperscale 전용)

“측정 없으면 주장 없음”의 스케일판 — **부하 측정 없이 “대규모 감당 가능” 판정은 그 자체가 근거 없는 단언**이다.
`/review:all` 은 hyperscale 티어에서 아래를 게이트로 판정한다:

- [ ] `slo_defined` — p95/에러율 예산이 숫자로 존재
- [ ] `load_tested` — 핵심 엔드포인트 부하 측정값(k6/vegeta 등) 존재, p95 예산 이내. **n/a = unknown 이 아니라 미통과**
- [ ] `rollback_ready` — 롤백 기준 숫자 + 절차 존재 (@planning/prd-guidelines.md §롤백)
- [ ] `dashboards_exist` — 핵심 지표 대시보드·알림 존재 (@product/metrics.md §측정 인프라)

## 코드 작성 시 (리뷰 전에)

이 문서는 리뷰 체크리스트이기 전에 **작성 기준**이다. 에이전트·사람 모두 코드를 쓸 때:
1. 목록 반환 → 페이지네이션부터 (R1·R2)
2. 외부 호출 → 타임아웃·백오프부터 (R7·R8)
3. 부수효과 쓰기 → 멱등 키부터 (R15)
4. 공유 상태 → 원자성부터 (R16·R17)
5. 새 엔드포인트 → 메트릭·traceId 부터 (R19)

---

**버전**: 1.0.0 | **최종 업데이트**: 2026-07-17

> 근거(provenance): hard-won-conventions §아키텍처·회복탄력성(rate-limit fail-open 사고 · CB 튜닝 미적용 버그 · L1 캐시 범위 무효화)에서 일반화. 스케일 티어는 “1인 스케일 프로젝트 과잉 규제 금지”(philosophy §운영 원칙)와 “2000만급 기준”의 양립 장치.
