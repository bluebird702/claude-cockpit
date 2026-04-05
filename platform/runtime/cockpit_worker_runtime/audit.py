"""감사 로그 — JSONL append-only.

모든 worker 의 모든 의사결정 포인트는 여기를 통과해야 합니다.
PII 로깅 금지 (core/standards/management/security.md).

파일 위치: ~/.cockpit-agents/<worker-name>/audit.jsonl
각 라인은 독립된 JSON 객체. tail -f 로 실시간 관찰 가능.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import structlog

log = structlog.get_logger(__name__)


class AuditLogger:
    """JSONL append-only 감사 로거.

    - 동시 기록은 append 시스템콜의 원자성에 의존 (Linux/macOS 모두 안전)
    - 파일은 자동 생성, 디렉토리도 자동 생성
    - 전송 가능 필드: worker, thread_id, tool, tokens, usd, decision
    - 금지 필드: 사용자 메시지 원문, 이메일, 토큰 값
    """

    def __init__(self, worker_name: str, log_path: Path | None = None) -> None:
        self.worker_name = worker_name
        if log_path is None:
            log_path = Path.home() / ".cockpit-agents" / worker_name / "audit.jsonl"
        self.log_path = log_path
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log_event(
        self,
        event: str,
        *,
        thread_id: str | None = None,
        tool: str | None = None,
        tokens: int | None = None,
        usd: float | None = None,
        decision: str | None = None,
        extra: dict[str, Any] | None = None,
    ) -> None:
        """감사 이벤트 한 줄 append.

        extra 는 임의 필드지만 PII 포함 금지 — 호출자 책임.
        """
        # 주의: "event" 는 structlog 의 예약 키이므로 JSONL 에선 audit_event 로 저장.
        record: dict[str, Any] = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "worker": self.worker_name,
            "audit_event": event,
        }
        if thread_id is not None:
            record["thread_id"] = thread_id
        if tool is not None:
            record["tool"] = tool
        if tokens is not None:
            record["tokens"] = tokens
        if usd is not None:
            record["usd"] = round(usd, 6)
        if decision is not None:
            record["decision"] = decision
        if extra:
            record["extra"] = extra

        line = json.dumps(record, ensure_ascii=False, separators=(",", ":"))
        with self.log_path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")

        log.debug("audit", **record)
