"""공통 슬래시 커맨드 핸들러.

모든 worker 는 아래 명령을 동일한 프로토콜로 지원합니다:

  /status            — 현재 상태, 활성 스레드, 업타임
  /pause             — 즉시 일시정지 (새 요청 거부, 진행 중은 완료)
  /resume            — 재개
  /budget            — 예산 소진 현황
  /trace <thread_id> — 특정 스레드의 최근 감사 로그 tail

이 모듈은 커맨드 → 응답 문자열 매핑만 담당. 실제 Slack 전송은 bolt_adapter.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum

from cockpit_worker_runtime.budget import BudgetTracker


class WorkerState(Enum):
    RUNNING = "running"
    PAUSED = "paused"
    HALTED = "halted"  # 예산/루프 방어로 강제 정지


@dataclass
class WorkerStatus:
    worker_name: str
    state: WorkerState
    started_at: datetime
    active_threads: int

    def uptime_seconds(self) -> float:
        return (datetime.now(timezone.utc) - self.started_at).total_seconds()


class CommandHandler:
    """worker 인스턴스당 하나. 상태·예산·루프가드를 주입받아 응답 생성."""

    def __init__(
        self,
        worker_name: str,
        budget: BudgetTracker,
    ) -> None:
        self.worker_name = worker_name
        self.budget = budget
        self._state = WorkerState.RUNNING
        self._started_at = datetime.now(timezone.utc)
        self._active_threads: set[str] = set()

    # ─────────────────── 상태 관리
    def track_thread_start(self, thread_id: str) -> None:
        self._active_threads.add(thread_id)

    def track_thread_end(self, thread_id: str) -> None:
        self._active_threads.discard(thread_id)

    def halt(self) -> None:
        self._state = WorkerState.HALTED

    @property
    def state(self) -> WorkerState:
        return self._state

    def is_accepting_requests(self) -> bool:
        return self._state == WorkerState.RUNNING

    # ─────────────────── 명령 핸들러
    def handle_status(self) -> str:
        status = WorkerStatus(
            worker_name=self.worker_name,
            state=self._state,
            started_at=self._started_at,
            active_threads=len(self._active_threads),
        )
        uptime_min = status.uptime_seconds() / 60
        return (
            f"*{self.worker_name}* · `{self._state.value}`\n"
            f"• 업타임: {uptime_min:.1f} min\n"
            f"• 활성 스레드: {status.active_threads}"
        )

    def handle_pause(self) -> str:
        if self._state == WorkerState.HALTED:
            return f"`{self.worker_name}` 는 halted 상태 — /resume 으로는 복구 불가. 재배포 필요."
        self._state = WorkerState.PAUSED
        return f"⏸ `{self.worker_name}` 일시정지. 새 요청 거부합니다."

    def handle_resume(self) -> str:
        if self._state == WorkerState.HALTED:
            return f"`{self.worker_name}` 는 halted — /resume 불가. 재배포 필요."
        self._state = WorkerState.RUNNING
        return f"▶ `{self.worker_name}` 재개."

    def handle_budget(self) -> str:
        s = self.budget.status()
        return (
            f"*{self.worker_name} 예산*\n"
            f"• 오늘 USD: ${s['usd_today']} / ${s['usd_cap']}\n"
            f"• 오늘 토큰: {s['tokens_today']:,}\n"
            f"• 활성 스레드: {s['active_threads']}"
        )
