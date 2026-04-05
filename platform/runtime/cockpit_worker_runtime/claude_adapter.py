"""Claude Agent SDK 어댑터 — 구독 인증 재사용.

정책 (2026-04-05 확정, 영구):
  cockpit 워커 봇은 Anthropic API 직접 호출을 사용하지 않는다.
  Claude Code 의 로그인 세션(~/.claude/.credentials.json) 을 재사용하는
  `claude_agent_sdk` 만 사용한다. API key 도, 별도 과금도 없다.

책임:
1. AGENT.md 의 persona + memory-seed 를 단일 system prompt 로 조립
2. `claude_agent_sdk.query()` 스트림을 수집해 최종 텍스트 반환
3. ResultMessage 의 usage 를 Budget 에 위임 (cost_usd 가 0 일 수 있음 — 안전장치일 뿐)
4. 도구 사용(tools) 은 Sprint 1 에선 비활성, 이후 allowed_tools 로 확장

Budget 의 달러 캡은 SDK 방식에선 실효 0 (cost_usd 가 대부분 0 반환).
tokens_per_thread, turns_per_thread 캡은 여전히 유효 — 이상 동작 감지용.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

import structlog

from cockpit_worker_runtime.budget import BudgetTracker
from cockpit_worker_runtime.memory import LoadedMemory

if TYPE_CHECKING:  # pragma: no cover
    from cockpit_worker_runtime.agent_md import AgentMD

log = structlog.get_logger(__name__)


@dataclass
class ClaudeResponse:
    """Claude 응답 래퍼."""

    text: str
    model: str
    input_tokens: int
    output_tokens: int
    tool_uses: list[dict[str, Any]] = field(default_factory=list)
    stop_reason: str | None = None
    cost_usd: float = 0.0


@dataclass
class ClaudeAdapter:
    """Claude Agent SDK 래퍼.

    dry_run=True 면 SDK 호출 없이 stub 응답. 실제 기동 시에만 query() 호출.
    """

    worker_name: str
    agent: "AgentMD"
    budget: BudgetTracker
    memory: LoadedMemory
    persona_text: str = ""
    dry_run: bool = False

    def build_system_prompt(self) -> str:
        """시스템 프롬프트를 단일 문자열로 조립.

        SDK 가 자체적으로 prompt caching 을 처리하므로 블록 분할 불필요.
        회사명은 환경변수 COCKPIT_ORG_NAME 로 오버라이드 가능 (기본은 미지정).
        """
        parts: list[str] = []

        org_name = os.environ.get("COCKPIT_ORG_NAME", "")
        org_prefix = f"{org_name} 회사의 " if org_name else ""
        parts.append(
            f"당신은 {org_prefix}AI 직원 '{self.worker_name}' 입니다. "
            f"직함은 '{self.agent.role}' 이며, CEO 에게 직접 보고합니다."
        )

        if self.persona_text:
            parts.append("\n# 페르소나\n\n" + self.persona_text.strip())

        if self.memory.immutable_text:
            parts.append("\n# 메모리 시드\n\n" + self.memory.immutable_text.strip())

        parts.append(
            "\n# 응답 규칙\n\n"
            "- Slack 에 포스트되는 메시지입니다. 마크다운은 제한적으로만 사용.\n"
            "- 한 메시지는 4000자 이내. 더 길면 스레드로 분할.\n"
            "- 코드 블록은 ```언어``` 형식.\n"
            "- 긴 분석은 요약 먼저, 근거 후, 권장 액션 마지막.\n"
            "- 확실하지 않은 부분은 '추가 조사 필요' 로 명시.\n"
            "- PII/비밀값을 로그에 재인용하지 말 것."
        )

        return "\n".join(parts)

    async def complete(
        self,
        *,
        thread_id: str,
        user_text: str,
        model: str | None = None,
        max_tokens: int = 2048,  # SDK 가 자체 관리하지만 호환성 유지
        tools: list[dict[str, Any]] | None = None,  # Sprint 1 에선 사용 안 함
    ) -> ClaudeResponse:
        """단일 턴 호출. thread_id 는 Budget 과금/감사 키."""
        _ = max_tokens, tools  # 향후 사용
        chosen_model = model or self.agent.primary_model

        if self.dry_run:
            log.info(
                "claude.dry_run",
                worker=self.worker_name,
                thread=thread_id,
                model=chosen_model,
                input_chars=len(user_text),
            )
            return ClaudeResponse(
                text=f"[dry-run] {self.worker_name} 응답 stub",
                model=chosen_model,
                input_tokens=0,
                output_tokens=0,
                stop_reason="dry_run",
            )

        try:
            from claude_agent_sdk import ClaudeAgentOptions, query
        except ImportError as e:
            raise RuntimeError(
                "claude-agent-sdk 미설치. "
                "cockpit 은 Anthropic API 직접 호출을 쓰지 않습니다. "
                "poetry install 또는 pip install claude-agent-sdk 로 설치하세요."
            ) from e

        options = ClaudeAgentOptions(
            model=chosen_model,
            system_prompt=self.build_system_prompt(),
            permission_mode="bypassPermissions",  # 봇은 대화형 승인 없이 동작
            allowed_tools=[],  # Sprint 1: 순수 대화. tools 확장은 후속.
        )

        text_parts: list[str] = []
        input_tokens = 0
        output_tokens = 0
        cost_usd = 0.0
        stop_reason: str | None = None
        tool_uses: list[dict[str, Any]] = []

        try:
            async for message in query(prompt=user_text, options=options):
                # SDK 의 메시지 타입은 클래스 이름으로 구분 (SDK 버전에 따라
                # 다를 수 있어 isinstance 대신 덕 타이핑으로 안전하게 처리)
                msg_type = type(message).__name__

                if msg_type == "AssistantMessage":
                    for block in getattr(message, "content", []) or []:
                        block_type = type(block).__name__
                        if block_type == "TextBlock":
                            text_parts.append(getattr(block, "text", ""))
                        elif block_type == "ToolUseBlock":
                            tool_uses.append(
                                {
                                    "id": getattr(block, "id", ""),
                                    "name": getattr(block, "name", ""),
                                    "input": getattr(block, "input", {}),
                                }
                            )

                elif msg_type == "ResultMessage":
                    usage = getattr(message, "usage", None)
                    if usage is not None:
                        input_tokens = int(getattr(usage, "input_tokens", 0) or 0)
                        output_tokens = int(getattr(usage, "output_tokens", 0) or 0)
                    cost_usd = float(getattr(message, "total_cost_usd", 0.0) or 0.0)
                    stop_reason = getattr(message, "subtype", None) or "end_turn"

        except Exception:
            log.exception(
                "claude.sdk_error",
                worker=self.worker_name,
                thread=thread_id,
            )
            raise

        text = "\n".join(text_parts).strip() or "(응답 없음)"

        # Budget 과금 — SDK 가 usage 를 준 경우에만 유의미.
        # 토큰 카운트가 0 이어도 charge 호출은 해서 "턴 수" 는 추적.
        try:
            self.budget.charge(
                thread_id=thread_id,
                model=chosen_model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
            )
        except Exception:
            log.exception(
                "claude.budget_charge_failed",
                worker=self.worker_name,
                thread=thread_id,
            )
            raise

        log.info(
            "claude.response",
            worker=self.worker_name,
            thread=thread_id,
            model=chosen_model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cost_usd=round(cost_usd, 6),
            stop_reason=stop_reason,
            tool_uses=len(tool_uses),
        )

        return ClaudeResponse(
            text=text,
            model=chosen_model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            tool_uses=tool_uses,
            stop_reason=stop_reason,
            cost_usd=cost_usd,
        )

    async def complete_with_history(
        self,
        *,
        thread_id: str,
        messages: list[dict[str, Any]],
        model: str | None = None,
        max_tokens: int = 2048,
        tools: list[dict[str, Any]] | None = None,
    ) -> ClaudeResponse:
        """멀티턴 호환 래퍼.

        SDK 의 query() 는 단일 프롬프트를 받으므로 messages 의 마지막 user
        메시지만 추출해 전달. 정식 멀티턴은 Sprint 1.5+ 에서 SDK 의
        ClaudeSDKClient 를 사용해 확장.
        """
        last_user_text = ""
        for m in reversed(messages):
            if m.get("role") == "user":
                content = m.get("content", "")
                if isinstance(content, str):
                    last_user_text = content
                elif isinstance(content, list):
                    last_user_text = "\n".join(
                        block.get("text", "") for block in content if isinstance(block, dict)
                    )
                break

        return await self.complete(
            thread_id=thread_id,
            user_text=last_user_text,
            model=model,
            max_tokens=max_tokens,
            tools=tools,
        )
