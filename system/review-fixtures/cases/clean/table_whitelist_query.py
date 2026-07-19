"""리포트 대상 테이블별 집계 — 식별자는 고정 매핑, 값은 파라미터."""

from app.db import session

REPORT_TABLES = {
    "orders": "orders",
    "payments": "payments",
    "refunds": "refunds",
}


def count_since(report_kind: str, since: str) -> int:
    table = REPORT_TABLES[report_kind]
    row = session.execute(
        f"SELECT count(*) AS cnt FROM {table} WHERE created_at >= :since",
        {"since": since},
    ).fetchone()
    return row.cnt
