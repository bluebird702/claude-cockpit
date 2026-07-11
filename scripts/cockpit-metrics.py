#!/usr/bin/env python3
"""cockpit-metrics — 플라이휠 기어2(시스템 계측) + 기어1 승격 후보 자동 탐지.

docs/review/ledger.jsonl (+ --ledger 로 프로젝트 원장)에서 메타 지표를 계산해
docs/process/cockpit-metrics.jsonl 에 스냅샷을 append 한다. 동시에 승격 자격
(안정 키가 N개↑ 스냅샷에서 open, 또는 2+ 프로젝트 등장)을 만족하는 후보를 출력해
/review:promote 로 넘길 수 있게 한다. **적용은 사람** — 이 스크립트는 계측·넛지만.

사용:
    python3 scripts/cockpit-metrics.py                       # 계측 + 기록
    python3 scripts/cockpit-metrics.py --check               # 출력만(기록 안 함)
    python3 scripts/cockpit-metrics.py --ledger <프로젝트 원장> ...   # cross-project
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LEDGER = os.path.join(ROOT, "docs", "review", "ledger.jsonl")
OUT = os.path.join(ROOT, "docs", "process", "cockpit-metrics.jsonl")
PROMOTE_THRESHOLD = 3  # 안정 키가 N개↑ 스냅샷에 open → 승격 후보 (flywheel 기어1)


def load_ledger(path: str) -> list[dict]:
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def keys_of(snap: dict) -> set[str]:
    return {f.get("key") for f in snap.get("findings", []) if f.get("key")}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--ledger", action="append", default=[], help="추가 프로젝트 원장(반복 가능)"
    )
    ap.add_argument("--check", action="store_true", help="append 없이 출력만")
    args = ap.parse_args()

    ledgers = [DEFAULT_LEDGER, *args.ledger]
    snaps_by_ledger = {p: load_ledger(p) for p in ledgers}
    cockpit_snaps = snaps_by_ledger.get(DEFAULT_LEDGER, [])
    if not any(snaps_by_ledger.values()):
        print("원장 없음 — 계측할 데이터가 없습니다.", file=sys.stderr)
        return 1

    # open-debt: 스냅샷별 open 발견 수 + 추세
    debt_trend = [len(keys_of(s)) for s in cockpit_snaps]
    open_debt = debt_trend[-1] if debt_trend else 0

    # 안정 키별 등장 스냅샷 수 (cockpit 원장)
    appear: Counter[str] = Counter()
    for s in cockpit_snaps:
        appear.update(keys_of(s))

    # 재발률: 사라졌던(fixed) 키가 이후 다시 등장(new)한 횟수
    recurrence = 0
    gone: set[str] = set()
    prev: set[str] = set()
    for s in cockpit_snaps:
        cur = keys_of(s)
        recurrence += len(cur & gone)
        gone |= prev - cur
        gone -= cur
        prev = cur

    # fire-rate: category 별 총 발견 수 (cross-ledger). 0 인 표준 규칙은 죽은 규칙 후보.
    # category 는 안정 키 `area:path:category:rule` 의 3번째 세그먼트에서 파싱
    # (원장 finding 은 별도 category 필드 없이 key 에 인코딩).
    def category_of(f: dict) -> str:
        if f.get("category"):
            return str(f["category"])
        parts = str(f.get("key", "")).split(":")
        return parts[2] if len(parts) >= 3 else ""

    fire: Counter[str] = Counter()
    for snaps in snaps_by_ledger.values():
        for s in snaps:
            for f in s.get("findings", []):
                cat = category_of(f)
                if cat:
                    fire.update([cat])

    # cross-project: 2개↑ 원장에 같은 키
    keycount: Counter[str] = Counter()
    for snaps in snaps_by_ledger.values():
        seen: set[str] = set()
        for s in snaps:
            seen |= keys_of(s)
        keycount.update(seen)
    cross_project = sorted(k for k, c in keycount.items() if c >= 2 and k)

    candidates = sorted(
        {k for k, c in appear.items() if c >= PROMOTE_THRESHOLD and k}
        | set(cross_project)
    )

    commit = ""
    try:
        commit = subprocess.run(
            ["git", "-C", ROOT, "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
    except OSError:
        pass

    snapshot = {
        "at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "commit": commit,
        "snapshots_analyzed": len(cockpit_snaps),
        "open_debt": open_debt,
        "open_debt_trend": debt_trend,
        "recurrence": recurrence,
        "fire_rate_top": fire.most_common(10),
        "promotion_candidates": candidates,
    }
    print(json.dumps(snapshot, ensure_ascii=False, indent=2))

    if candidates:
        print(
            f"\n승격 후보 {len(candidates)}건 (≥{PROMOTE_THRESHOLD}회 open 또는 2+프로젝트) "
            "→ /review:promote 로 검토:",
            file=sys.stderr,
        )
        for k in candidates:
            print(f"  - {k}", file=sys.stderr)

    if not args.check:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "a", encoding="utf-8") as f:
            f.write(json.dumps(snapshot, ensure_ascii=False) + "\n")
        print(f"\n기록: {os.path.relpath(OUT, ROOT)}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
