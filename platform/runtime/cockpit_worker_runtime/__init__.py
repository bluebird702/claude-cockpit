"""claude-cockpit 에이전트 직원 공통 런타임.

모든 worker 봇이 공유하는 뼈대. 각 worker 는 자신의 AGENT.md 만 채우면
이 런타임이 Slack Bolt + Claude Agent SDK + 루프 방어 + 예산 + HITL + 감사
전부를 조립해 기동합니다.

주요 모듈:
- agent_md: AGENT.md YAML frontmatter Pydantic 스키마
- bolt_adapter: Slack Bolt AsyncApp Socket Mode 래퍼 + SlackReactionAwaiter
- claude_adapter: Anthropic AsyncClient 래퍼, prompt caching 블록 조립
- loop_guard: 5중 루프 방어
- budget: 토큰/USD 누적 추적
- memory: 불변/가변 메모리 분리
- hitl: 리액션 기반 승인 게이트
- audit: JSONL append-only 감사 로그
- commands: /status /pause /resume /budget /trace 공통 핸들러
- delegation: 리더 → 서브워커 Task 툴 위임 (Sprint 3)
- secrets: macOS Keychain 우선 시크릿 로더
- tools.github_app: GitHub App installation token + PR 작업 (Plan B)
- entrypoint: 전체 조립기 + 메인 루프

Sprint 1: CTO 봇 1 호 실제 동작. app_mention → Claude 응답.
"""

__version__ = "0.1.0"

from cockpit_worker_runtime.agent_md import AgentMD
from cockpit_worker_runtime.budget import Budget, BudgetExceeded
from cockpit_worker_runtime.loop_guard import LoopGuard, LoopGuardTripped
from cockpit_worker_runtime.memory import Memory

__all__ = [
    "AgentMD",
    "Budget",
    "BudgetExceeded",
    "LoopGuard",
    "LoopGuardTripped",
    "Memory",
]
