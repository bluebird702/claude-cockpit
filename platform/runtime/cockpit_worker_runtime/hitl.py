"""HITL (Human-in-the-loop) 승인 게이트.

봇이 위험한 액션 (PR 생성, 머지, 외부 발송, 프로덕션 배포 등) 을 수행하기 전
Slack 메시지에 리액션으로 승인을 받습니다. 타임아웃 내에 승인이 없으면 거절.

승인 방식:
- `:white_check_mark:` (✅) — 승인
- `:no_entry:` (⛔)        — 명시적 거절
- 타임아웃 (기본 10 분)   — 암묵적 거절

Sprint 0 에선 인터페이스만 정의. 실제 Slack 연동은 Sprint 1 에서 bolt_adapter
가 주입받아 사용.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Protocol


class ApprovalResult(Enum):
    APPROVED = "approved"
    REJECTED = "rejected"
    TIMEOUT = "timeout"


class ReactionAwaiter(Protocol):
    """Slack 리액션 대기 프로토콜. 실제 구현은 bolt_adapter 에서 제공."""

    async def await_reaction(
        self,
        *,
        channel: str,
        ts: str,
        timeout_seconds: int,
    ) -> ApprovalResult:
        ...


@dataclass
class HitlRequest:
    """HITL 요청 한 건.

    channel, ts 는 봇이 Slack 에 posted 메시지의 위치 (리액션 감지 대상).
    action 은 감사 로그용 사람 읽기 좋은 문자열.
    """

    channel: str
    ts: str
    action: str
    timeout_seconds: int = 600  # 10 분 기본


class HitlGate:
    """HITL 래퍼. AGENT.md 의 hitl.* 필드에 따라 어떤 액션에 게이트 걸릴지 결정."""

    def __init__(self, awaiter: ReactionAwaiter) -> None:
        self._awaiter = awaiter

    async def require(self, request: HitlRequest) -> ApprovalResult:
        """승인 대기. 결과는 호출자가 받아서 처리."""
        return await self._awaiter.await_reaction(
            channel=request.channel,
            ts=request.ts,
            timeout_seconds=request.timeout_seconds,
        )
