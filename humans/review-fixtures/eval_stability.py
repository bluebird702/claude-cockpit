#!/usr/bin/env python3
"""리뷰 재현성(run-to-run 안정성) 측정 — 두 실행의 발견 집합을 안정 키로 비교한다.

골든셋 P/R(eval.py)이 "맞느냐"를 잰다면, 이 스크립트는 "흔들리느냐"를 잰다.
같은 입력(커밋·픽스처)을 두 번 리뷰했을 때 발견 집합이 얼마나 겹치는가 —
리뷰 시스템의 실전 신뢰는 사실 이쪽이 결정한다. 골든셋뿐 아니라 실제 프로젝트의
"같은 커밋 2회 실행" 비교에도 그대로 쓴다 (정답 라벨 불필요).

안정 키는 all.md 원장(ledger) 방식과 동일: area:basename:category-stems
(라인 번호 제외 — 표기 흔들림 흡수, category 는 eval.py 의 stem/동의어 정규화 재사용).

사용:
    python3 eval_stability.py --a run1_findings.json --b run2_findings.json
    python3 eval_stability.py --selftest   # 채점기 자체 회귀 (CI, LLM 불필요)

판정: 전체 자카드 ≥ 0.8 = PASS (권장 임계 — 하단 THRESHOLD 조정 가능)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# eval.py 의 category 정규화(stem·동의어)를 재사용 — 두 채점기가 다른 사전을
# 쓰면 "eval 은 같다는데 stability 는 다르다" 는 모순이 생긴다.
sys.path.insert(0, str(Path(__file__).parent))
from eval import _basename, _norm, _tokens  # noqa: E402

THRESHOLD = 0.8


def stable_key(f: dict) -> str:
    stems = "-".join(sorted(_tokens(f.get("category", ""))))
    return f"{_norm(f.get('area'))}:{_basename(f.get('file', ''))}:{stems}"


def load(path: Path) -> set[str]:
    data = json.loads(path.read_text("utf-8"))
    findings = data if isinstance(data, list) else data.get("findings", [])
    return {stable_key(f) for f in findings}


def score(a: set[str], b: set[str]) -> dict:
    union = a | b
    inter = a & b
    jaccard = len(inter) / len(union) if union else 1.0
    by_area: dict[str, dict] = {}
    for area in sorted({k.split(":", 1)[0] for k in union}):
        ua = {k for k in a if k.startswith(area + ":")}
        ub = {k for k in b if k.startswith(area + ":")}
        u, i = ua | ub, ua & ub
        by_area[area] = {
            "jaccard": round(len(i) / len(u), 3) if u else 1.0,
            "only_a": sorted(ua - ub),
            "only_b": sorted(ub - ua),
        }
    return {
        "jaccard": round(jaccard, 3),
        "stable": len(inter),
        "only_a": len(a - b),
        "only_b": len(b - a),
        "by_area": by_area,
        "passed": jaccard >= THRESHOLD,
    }


def selftest() -> int:
    f1 = [
        {
            "area": "security",
            "category": "sql-injection",
            "severity": "critical",
            "file": "cases/a.py:6",
        },
        {
            "area": "code",
            "category": "swallowed-exception",
            "severity": "high",
            "file": "cases/b.py:5",
        },
    ]
    # 같은 발견의 다른 표기(라인·동의어·순서) → 동일 키
    f2 = [
        {
            "area": "code",
            "category": "swallowed-exception",
            "severity": "high",
            "file": "cases/b.py:99",
        },
        {
            "area": "security",
            "category": "sql-injection",
            "severity": "critical",
            "file": "x/cases/a.py:1",
        },
    ]
    r = score({stable_key(f) for f in f1}, {stable_key(f) for f in f2})
    assert r["jaccard"] == 1.0 and r["passed"], r
    print("✓ 표기만 다른 동일 발견 → jaccard 1.0 PASS")

    # 절반만 겹침 → jaccard 1/3, FAIL
    f3 = [
        f1[0],
        {
            "area": "test",
            "category": "tautological",
            "severity": "high",
            "file": "cases/c.py:1",
        },
    ]
    r = score({stable_key(f) for f in f1}, {stable_key(f) for f in f3})
    assert r["jaccard"] < THRESHOLD and not r["passed"], r
    print("✓ 절반 불일치 → FAIL (jaccard < 0.8)")

    # 빈 집합끼리 → 1.0 (둘 다 아무것도 못 찾은 것도 '일관'은 하다)
    r = score(set(), set())
    assert r["jaccard"] == 1.0, r
    print("✓ 빈 집합 쌍 → jaccard 1.0")

    print("eval_stability.py 셀프테스트 통과")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", help="실행 1 findings JSON")
    ap.add_argument("--b", help="실행 2 findings JSON")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if not (args.a and args.b):
        ap.error("--a/--b 또는 --selftest 필요")

    report = score(load(Path(args.a)), load(Path(args.b)))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print(
        ("PASS" if report["passed"] else "FAIL")
        + f" (jaccard ≥ {THRESHOLD}) — jaccard={report['jaccard']:.2f}"
        + f" (공통 {report['stable']} · A단독 {report['only_a']} · B단독 {report['only_b']})",
        file=sys.stderr,
    )
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
