# 리뷰어 골든셋 (자체 QA)

> "이 리뷰어가 **실제로 좋은가**"를 숫자로 측정하는 장치. 안정성(재현성) 개선이
> 자화자찬이 되지 않도록, 라벨된 결함으로 **precision/recall** 을 잰다.

## 왜 필요한가
- 리뷰 점수를 아무리 결정적으로 만들어도, **탐지 자체가 틀리면** 무의미하다.
- 모델 교체·룰셋 변경 시 조용히 품질이 떨어질 수 있다(회귀). 골든셋이 이를 잡는다.
- `clean/` 픽스처로 **거짓양성**(멀쩡한 코드에 발견을 만드는 것 — 점수를 흔드는 또 다른 원인)을 감시한다.

## 구성 (영역별 결함 + clean 쌍)

```
fixtures/
├── cases/
│   ├── security/       sql_injection · hardcoded_credential · fail_open_guard.sh · untrusted_exec.sh
│   ├── code/           swallowed_exception · long_method · CreateOrderService.kt(검증 위치) ·
│   │                   MemberController.kt(ResponseEntity.ok) · AuthTokenIssuer.kt(인자 개행)
│   ├── test/           tautological_test · time_dependent_test · model_coverage_test
│   ├── architecture/   report_usecase(유스케이스가 인프라 직접 의존)
│   ├── domain/         order(도메인의 프레임워크 의존)
│   ├── performance/    concurrency_race · n_plus_one · unbounded_query · high_cardinality_metric
│   ├── resilience/     missing_timeout · retry_no_backoff · cache_stampede · non_idempotent_charge
│   ├── deps/           requirements_unpinned · requirements_vulnerable
│   ├── clean/          결함처럼 보이지만 멀쩡한 코드 (precision 가드) — 각 영역의 짝:
│   │                   parameterized_query · env_secret · locked_counter · rethrown_exception ·
│   │                   failclosed_guard.sh · trusted_exec.sh · paginated_query · http_with_timeout ·
│   │                   backoff_retry · idempotent_charge · AccountController.kt
│   └── clean_good.py   결함 없음 (거짓양성 탐지)
├── expected.jsonl        정답 매니페스트 (파일별 기대 발견 — 라벨의 유일한 위치)
├── eval.py               리뷰어 채점: findings ↔ expected 대조 → P/R/F1/score
├── verifier-cases.jsonl  검증자 골든셋 17케이스 (known-true 7 + known-false 10 —
│                         vh-* 는 교차 파일 가드·위장 결함 등 난이도 상향 케이스)
├── eval_verifier.py      검증자 채점: confirm/refute recall + score
├── eval_stability.py     재현성 채점: 두 실행의 발견 집합을 안정 키로 비교 → jaccard
│                         (실제 프로젝트의 "같은 커밋 2회 실행" 비교에도 사용 — 라벨 불필요)
└── selftest.py           eval.py 채점기 자체 회귀 (CI, LLM 불필요)
```
> `cases/` 는 **의도적 결함**이다. lint/CI 대상에서 제외하고, 절대 "고치지"(결함 제거) 말 것.
> **정답 누설 금지** ★: 픽스처 코드에 "의도적 결함/QA용/이것은 위반" 같은 주석을 넣지 말 것.
> 리뷰어가 그 주석을 보고 탐지를 **억제**하거나, 반대로 힌트에 **의존**해 통과한다 —
> 실측(2026-07-05): 주석 제거만으로 보안 recall 0.57→0.71 상승(억제 해소), 동시에 아키텍처가
> 힌트 의존이 드러나 miss 발생. 결함의 라벨은 **`expected.jsonl`(사이드카)에만** 둔다.
> Kotlin 픽스처(`*.kt`)는 standards 고유 규칙(인자 개행·검증 위치·Controller 반환)의 탐지율을
> 재기 위함 — 이 규칙들은 Python 픽스처로는 측정 불가.

## 실행 프로토콜

### 1) 리뷰어 측정 (P/R)
```bash
# 골든셋을 리뷰 (전체 스코프)
/review:all humans/review-fixtures/cases --full
#    → 리뷰가 방출한 findings 를 JSON 배열로 저장 (예: run_findings.json)
#      스키마: [{"area","category","severity","file":"cases/.../x.py:LN"}]

# 채점
python3 humans/review-fixtures/eval.py --findings run_findings.json
#    → {tp,fp,fn,precision,recall,f1,score, misses[], false_positives[]}
#    → 종료코드 0=PASS(P≥0.8·R≥0.8) / 1=FAIL
#    → score(F1×100)는 실행 간 추세 관찰용 — 판정은 항상 P/R 게이트
#      (단일 점수는 P/R 어느 쪽이 무너졌는지 숨기므로 게이트를 대체하지 않는다)
```

