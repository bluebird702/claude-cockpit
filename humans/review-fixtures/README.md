# 리뷰어 골든셋 (자체 QA)

> "이 리뷰어가 **실제로 좋은가**"를 숫자로 측정하는 장치. 안정성(재현성) 개선이
> 자화자찬이 되지 않도록, 라벨된 결함으로 **precision/recall** 을 잰다.

## 왜 필요한가
- 리뷰 점수를 아무리 결정적으로 만들어도, **탐지 자체가 틀리면** 무의미하다.
- 모델 교체·룰셋 변경 시 조용히 품질이 떨어질 수 있다(회귀). 골든셋이 이를 잡는다.
- `clean_good.py` 로 **거짓양성**(멀쩡한 코드에 발견을 만드는 것 — 점수를 흔드는 또 다른 원인)을 감시한다.

## 구성
```
fixtures/
├── cases/                  라벨된 결함 코드 (각 파일 = 특정 체크리스트 항목 트리거)
│   ├── performance/concurrency_race.py     race-condition (high)
│   ├── security/sql_injection.py           sql-injection (critical)
│   ├── security/hardcoded_credential.py    hardcoded-secret (high)
│   ├── code/swallowed_exception.py         swallowed-exception (high)
│   ├── code/long_method.py                 long-method (low · objective)
│   ├── test/tautological_test.py           tautological (high)
│   ├── domain/order.py                     framework-dependency-in-domain (medium)
│   ├── deps/requirements_unpinned.txt      dynamic-version (medium)
│   ├── deps/requirements_vulnerable.txt    vulnerable-dependency (high · objective/CVE)
│   ├── clean/parameterized_query.py        SQLi 아님 (precision 가드)
│   ├── clean/env_secret.py                 하드코딩 아님 (env 로드)
│   ├── clean/locked_counter.py             race 아님 (lock)
│   ├── clean/rethrown_exception.py         삼킴 아님 (log+raise)
│   └── clean_good.py                       결함 없음 (거짓양성 탐지)
├── expected.jsonl          정답 매니페스트 (파일별 기대 발견)
└── eval.py                 findings ↔ expected 대조 → P/R/F1
```
> `cases/` 는 **의도적 결함**이다. lint/CI 대상에서 제외하고, 절대 "고치지"(결함 제거) 말 것.
> **정답 누설 금지** ★: 픽스처 코드에 "의도적 결함/QA용/이것은 위반" 같은 주석을 넣지 말 것.
> 리뷰어가 그 주석을 보고 탐지를 **억제**하거나, 반대로 힌트에 **의존**해 통과한다 —
> 실측(2026-07-05): 주석 제거만으로 보안 recall 0.57→0.71 상승(억제 해소), 동시에 아키텍처가
> 힌트 의존이 드러나 miss 발생. 결함의 라벨은 **`expected.jsonl`(사이드카)에만** 둔다.

## 실행 프로토콜
```bash
# 1) 골든셋을 리뷰 (전체 스코프)
/review:all humans/review-fixtures/cases --full
#    → 리뷰가 방출한 findings 를 JSON 배열로 저장 (예: run_findings.json)
#      스키마: [{"area","category","severity","file":"cases/.../x.py:LN"}]

# 2) 채점
python3 humans/review-fixtures/eval.py --findings run_findings.json
#    → {tp,fp,fn,precision,recall,f1, misses[], false_positives[]}
#    → 종료코드 0=PASS(P≥0.8·R≥0.8) / 1=FAIL
```

## 언제 돌리나
- 위임 에이전트·모델 변경 시
- 룰셋(RULESET_VERSION) 변경 시 — 회귀 확인 후 버전 bump
- 분기 1회 정기 (리뷰어 드리프트 점검)

## 확장
- 새 결함 유형이 실제 리뷰에서 반복 누락되면 → `cases/` 에 픽스처 + `expected.jsonl` 한 줄 추가.
- 임계(P/R≥0.8)는 `eval.py` 하단에서 조정. 도메인 위험이 크면 recall 임계를 높인다.
