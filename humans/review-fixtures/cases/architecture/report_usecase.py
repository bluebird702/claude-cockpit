"""월간 정산 리포트 생성 유스케이스."""

import psycopg2

from app.domain.report import SettlementReport

DSN = "postgresql://app@db.internal:5432/billing"


class GenerateSettlementReport:
    def generate(self, month: str) -> SettlementReport:
        conn = psycopg2.connect(DSN)
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT merchant_id, SUM(amount) FROM settlements"
                " WHERE month = %s GROUP BY merchant_id",
                (month,),
            )
            rows = cur.fetchall()
        finally:
            conn.close()
        return SettlementReport.from_rows(month=month, rows=rows)
