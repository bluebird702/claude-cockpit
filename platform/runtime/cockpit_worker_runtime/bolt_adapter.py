"""Slack Bolt Socket Mode 어댑터 — Sprint 1 실제 구현.

책임:
1. Slack Bolt AsyncApp 인스턴스 생성 (bot token + app-level token)
2. 이벤트 핸들러 등록 (app_mention, message, reaction_added)
3. 슬래시 커맨드 라우팅
4. 봇 메시지 포스트 래퍼 (스레드 안전)
5. HITL 리액션 대기 구현 (SlackReactionAwaiter)
6. Socket Mode 로 24/7 연결

환경변수:
  COCKPIT_<WORKER>_BOT_TOKEN  — xoxb-... (OAuth Bot token)
  COCKPIT_<WORKER>_APP_TOKEN  — xapp-... (App-level, Socket Mode 용)
  COCKPIT_<WORKER>_SIGNING_SECRET — (선택, Socket Mode 에선 불필요)

Keychain 에서 읽으려면 `BoltCredentials.from_keychain(worker_name)` 사용.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, Awaitable, Callable

if TYPE_CHECKING:  # pragma: no cover
    from cockpit_worker_runtime.agent_md import AgentMD

import structlog

from cockpit_worker_runtime.hitl import ApprovalResult, ReactionAwaiter
from cockpit_worker_runtime.secrets import get_keychain_secret

log = structlog.get_logger(__name__)

EventHandler = Callable[..., Awaitable[Any]]
CommandHandler = Callable[..., Awaitable[Any]]


@dataclass
class BoltCredentials:
    """Slack 앱 크레덴셜. 하드코딩 절대 금지, Keychain 또는 환경변수에서 로드."""

    bot_token: str  # xoxb-...
    app_token: str  # xapp-... (Socket Mode)
    signing_secret: str | None = None

    @classmethod
    def from_env(cls, worker_name: str) -> "BoltCredentials":
        """환경변수에서 로드. 키: COCKPIT_<WORKER>_BOT_TOKEN 등."""
        import os

        prefix = f"COCKPIT_{worker_name.upper().replace('-', '_')}"
        bot = os.environ.get(f"{prefix}_BOT_TOKEN")
        app = os.environ.get(f"{prefix}_APP_TOKEN")
        signing = os.environ.get(f"{prefix}_SIGNING_SECRET")
        if not bot or not app:
            raise RuntimeError(
                f"{prefix}_BOT_TOKEN 및 {prefix}_APP_TOKEN 환경변수 필요"
            )
        return cls(bot_token=bot, app_token=app, signing_secret=signing)

    @classmethod
    def from_keychain(cls, worker_name: str) -> "BoltCredentials":
        """macOS Keychain 에서 로드. 서비스 이름: cockpit/<worker>/<kind>."""
        bot = get_keychain_secret(f"cockpit/{worker_name}/bot-token")
        app = get_keychain_secret(f"cockpit/{worker_name}/app-token")
        signing = get_keychain_secret(f"cockpit/{worker_name}/signing-secret")
        if not bot or not app:
            raise RuntimeError(
                f"Keychain 에 cockpit/{worker_name}/bot-token · app-token 저장 필요. "
                f"저장: security add-generic-password -a $USER -s cockpit/{worker_name}/bot-token -w <xoxb-...>"
            )
        return cls(bot_token=bot, app_token=app, signing_secret=signing)

    @classmethod
    def load(cls, worker_name: str) -> "BoltCredentials":
        """Keychain 우선, 실패 시 환경변수 폴백."""
        try:
            return cls.from_keychain(worker_name)
        except RuntimeError:
            return cls.from_env(worker_name)


@dataclass
class BoltAdapter:
    """Slack Bolt AsyncApp 래퍼.

    dry_run=True 면 app 생성 없이 핸들러 등록만 검증 후 즉시 반환.
    """

    worker_name: str
    agent: "AgentMD"
    credentials: BoltCredentials | None = None
    dry_run: bool = False

    _event_handlers: dict[str, EventHandler] = field(default_factory=dict)
    _command_handlers: dict[str, CommandHandler] = field(default_factory=dict)
    _app: Any = None  # slack_bolt.async_app.AsyncApp
    _handler: Any = None  # AsyncSocketModeHandler
    _bot_user_id: str | None = None
    _reaction_awaiter: "SlackReactionAwaiter | None" = None

    def on_event(self, event_type: str) -> Callable[[EventHandler], EventHandler]:
        """@bolt.on_event("app_mention") 데코레이터."""

        def decorator(fn: EventHandler) -> EventHandler:
            self._event_handlers[event_type] = fn
            return fn

        return decorator

    def on_command(self, cmd: str) -> Callable[[CommandHandler], CommandHandler]:
        """@bolt.on_command("/status") 데코레이터."""

        def decorator(fn: CommandHandler) -> CommandHandler:
            self._command_handlers[cmd] = fn
            return fn

        return decorator

    @property
    def bot_user_id(self) -> str | None:
        return self._bot_user_id

    @property
    def reaction_awaiter(self) -> "SlackReactionAwaiter":
        """BoltAdapter 가 갖고 있는 ReactionAwaiter 반환 (HITL 용)."""
        if self._reaction_awaiter is None:
            self._reaction_awaiter = SlackReactionAwaiter()
        return self._reaction_awaiter

    async def post_message(
        self,
        *,
        channel: str,
        text: str,
        thread_ts: str | None = None,
    ) -> dict[str, Any]:
        """봇 메시지 포스트. 스레드가 주어지면 스레드에 답장."""
        if self._app is None:
            raise RuntimeError("bolt_adapter 가 start() 되기 전에는 post_message 불가")
        resp = await self._app.client.chat_postMessage(
            channel=channel,
            text=text,
            thread_ts=thread_ts,
        )
        return resp.data

    async def add_reaction(self, *, channel: str, timestamp: str, name: str) -> None:
        if self._app is None:
            raise RuntimeError("bolt_adapter 가 start() 되기 전에는 add_reaction 불가")
        try:
            await self._app.client.reactions_add(
                channel=channel,
                timestamp=timestamp,
                name=name,
            )
        except Exception:
            log.debug("reaction_add_failed", channel=channel, ts=timestamp, name=name)

    async def start_async(self) -> None:
        """Socket Mode 로 연결 시작 (async). dry_run 이면 즉시 반환."""
        if self.dry_run:
            log.info(
                "bolt.dry_run",
                worker=self.worker_name,
                events=list(self._event_handlers.keys()),
                commands=list(self._command_handlers.keys()),
            )
            return

        if self.credentials is None:
            self.credentials = BoltCredentials.load(self.worker_name)

        from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler
        from slack_bolt.async_app import AsyncApp

        self._app = AsyncApp(
            token=self.credentials.bot_token,
            signing_secret=self.credentials.signing_secret,
        )

        # bot_user_id 조회 (self-initiation 가드에 사용)
        try:
            auth = await self._app.client.auth_test()
            self._bot_user_id = auth["user_id"]
            log.info("bolt.auth", worker=self.worker_name, bot_user_id=self._bot_user_id)
        except Exception:
            log.exception("bolt.auth_failed", worker=self.worker_name)
            raise

        # 이벤트 핸들러 등록
        for event_type, handler in self._event_handlers.items():
            self._app.event(event_type)(handler)
            log.debug("bolt.event_registered", type=event_type)

        # 슬래시 커맨드 등록
        for cmd, handler in self._command_handlers.items():
            self._app.command(cmd)(handler)
            log.debug("bolt.command_registered", cmd=cmd)

        # ReactionAwaiter 가 reaction_added 이벤트를 받도록 자동 등록
        awaiter = self.reaction_awaiter

        @self._app.event("reaction_added")
        async def _on_reaction(event: dict[str, Any], **_: Any) -> None:
            await awaiter.on_reaction_event(event)

        self._handler = AsyncSocketModeHandler(self._app, self.credentials.app_token)
        log.info("bolt.connecting", worker=self.worker_name)
        await self._handler.start_async()

    def start(self) -> None:
        """sync 래퍼. entrypoint.py 가 호출."""
        if self.dry_run:
            log.info(
                "bolt.dry_run",
                worker=self.worker_name,
                events=list(self._event_handlers.keys()),
                commands=list(self._command_handlers.keys()),
            )
            return
        asyncio.run(self.start_async())


class SlackReactionAwaiter:
    """Slack 리액션 기반 승인 대기자.

    bolt_adapter 가 reaction_added 이벤트를 받을 때마다 `on_reaction_event` 를 호출.
    HITL 이 `await_reaction` 으로 특정 (channel, ts) 에 대한 리액션을 대기.
    """

    APPROVE_EMOJIS = frozenset({"white_check_mark", "+1", "heavy_check_mark"})
    REJECT_EMOJIS = frozenset({"no_entry", "x", "-1", "no_entry_sign"})

    def __init__(self) -> None:
        self._waiters: dict[tuple[str, str], asyncio.Future[ApprovalResult]] = {}

    async def await_reaction(
        self,
        *,
        channel: str,
        ts: str,
        timeout_seconds: int,
    ) -> ApprovalResult:
        key = (channel, ts)
        loop = asyncio.get_running_loop()
        fut: asyncio.Future[ApprovalResult] = loop.create_future()
        self._waiters[key] = fut

        try:
            return await asyncio.wait_for(fut, timeout=timeout_seconds)
        except asyncio.TimeoutError:
            log.info("hitl.timeout", channel=channel, ts=ts)
            return ApprovalResult.TIMEOUT
        finally:
            self._waiters.pop(key, None)

    async def on_reaction_event(self, event: dict[str, Any]) -> None:
        """reaction_added 이벤트 수신 시 호출."""
        item = event.get("item", {})
        if item.get("type") != "message":
            return
        key = (item.get("channel", ""), item.get("ts", ""))
        fut = self._waiters.get(key)
        if fut is None or fut.done():
            return

        reaction = event.get("reaction", "")
        if reaction in self.APPROVE_EMOJIS:
            fut.set_result(ApprovalResult.APPROVED)
            log.info("hitl.approved", channel=key[0], ts=key[1], by=event.get("user"))
        elif reaction in self.REJECT_EMOJIS:
            fut.set_result(ApprovalResult.REJECTED)
            log.info("hitl.rejected", channel=key[0], ts=key[1], by=event.get("user"))
        # 그 외 이모지는 무시


class NullReactionAwaiter(ReactionAwaiter):
    """dry-run 용 stub. 항상 APPROVED."""

    async def await_reaction(
        self,
        *,
        channel: str,
        ts: str,
        timeout_seconds: int,
    ) -> ApprovalResult:
        log.info(
            "hitl.null_awaiter",
            channel=channel,
            ts=ts,
            timeout=timeout_seconds,
            decision="auto-approved (dry-run)",
        )
        return ApprovalResult.APPROVED
