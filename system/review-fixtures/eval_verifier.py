#!/usr/bin/env python3
"""검증자(적대적 검증) 골든셋 채점 — verifier 의 confirm/refute 정답률을 측정한다.

검증자가 진짜 결함을 refute 하면 recall 이 조용히 죽고, 오탐을 confirm 하면
적대적 검증이라는 방어선 자체가 무력화된다. 그래서 검증자도 리뷰어처럼 측정한다:
verifier-cases.jsonl 의 known-true(confirmed 기대)·known-false(refuted 기대) 발견을
검증자에 넣고, 판정 결과를 이 스크립트로 채점한다.

사용:
    # 1) verifier-cases.jsonl 의 각 케이스를 review-verifier 에게 전달
    #    → 판정을 JSON 배열로 저장: [{"id": "vt-01", "verdict": "confirmed"}]
    # 2) 채점:
    python3 eval_verifier.py --verdicts run_verdicts.json
    # 채점기 자체 회귀 확인 (CI, LLM 불필요):
    python3 eval_verifier.py --selftest

판정 기준 (둘 다 만족해야 PASS):
- confirm_recall ≥ 0.8  — 진짜 결함을 confirmed 로 지킨 비율 (미달 = recall 킬러)
- refute_recall  ≥ 0.8  — 오탐을 refuted 로 걸러낸 비율 (미달 = 방어선 무력화)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
CASES = HERE / "verifier-cases.jsonl"
THRESHOLD = 0.8


def load_cases(path: Path) -> dict[str, str]:
    cases = {}
    for line in path.read_text("utf-8").splitlines():
        line = line.strip()
        if line:
            row = json.loads(line)
            cases[row["id"]] = row["expected_verdict"]
    return cases


def score(cases: dict[str, str], verdicts: list[dict]) -> dict:
    if not isinstance(verdicts, list):
        verdicts = [verdicts] if isinstance(verdicts, dict) else []
    got = {v.get("id"): (v.get("verdict") or "").strip().lower() for v in verdicts if isinstance(v, dict) and "id" in v}
    true_ids = [i for i, e in cases.items() if e == "confirmed"]
    false_ids = [i for i, e in cases.items() if e == "refuted"]

    confirm_hits = sum(1 for i in true_ids if got.get(i) == "confirmed")
    refute_hits = sum(1 for i in false_ids if got.get(i) == "refuted")
    missing = [i for i in cases if i not in got]

    confirm_recall = confirm_hits / len(true_ids) if true_ids else 1.0
    refute_recall = refute_hits / len(false_ids) if false_ids else 1.0
    denom = confirm_recall + refute_recall
    harmonic = 2 * confirm_recall * refute_recall / denom if denom else 0.0
    return {
        "confirm_recall": round(confirm_recall, 3),
        "refute_recall": round(refute_recall, 3),
        # 추세 관찰용 100점 환산 (두 recall 의 조화평균 ×100 — 한쪽 붕괴가 평균에
        # 가려지지 않게). 판정은 아래 passed 게이트가 한다.
        "score": round(harmonic * 100),
        "wrongly_refuted": [i for i in true_ids if got.get(i) != "confirmed"],
        "wrongly_confirmed": [i for i in false_ids if got.get(i) != "refuted"],
        "missing": missing,
        "passed": confirm_recall >= THRESHOLD and refute_recall >= THRESHOLD,
    }


def selftest() -> int:
    cases = load_cases(CASES)
    assert cases, "verifier-cases.jsonl 이 비어 있음"
    assert any(e == "confirmed" for e in cases.values()), "known-true 케이스 없음"
    assert any(e == "refuted" for e in cases.values()), "known-false 케이스 없음"

    perfect = [{"id": i, "verdict": e} for i, e in cases.items()]
    r = score(cases, perfect)
    assert r["passed"] and r["confirm_recall"] == 1.0 and r["refute_recall"] == 1.0, r
    print("✓ 완벽 판정 → confirm/refute recall 1.0 PASS")

    # 전부 confirmed 로 동조하는 검증자(파일 안 읽는 yes-man)는 FAIL 해야 한다
    yes_man = [{"id": i, "verdict": "confirmed"} for i in cases]
    r = score(cases, yes_man)
    assert not r["passed"] and r["refute_recall"] == 0.0, r
    print("✓ 전부 confirmed(동조) → FAIL (refute_recall 0)")

    # 전부 refuted 로 죽이는 검증자(recall 킬러)도 FAIL 해야 한다
    nay_man = [{"id": i, "verdict": "refuted"} for i in cases]
    r = score(cases, nay_man)
    assert not r["passed"] and r["confirm_recall"] == 0.0, r
    print("✓ 전부 refuted(킬러) → FAIL (confirm_recall 0)")

    print("eval_verifier.py 셀프테스트 통과")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verdicts", help="검증자 판정 JSON 배열")
    ap.add_argument("--cases", default=str(CASES), help="검증자 골든셋 manifest")
    ap.add_argument("--selftest", action="store_true", help="채점기 자체 회귀 확인")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if not args.verdicts:
        ap.error("--verdicts 또는 --selftest 필요")

    cases = load_cases(Path(args.cases))
    verdicts = json.loads(Path(args.verdicts).read_text("utf-8"))
    report = score(cases, verdicts)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print(
        ("PASS" if report["passed"] else "FAIL")
        + f" (confirm/refute recall ≥ {THRESHOLD}) — "
        + f"confirm={report['confirm_recall']:.2f} refute={report['refute_recall']:.2f}"
        + f" · score {report['score']}/100",
        file=sys.stderr,
    )
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
