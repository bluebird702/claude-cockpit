#!/usr/bin/env python3
"""eval.py 하네스 셀프테스트 (CI용 — LLM 불필요).

expected.jsonl 로부터 '완벽' findings 를 합성해 eval.py 가 P=R=1 로 PASS 하는지,
'빈' findings 는 FAIL(recall 0) 하는지 확인한다. 스코어러 자체의 회귀를 잡는 용도.
(골든셋의 실제 리뷰 품질 측정이 아니라, 채점기 mechanics 검증)
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
EXPECTED = os.path.join(HERE, "expected.jsonl")
EVAL = os.path.join(HERE, "eval.py")


def _run(findings: list[dict]) -> tuple[int, str]:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as t:
        json.dump(findings, t)
        path = t.name
    try:
        r = subprocess.run(
            [sys.executable, EVAL, "--findings", path],
            capture_output=True,
            text=True,
        )
    finally:
        os.unlink(path)
    return r.returncode, r.stdout


def main() -> int:
    expected = [
        json.loads(line) for line in open(EXPECTED, encoding="utf-8") if line.strip()
    ]

    # 완벽: 각 expected 항목당 정확 매칭 finding 합성
    perfect = [
        {
            "area": e["area"],
            "category": e["category"],
            "severity": e["severity"],
            "file": f"{row['file']}:1",
        }
        for row in expected
        for e in row["expected"]
    ]
    rc, out = _run(perfect)
    assert rc == 0, f"완벽 findings 는 PASS(rc=0) 해야 함: rc={rc}\n{out}"
    d = json.loads(out)
    assert d["precision"] == 1.0 and d["recall"] == 1.0, f"P/R 1.0 기대: {d}"
    print("✓ 완벽 findings → P=R=1.0 PASS")

    # 빈: recall 0 → FAIL
    rc, out = _run([])
    assert rc == 1, f"빈 findings 는 FAIL(rc=1) 해야 함: rc={rc}\n{out}"
    print("✓ 빈 findings → FAIL (recall 0)")

    print("eval.py 셀프테스트 통과")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
