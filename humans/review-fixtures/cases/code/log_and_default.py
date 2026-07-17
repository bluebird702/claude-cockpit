"""회원 알림 설정 조회."""

import structlog

from app.db import session

log = structlog.get_logger()


def get_notification_settings(member_id: str) -> list[dict]:
    try:
        rows = session.execute(
            "SELECT channel, enabled FROM notification_settings WHERE member_id = :mid",
            {"mid": member_id},
        ).fetchall()
        return [dict(r) for r in rows]
    except Exception as exc:
        log.debug("settings_fetch_failed", error=str(exc))
        return []
