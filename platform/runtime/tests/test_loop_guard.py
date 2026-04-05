"""루프 방어 5 층 단위 테스트."""

from __future__ import annotations

import pytest

from cockpit_worker_runtime.agent_md import LoopGuardLimits
from cockpit_worker_runtime.loop_guard import LoopGuard, LoopGuardTripped


def _fresh_guard(**overrides: object) -> LoopGuard:
    limits_kwargs = {
        "max_chain_depth": 3,
        "requests_per_hour": 60,
        "ignore_other_bots": True,
    }
    limits_kwargs.update(overrides)
    return LoopGuard(
        worker_name="test-bot",
        worker_slack_user_id="U_SELF",
        limits=LoopGuardLimits(**limits_kwargs),  # type: ignore[arg-type]
        turns_per_thread_cap=5,
        allowlisted_bot_ids=frozenset({"U_ALLOWED_BOT"}),
    )


class TestLayer1SelfInitiation:
    def test_self_mention_rejected(self) -> None:
        guard = _fresh_guard()
        with pytest.raises(LoopGuardTripped) as exc:
            guard.check_incoming_mention(
                sender_user_id="U_SELF",
                sender_is_bot=True,
                thread_id="T1",
            )
        assert exc.value.layer == "self_initiation"


class TestLayer2TurnCap:
    def test_turn_cap_enforced(self) -> None:
        guard = _fresh_guard()
        # 5 턴까진 OK
        for _ in range(5):
            guard.tick_turn("T1")
        # 6 번째 초과
        with pytest.raises(LoopGuardTripped) as exc:
            guard.tick_turn("T1")
        assert exc.value.layer == "turn_cap"


class TestLayer3ChainDepth:
    def test_chain_depth_exceeded(self) -> None:
        guard = _fresh_guard(max_chain_depth=3)
        with pytest.raises(LoopGuardTripped) as exc:
            guard.check_incoming_mention(
                sender_user_id="U_HUMAN",
                sender_is_bot=False,
                thread_id="T1",
                chain_depth_hint=3,  # 초과
            )
        assert exc.value.layer == "chain_depth"

    def test_chain_depth_under_limit_ok(self) -> None:
        guard = _fresh_guard(max_chain_depth=3)
        guard.check_incoming_mention(
            sender_user_id="U_HUMAN",
            sender_is_bot=False,
            thread_id="T1",
            chain_depth_hint=2,
        )  # 예외 없음


class TestLayer4BotIgnore:
    def test_non_allowlisted_bot_rejected(self) -> None:
        guard = _fresh_guard()
        with pytest.raises(LoopGuardTripped) as exc:
            guard.check_incoming_mention(
                sender_user_id="U_OTHER_BOT",
                sender_is_bot=True,
                thread_id="T1",
            )
        assert exc.value.layer == "bot_ignore"

    def test_allowlisted_bot_ok(self) -> None:
        guard = _fresh_guard()
        guard.check_incoming_mention(
            sender_user_id="U_ALLOWED_BOT",
            sender_is_bot=True,
            thread_id="T1",
        )

    def test_human_always_ok(self) -> None:
        guard = _fresh_guard()
        guard.check_incoming_mention(
            sender_user_id="U_HUMAN",
            sender_is_bot=False,
            thread_id="T1",
        )


class TestLayer5RateLimit:
    def test_rate_limit_trips(self) -> None:
        guard = _fresh_guard(requests_per_hour=3)
        for _ in range(3):
            guard.check_incoming_mention(
                sender_user_id="U_HUMAN",
                sender_is_bot=False,
                thread_id="T1",
            )
        with pytest.raises(LoopGuardTripped) as exc:
            guard.check_incoming_mention(
                sender_user_id="U_HUMAN",
                sender_is_bot=False,
                thread_id="T2",
            )
        assert exc.value.layer == "rate_limit"