### 2) 검증자 측정 (confirm/refute recall) ★
적대적 검증(Step 2.6)의 검증자 자체를 잰다 — 검증자가 진짜 결함을 refute 하면 recall 이
조용히 죽고, 오탐을 confirm 하면 방어선이 무력화되기 때문.
```bash
# verifier-cases.jsonl 의 각 케이스를 review-verifier 에게 전달
#    → 판정을 JSON 배열로 저장: [{"id": "vt-01", "verdict": "confirmed"}]
python3 humans/review-fixtures/eval_verifier.py --verdicts run_verdicts.json
#    → 종료코드 0=PASS(confirm/refute recall ≥0.8) / 1=FAIL
```

### 3) 재현성 측정 (run-to-run jaccard)
같은 입력을 두 번 리뷰해 발견 집합의 흔들림을 잰다 — 골든셋이 "맞느냐"라면 이건 "흔들리느냐".
```bash
python3 humans/review-fixtures/eval_stability.py --a run1.json --b run2.json
#    → {jaccard, by_area{only_a,only_b}, passed}  (임계 0.8)
# 실제 프로젝트: 같은 커밋을 2회 /review:all 실행 → 두 findings 를 비교 (정답 라벨 불필요)
```

## held-out 케이스 정책 ★
골든셋으로 점수를 끌어올리다 보면 **골든셋에만 강한 리뷰어**(암기)가 될 수 있다.
일부 케이스는 유형을 체크리스트·에이전트 프롬프트·이 문서 어디에도 예시로 언급하지 않는
**held-out** 으로 유지한다 (라벨은 expected.jsonl 에만). held-out 에서만 recall 이 떨어지면
그것이 암기의 신호다. held-out 케이스의 유형을 문서·프롬프트에 추가하는 것은 held-out 해제를
의미하므로, 해제 시 새 held-out 을 보충한다.

## 베이스라인 기록 (측정 이력)
| 날짜 | 룰셋 | 실행 | 리뷰어 P/R (score) | 검증자 (score) | 비고 |
|------|------|------|--------------------|----------------|------|
| 2026-07-17 | v7 | run1 (36케이스) | 0.79/0.96 (87) → 정제 후 0.92/1.00 (96) | 1.00/1.00 (100, 11케이스) | 최초 라이브. FAIL 원인 전부 픽스처·채점기·영역 경계 결함 — 수정 반영 |
| 2026-07-17 | v7 | run2 (36케이스) | **1.00/1.00 (100)** | **1.00/1.00 (100, 17케이스 — vh-* 난이도 상향 포함)** | FP 완전 소거 확인. run1↔run2 jaccard **0.85** (불일치 4 중 3은 의도적 수정 효과, 순수 명명 변동 1). 검증자는 교차 파일 가드·위장 멱등성까지 17/17 정답 |

> 신규 실행 시 이 표에 한 줄 추가 (측정 provenance — "점수가 어디서 왔는가"에 답하는 표).

## 언제 돌리나
- 위임 에이전트(`humans/subagents/review-*.md`)·모델 변경 시 — **1)·2) 모두**
- 룰셋(RULESET_VERSION) 변경 시 — 회귀 확인 후 버전 bump
- 분기 1회 정기 (리뷰어 드리프트 점검)
- CI: `humans/skills/review/**`·`humans/subagents/review-*` 변경 PR 은
  `.github/workflows/goldenset-eval.yml` 이 자동 실행 (머지 게이트)

## 확장
- 새 결함 유형이 실제 리뷰에서 반복 누락되면 → `cases/` 에 픽스처 + `expected.jsonl` 한 줄 추가.
- 검증자가 실전에서 오판(진짜를 refute / 오탐을 confirm)하면 → 그 발견을 `verifier-cases.jsonl` 에 추가.
- 임계(P/R≥0.8)는 `eval.py`·`eval_verifier.py` 하단에서 조정. 도메인 위험이 크면 recall 임계를 높인다.
