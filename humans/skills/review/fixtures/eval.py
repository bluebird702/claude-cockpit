#!/usr/bin/env python3
"""골든셋 채점 — 리뷰어의 precision/recall 을 측정한다.

리뷰 실행이 방출한 findings 를 정답(expected.jsonl)과 대조해 TP/FP/FN 을 센다.
LLM 리뷰 자체는 비결정적이므로, 이 스크립트로 **리뷰어의 품질을 숫자로** 잡아
모델 교체·룰셋 변경 시 회귀(정밀도·재현율 하락)를 감지한다.

사용:
    # 1) 골든셋을 리뷰: /review:all humans/skills/review/fixtures/cases --full
    #    → 그 findings 를 JSON 배열로 저장 (아래 스키마)
    # 2) 채점:
    python3 eval.py --findings run_findings.json [--expected expected.jsonl]

findings JSON 스키마 (배열):
    [{"area": "security", "category": "sql-injection", "severity": "critical",
      "file": "cases/security/sql_injection.py:6"}]

매칭 규칙:
- 파일 basename + area 가 같고 (category 일치 OR 같은 area+severity) 면 매칭(TP).
- clean 파일에서 나온 발견은 무조건 FP(거짓양성).
- 정답에 있는데 매칭 안 되면 FN(놓침).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def _basename(path: str) -> str:
    # "cases/security/sql_injection.py:6" → "sql_injection.py"
    return os.path.basename(path.split(":", 1)[0])


def _norm(s: str) -> str:
    return (s or "").strip().lower()


_STOP = {"in", "of", "the", "a", "to", "with", "on", "and"}
_SEV = {"critical": 4, "high": 3, "medium": 2, "low": 1}
# stem 동의어 → canonical stem (리뷰어가 같은 결함을 다른 어휘로 명명하는 것 흡수).
# 원장의 category 동의어 사전과 같은 취지. 순수 severity 매칭을 없앤 뒤 true-synonym 을 지킨다.
_SYN = {
    "unpin": "dynam",  # unpinned-dependency ↔ dynamic-version
    "crede": "secre",  # hardcoded-credential ↔ hardcoded-secret
    "known": "vulne",  # known-vulnerability ↔ vulnerable-dependency
    "direc": "depen",  # dependency-direction ↔ (framework-)dependency
}


def _tokens(s: str) -> set[str]:
    # 접두 stem(5자) + 동의어 canonical 로 표기차 흡수: vulnerable≈vulnerability 등.
    # "framework-dependency-in-domain" → {frame, depen, domai}
    return {
        _SYN.get(t[:5], t[:5])
        for t in _norm(s).replace("_", "-").split("-")
        if t and t not in _STOP
    }


def _cat_similar(a: str, b: str, threshold: float = 0.5) -> bool:
    # 리뷰어가 같은 결함을 다르게 명명해도(예: domain-layer-framework-dependency
    # ↔ framework-dependency-in-domain) 토큰 자카드로 매칭.
    ta, tb = _tokens(a), _tokens(b)
    if not ta or not tb:
        return False
    return len(ta & tb) / len(ta | tb) >= threshold


def _cat_overlap(a: str, b: str) -> bool:
    # 공유 stem 이 하나라도 있는가 (약한 category 신호).
    return bool(_tokens(a) & _tokens(b))


def _sev_close(a: str, b: str) -> bool:
    # severity 표기 차이(±1)는 같은 결함으로 본다 (high↔medium 등).
    sa, sb = _SEV.get(_norm(a), 0), _SEV.get(_norm(b), 0)
    return bool(sa and sb and abs(sa - sb) <= 1)


def load_expected(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text("utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def load_findings(path: Path) -> list[dict]:
    data = json.loads(path.read_text("utf-8"))
    return data if isinstance(data, list) else data.get("findings", [])


def matches(exp: dict, f: dict) -> bool:
    if _norm(exp["area"]) != _norm(f.get("area")):
        return False
    ec, fc = exp.get("category", ""), f.get("category", "")
    if not _tokens(ec) or not _tokens(fc):
        # category 정보 없음 → severity 근접으로만 (드묾)
        return _sev_close(exp.get("severity", ""), f.get("severity", ""))
    # 강한 category 일치(자카드≥0.5) → 매칭
    if _cat_similar(ec, fc):
        return True
    # 약한 category 일치(공유 stem≥1) + severity 근접 → 표기차 흡수
    if _cat_overlap(ec, fc) and _sev_close(
        exp.get("severity", ""), f.get("severity", "")
    ):
        return True
    # 순수 severity 매칭 금지: category 신호 0 이면 다른 결함으로 본다(과관대 방지)
    return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", required=True, help="리뷰 실행 findings JSON")
    ap.add_argument(
        "--expected",
        default=str(Path(__file__).parent / "expected.jsonl"),
        help="정답 manifest",
    )
    args = ap.parse_args()

    expected = load_expected(Path(args.expected))
    findings = load_findings(Path(args.findings))

    # 파일 basename → 발견 목록
    by_file: dict[str, list[dict]] = {}
    for f in findings:
        by_file.setdefault(_basename(f.get("file", "")), []).append(f)

    tp = fn = fp = 0
    misses: list[str] = []
    false_positives: list[str] = []

    matched_ids: set[int] = set()
    for row in expected:
        base = _basename(row["file"])
        cands = by_file.get(base, [])
        for exp in row["expected"]:
            hit = None
            for i, f in enumerate(cands):
                if id(f) in matched_ids:
                    continue
                if matches(exp, f):
                    hit = i
                    break
            if hit is not None:
                tp += 1
                matched_ids.add(id(cands[hit]))
            else:
                fn += 1
                misses.append(f"{base}: {exp['area']}/{exp.get('category')}")
        # clean 파일: 매칭 안 된 모든 발견 = FP
        if row.get("clean"):
            for f in cands:
                fp += 1
                false_positives.append(
                    f"{base}: {f.get('area')}/{f.get('category')} (clean 파일)"
                )

    # clean 아닌 파일에서 정답과 매칭 안 된 잉여 발견도 FP 로 집계
    for row in expected:
        if row.get("clean"):
            continue
        base = _basename(row["file"])
        for f in by_file.get(base, []):
            if id(f) not in matched_ids:
                fp += 1
                false_positives.append(
                    f"{base}: {f.get('area')}/{f.get('category')} (잉여)"
                )

    precision = tp / (tp + fp) if (tp + fp) else 1.0
    recall = tp / (tp + fn) if (tp + fn) else 1.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0

    report = {
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "precision": round(precision, 3),
        "recall": round(recall, 3),
        "f1": round(f1, 3),
        "misses": misses,
        "false_positives": false_positives,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))

    # 회귀 게이트: 권장 임계 (조정 가능)
    ok = precision >= 0.8 and recall >= 0.8
    print(
        ("PASS" if ok else "FAIL")
        + f" (precision≥0.8·recall≥0.8) — P={precision:.2f} R={recall:.2f}",
        file=sys.stderr,
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
