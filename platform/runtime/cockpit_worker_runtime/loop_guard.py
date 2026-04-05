"""루프 방어 — 5중 방어층.

봇이 봇을 부르고 그 봇이 다시 원래 봇을 부르는 무한 루프를 막습니다.
하나라도 뚫리면 주말 아침 $$$$ 청구서가 날아옵니다.

방어 5 층:
1. self_initiation_guard  — 자기가 자기를 멘션하면 거부
2. turn_cap              — 스레드당 최대 턴 수
3. chain_depth_guard     — 봇 → 봇 체인 깊이 제한
4. bot_ignore_default    — 다른 봇 메시지 기본 무시 (allowlist 제외)
5. rate_limit            — 시간당 요청 수 제한

어느 하나라도 발동하면 `LoopGuardTripped` 예외 → runtime 이 받아서
Slack #agent-ops 알림 + 해당 스레드 중단.
"""

from __future__ import annotations

import time
from collections import deque
from dataclasses import dataclass, field

from cockpit_worker_runtime.agent_md import LoopGuardLimits


class LoopGuardTripped(Exception):
    """5 중 방어 중 하나가 발동."""

    def __init__(self, layer: str, detail: str) -> None:
        super().__init__(f"[loop-guard/{layer}] {detail}")
        self.layer = layer
        self.detail = detail


@dataclass
class _ThreadState:
    turns: int = 0
    chain_depth: int = 0


@dataclass
class LoopGuard:
    """worker 인스턴스당 하나.

    thread_state 는 메모리 내. 프로세스 재시작 시 리셋 (의도된 동작 —
    오래된 스레드는 새 세션에서 깊이 0 부터 재시작).
    """

    worker_name: str
    worker_slack_user_id: str
    limits: LoopGuardLimits
    turns_per_thread_cap: int
    allowlisted_bot_ids: frozenset[str] = frozenset()

    _thread_state: dict[str, _ThreadState] = field(default_factory=dict)
    _request_timestamps: deque[float] = field(default_factory=deque)

    def check_incoming_mention(
        self,
        *,
        sender_user_id: str,
        sender_is_bot: bool,
        thread_id: str,
        chain_depth_hint: int = 0,
    ) -> None:
        """봇이 멘션을 받았을 때 첫 방어선. 문제가 있으면 LoopGuardTripped.

        chain_depth_hint 는 상위 봇이 delegation.py 로 넘겨준 값.
        직접 사람이 부른 경우는 0.
        """
        # Layer 1: self-initiation
        if sender_user_id == self.worker_slack_user_id:
            raise LoopGuardTripped(
                "self_initiation",
                f"{self.worker_name} 가 자기 자신을 멘션함",
            )

        # Layer 4: bot_ignore_default
        if sender_is_bot and self.limits.ignore_other_bots:
            if sender_user_id not in self.allowlisted_bot_ids:
                raise LoopGuardTripped(
                    "bot_ignore",
                    f"봇 발신자 {sender_user_id} 가 allowlist 에 없음",
                )

        # Layer 5: rate limit (직전 1 시간)
        now = time.monotonic()
        cutoff = now - 3600
        while self._request_timestamps and self._request_timestamps[0] < cutoff:
            self._request_timestamps.popleft()
        if len(self._request_timestamps) >= self.limits.requests_per_hour:
            raise LoopGuardTripped(
                "rate_limit",
                f"시간당 요청 {self.limits.requests_per_hour} 초과",
            )
        self._request_timestamps.append(now)

        # Layer 3: chain depth
        state = self._thread_state.setdefault(thread_id, _ThreadState())
        state.chain_depth = max(state.chain_depth, chain_depth_hint)
        if state.chain_depth >= self.limits.max_chain_depth:
            raise LoopGuardTripped(
                "chain_depth",
                f"스레드 {thread_id} 체인 깊이 {state.chain_depth} >= "
                f"{self.limits.max_chain_depth}",
            )

    def tick_turn(self, thread_id: str) -> None:
        """워커가 실제로 한 턴 응답할 때 호출. Layer 2 (turn_cap) 검사."""
        state = self._thread_state.setdefault(thread_id, _ThreadState())
        state.turns += 1
        if state.turns > self.turns_per_thread_cap:
            raise LoopGuardTripped(
                "turn_cap",
                f"스레드 {thread_id} 턴 수 {state.turns} > {self.turns_per_thread_cap}",
            )

    def reset_thread(self, thread_id: str) -> None:
        self._thread_state.pop(thread_id, None)
