"""예산 추적 단위 테스트."""

from __future__ import annotations

from pathlib import Path

import pytest

from cockpit_worker_runtime.agent_md import Budget as BudgetConfig
from cockpit_worker_runtime.budget import BudgetExceeded, BudgetTracker


def _tracker(tmp_path: Path, **overrides: float | int) -> BudgetTracker:
    defaults: dict[str, float | int] = {
        "usd_per_day": 1.0,
        "tokens_per_thread": 10_000,
        "turns_per_thread": 10,
    }
    defaults.update(overrides)
    return BudgetTracker(
        worker_name="test-bot",
        config=BudgetConfig(**defaults),  # type: ignore[arg-type]
        state_path=tmp_path / "budget.json",
    )


class TestCostEstimation:
    def test_sonnet_cost(self, tmp_path: Path) -> None:
        t = _tracker(tmp_path)
        cost = t.estimate_cost(
            model="claude-sonnet-4-6",
            input_tokens=1_000_000,
            output_tokens=0,
        )
        assert cost == pytest.approx(3.0)

    def test_unknown_model_raises(self, tmp_path: Path) -> None:
        t = _tracker(tmp_path)
        with pytest.raises(ValueError, match="알 수 없는 모델"):
            t.estimate_cost(model="gpt-5", input_tokens=100, output_tokens=100)


class TestCapEnforcement:
    def test_daily_usd_cap(self, tmp_path: Path) -> None:
        t = _tracker(tmp_path, usd_per_day=0.01)
        with pytest.raises(BudgetExceeded, match="일일 USD 캡"):
            t.charge(
                thread_id="T1",
                model="claude-sonnet-4-6",
                input_tokens=10_000,
                output_tokens=10_000,
            )

    def test_thread_token_cap(self, tmp_path: Path) -> None:
        t = _tracker(tmp_path, usd_per_day=100.0, tokens_per_thread=1_000)
        with pytest.raises(BudgetExceeded, match="토큰 캡"):
            t.charge(
                thread_id="T1",
                model="claude-haiku-4-5",
                input_tokens=500,
                output_tokens=600,  # 합 1100 > 1000
            )

    def test_thread_reset(self, tmp_path: Path) -> None:
        t = _tracker(tmp_path, usd_per_day=100.0, tokens_per_thread=1_000)
        # 900 누적 — 아직 캡 이하
        t.charge(
            thread_id="T1",
            model="claude-haiku-4-5",
            input_tokens=500,
            output_tokens=400,
        )
        t.reset_thread("T1")
        # 리셋 후엔 다시 0 부터
        t.charge(
            thread_id="T1",
            model="claude-haiku-4-5",
            input_tokens=500,
            output_tokens=400,
        )


class TestPersistence:
    def test_state_survives_restart(self, tmp_path: Path) -> None:
        t1 = _tracker(tmp_path, usd_per_day=100.0)
        t1.charge(
            thread_id="T1",
            model="claude-sonnet-4-6",
            input_tokens=1000,
            output_tokens=500,
        )
        status1 = t1.status()

        t2 = _tracker(tmp_path, usd_per_day=100.0)
        status2 = t2.status()
        assert status2["tokens_today"] == status1["tokens_today"]
