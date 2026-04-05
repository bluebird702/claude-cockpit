"""예산 추적 — 토큰·USD 누적 + 일일·스레드 캡.

4층 방어의 1층. 각 worker 의 `AGENT.md` 에 선언된 `budget.usd_per_day`,
`budget.tokens_per_thread` 를 강제합니다. 초과 시 `BudgetExceeded` 예외
발생 → runtime 이 받아서 Slack 알림 + 자동 halt.

영속화: ~/.cockpit-agents/<worker>/budget.json (일일 리셋은 UTC 자정)
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from cockpit_worker_runtime.agent_md import Budget as BudgetConfig

# Claude Sonnet 4.6 기준 가격 (입력/출력, USD/1M tokens) — 2026-04 기준
# 최신화 필요 시 Anthropic 콘솔 참조
MODEL_PRICING: dict[str, tuple[float, float]] = {
    "claude-opus-4-6": (15.0, 75.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-haiku-4-5": (0.80, 4.0),
}


class BudgetExceeded(Exception):
    """봇 예산이 일일 또는 스레드 캡을 초과했을 때."""


class BudgetTracker:
    """worker 단위 예산 추적기.

    - 일일 캡: UTC 자정에 자동 리셋
    - 스레드 캡: 스레드 ID 로 그룹, 명시적 `reset_thread` 호출 필요
    - 디스크 영속화로 재시작에도 유지
    """

    def __init__(
        self,
        worker_name: str,
        config: BudgetConfig,
        state_path: Path | None = None,
    ) -> None:
        self.worker_name = worker_name
        self.config = config
        if state_path is None:
            state_path = Path.home() / ".cockpit-agents" / worker_name / "budget.json"
        self.state_path = state_path
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        self._state = self._load()

    def _load(self) -> dict[str, object]:
        if not self.state_path.exists():
            return self._fresh_state()
        try:
            data: dict[str, object] = json.loads(self.state_path.read_text("utf-8"))
        except (json.JSONDecodeError, OSError):
            return self._fresh_state()
        # 일일 리셋 체크
        if data.get("day") != self._today():
            return self._fresh_state()
        return data

    def _fresh_state(self) -> dict[str, object]:
        return {
            "day": self._today(),
            "usd_today": 0.0,
            "tokens_today": 0,
            "threads": {},  # thread_id → {"tokens": int, "usd": float}
        }

    @staticmethod
    def _today() -> str:
        return datetime.now(timezone.utc).strftime("%Y-%m-%d")

    def _save(self) -> None:
        self.state_path.write_text(
            json.dumps(self._state, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def estimate_cost(self, *, model: str, input_tokens: int, output_tokens: int) -> float:
        """모델·토큰 수로 USD 추정."""
        if model not in MODEL_PRICING:
            raise ValueError(f"알 수 없는 모델: {model}")
        in_rate, out_rate = MODEL_PRICING[model]
        return (input_tokens / 1_000_000) * in_rate + (output_tokens / 1_000_000) * out_rate

    def charge(
        self,
        *,
        thread_id: str,
        model: str,
        input_tokens: int,
        output_tokens: int,
    ) -> float:
        """사용량 누적. 반환값은 이번 호출 USD.

        캡 초과 시 `BudgetExceeded`.
        """
        cost = self.estimate_cost(
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )
        total_tokens = input_tokens + output_tokens

        # 상태 갱신
        self._state["usd_today"] = float(self._state.get("usd_today", 0.0)) + cost
        self._state["tokens_today"] = int(self._state.get("tokens_today", 0)) + total_tokens

        threads: dict[str, dict[str, float]] = self._state.setdefault("threads", {})  # type: ignore[assignment]
        thread = threads.setdefault(thread_id, {"tokens": 0, "usd": 0.0})
        thread["tokens"] = float(thread.get("tokens", 0)) + total_tokens
        thread["usd"] = float(thread.get("usd", 0.0)) + cost

        self._save()
        self._enforce_caps(thread_id=thread_id)
        return cost

    def _enforce_caps(self, *, thread_id: str) -> None:
        if float(self._state["usd_today"]) >= self.config.usd_per_day:
            raise BudgetExceeded(
                f"{self.worker_name}: 일일 USD 캡 초과 "
                f"({self._state['usd_today']:.4f} / {self.config.usd_per_day})"
            )

        threads: dict[str, dict[str, float]] = self._state.get("threads", {})  # type: ignore[assignment]
        thread = threads.get(thread_id, {})
        if thread.get("tokens", 0) >= self.config.tokens_per_thread:
            raise BudgetExceeded(
                f"{self.worker_name}: 스레드 {thread_id} 토큰 캡 초과 "
                f"({thread.get('tokens', 0)} / {self.config.tokens_per_thread})"
            )

    def reset_thread(self, thread_id: str) -> None:
        """스레드 완료 시 토큰 카운터 리셋 (USD 는 일일 기준 유지)."""
        threads: dict[str, dict[str, float]] = self._state.get("threads", {})  # type: ignore[assignment]
        threads.pop(thread_id, None)
        self._save()

    def status(self) -> dict[str, float | int]:
        """/budget 슬래시 커맨드 응답용."""
        return {
            "usd_today": round(float(self._state.get("usd_today", 0.0)), 4),
            "usd_cap": self.config.usd_per_day,
            "tokens_today": int(self._state.get("tokens_today", 0)),
            "active_threads": len(self._state.get("threads", {})),  # type: ignore[arg-type]
        }


__all__ = ["BudgetTracker", "BudgetExceeded", "MODEL_PRICING"]


# 하위 호환: __init__.py 가 Budget 이라는 이름을 export
Budget = BudgetTracker
