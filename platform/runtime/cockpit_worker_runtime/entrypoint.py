"""엔트리포인트 — AGENT.md 하나를 받아 전체 워커를 조립해 기동.

사용:
    python -m cockpit_worker_runtime.entrypoint workers/cto --dry-run
    python -m cockpit_worker_runtime.entrypoint workers/cto

조립 순서:
1. AGENT.md 파싱 + 일관성 검증
2. persona.md 로드
3. Memory(seed_dir + long_term_dir) 준비
4. BudgetTracker 초기화
5. LoopGuard 초기화
6. AuditLogger 초기화
7. ClaudeAdapter 조립 (memory + budget 주입)
8. BoltAdapter 조립 + 메시지 핸들러 등록
9. start() — Socket Mode 로 Slack 연결 또는 dry-run exit

Sprint 1: app_mention 한 턴 응답 + 공통 커맨드 (/status /pause /resume /budget) 동작.
Plan B: /review, /help 등 추가.
"""

from __future__ import annotations

import argparse
import asyncio
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import structlog

from cockpit_worker_runtime.agent_md import AgentMD
from cockpit_worker_runtime.audit import AuditLogger
from cockpit_worker_runtime.bolt_adapter import (
    BoltAdapter,
    BoltCredentials,
    NullReactionAwaiter,
)
from cockpit_worker_runtime.budget import BudgetExceeded, BudgetTracker
from cockpit_worker_runtime.claude_adapter import ClaudeAdapter
from cockpit_worker_runtime.commands import CommandHandler
from cockpit_worker_runtime.hitl import HitlGate, HitlRequest
from cockpit_worker_runtime.loop_guard import LoopGuard, LoopGuardTripped
from cockpit_worker_runtime.memory import Memory
from cockpit_worker_runtime.secrets import load_default_repo
from cockpit_worker_runtime.tools.github_app import (
    GitHubAppAuthError,
    GitHubAppClient,
    GitHubAppCredentials,
    parse_pr_reference,
)
from cockpit_worker_runtime.tools.pr_review import review_pull_request

log = structlog.get_logger(__name__)

# 멘션 정규식: <@U123ABC> 또는 <@U123ABC|name>
MENTION_RE = re.compile(r"<@([A-Z0-9]+)(\|[^>]+)?>")


@dataclass
class AssembledWorker:
    """조립된 worker 의 모든 컴포넌트 번들."""

    agent: AgentMD
    memory: Memory
    budget: BudgetTracker
    loop_guard: LoopGuard
    audit: AuditLogger
    commands: CommandHandler
    claude: ClaudeAdapter
    bolt: BoltAdapter
    hitl: HitlGate


def _strip_mentions(text: str, self_user_id: str | None = None) -> str:
    """메시지에서 <@U...> 멘션을 제거. 자기 자신만 제거해도 되지만 전부 제거가 안전."""
    return MENTION_RE.sub("", text).strip()


def assemble(worker_dir: Path, *, dry_run: bool = False) -> AssembledWorker:
    """worker 디렉토리를 읽어 컴포넌트를 전부 조립."""
    agent_md_path = worker_dir / "AGENT.md"
    agent = AgentMD.from_file(agent_md_path)

    consistency_errors = agent.validate_consistency()
    if consistency_errors:
        error_list = "\n  - ".join(consistency_errors)
        raise ValueError(f"AGENT.md 일관성 오류:\n  - {error_list}")

    persona_path = worker_dir / "persona.md"
    persona_text = persona_path.read_text("utf-8") if persona_path.exists() else ""

    memory_mgr = Memory(
        worker_name=agent.name,
        worker_root=worker_dir,
        config=agent.memory,
    )
    loaded_memory = memory_mgr.load()

    budget = BudgetTracker(worker_name=agent.name, config=agent.budget)

    loop_guard = LoopGuard(
        worker_name=agent.name,
        worker_slack_user_id="U_DRYRUN_PLACEHOLDER",  # start_async() 에서 실제 값 주입
        limits=agent.loop_guard,
        turns_per_thread_cap=agent.budget.turns_per_thread,
    )

    audit = AuditLogger(worker_name=agent.name)

    cmd_handler = CommandHandler(worker_name=agent.name, budget=budget)

    claude = ClaudeAdapter(
        worker_name=agent.name,
        agent=agent,
        budget=budget,
        memory=loaded_memory,
        persona_text=persona_text,
        dry_run=dry_run,
    )

    credentials: BoltCredentials | None = None
    if not dry_run:
        credentials = BoltCredentials.load(agent.name)

    bolt = BoltAdapter(
        worker_name=agent.name,
        agent=agent,
        credentials=credentials,
        dry_run=dry_run,
    )

    # HITL: dry-run 은 stub, 실제 기동은 bolt 의 reaction awaiter 사용
    hitl_awaiter = NullReactionAwaiter() if dry_run else bolt.reaction_awaiter
    hitl = HitlGate(awaiter=hitl_awaiter)

    # GitHub App 클라이언트 (옵션 — credentials 없으면 /review 비활성화)
    github_client: GitHubAppClient | None = None
    default_repo = load_default_repo(agent.name)
    if not dry_run and agent.github_app:
        try:
            gh_creds = GitHubAppCredentials.from_keychain(agent.name)
            github_client = GitHubAppClient(gh_creds)
            log.info("github_app.loaded", worker=agent.name, default_repo=default_repo)
        except GitHubAppAuthError as e:
            log.warning("github_app.unavailable", worker=agent.name, reason=str(e))

    _register_handlers(
        bolt=bolt,
        agent=agent,
        claude=claude,
        commands=cmd_handler,
        loop_guard=loop_guard,
        audit=audit,
        github=github_client,
        default_repo=default_repo,
        hitl=hitl,
    )

    audit.log_event("assembled", decision=f"dry_run={dry_run}")

    return AssembledWorker(
        agent=agent,
        memory=memory_mgr,
        budget=budget,
        loop_guard=loop_guard,
        audit=audit,
        commands=cmd_handler,
        claude=claude,
        bolt=bolt,
        hitl=hitl,
    )


def _register_handlers(
    *,
    bolt: BoltAdapter,
    agent: AgentMD,
    claude: ClaudeAdapter,
    commands: CommandHandler,
    loop_guard: LoopGuard,
    audit: AuditLogger,
    github: GitHubAppClient | None,
    default_repo: tuple[str, str] | None,
    hitl: HitlGate,
) -> None:
    """Slack 이벤트·커맨드 핸들러 등록."""

    worker_name = agent.name

    # ─── app_mention: 봇이 채널에서 멘션됐을 때
    @bolt.on_event("app_mention")
    async def on_mention(event: dict[str, Any], say: Any, **_: Any) -> None:
        channel = event.get("channel", "")
        user = event.get("user", "")
        text = event.get("text", "")
        thread_ts = event.get("thread_ts") or event.get("ts", "")
        is_bot = bool(event.get("bot_id"))

        # bot_user_id 갱신 (처음엔 placeholder 였을 수 있음)
        if bolt.bot_user_id and loop_guard.worker_slack_user_id != bolt.bot_user_id:
            loop_guard.worker_slack_user_id = bolt.bot_user_id

        try:
            loop_guard.check_incoming_mention(
                sender_user_id=user,
                sender_is_bot=is_bot,
                thread_id=thread_ts,
            )
        except LoopGuardTripped as e:
            audit.log_event("loop_guard_tripped", thread_id=thread_ts, decision=e.layer, extra={"detail": e.detail})
            log.warning("loop_guard_tripped", worker=worker_name, layer=e.layer, detail=e.detail)
            return

        if not commands.is_accepting_requests():
            await say(text="⏸ 현재 일시정지 상태입니다. `/resume` 으로 재개 가능합니다.", thread_ts=thread_ts)
            return

        clean_text = _strip_mentions(text, self_user_id=bolt.bot_user_id)
        if not clean_text:
            await say(text="네, 부르셨나요? 무엇을 도와드릴까요?", thread_ts=thread_ts)
            return

        audit.log_event(
            "mention_received",
            thread_id=thread_ts,
            extra={"channel": channel, "user": user, "chars": len(clean_text)},
        )

        # ─── /review 서브커맨드 감지 (멘션 본문에 "/review" 포함)
        if "/review" in clean_text.lower() or "pr#" in clean_text.lower() or "github.com" in clean_text.lower():
            handled = await _handle_review_request(
                text=clean_text,
                channel=channel,
                thread_ts=thread_ts,
                say=say,
                claude=claude,
                github=github,
                default_repo=default_repo,
                commands=commands,
                loop_guard=loop_guard,
                audit=audit,
                hitl=hitl,
            )
            if handled:
                return
            # 매칭 안 됐으면 일반 응답으로 폴백

        commands.track_thread_start(thread_ts)
        try:
            loop_guard.tick_turn(thread_ts)
            response = await claude.complete(
                thread_id=thread_ts,
                user_text=clean_text,
            )
        except BudgetExceeded as e:
            await say(text=f"🛑 예산 초과: {e}", thread_ts=thread_ts)
            commands.halt()
            audit.log_event("budget_exceeded", thread_id=thread_ts, decision=str(e))
            return
        except LoopGuardTripped as e:
            await say(text=f"🛑 루프 가드 발동: {e.layer}", thread_ts=thread_ts)
            audit.log_event("loop_guard_tripped", thread_id=thread_ts, decision=e.layer)
            return
        except Exception as e:
            log.exception("mention_handler_error", worker=worker_name, thread=thread_ts)
            await say(text=f"❗ 처리 중 오류: `{type(e).__name__}`", thread_ts=thread_ts)
            audit.log_event("error", thread_id=thread_ts, decision=type(e).__name__)
            return
        finally:
            commands.track_thread_end(thread_ts)

        audit.log_event(
            "response_sent",
            thread_id=thread_ts,
            tokens=response.input_tokens + response.output_tokens,
        )
        await say(text=response.text, thread_ts=thread_ts)

    # ─── 공통 슬래시 커맨드 (worker 이름 prefix — Slack 예약어 충돌 방지)
    # /status, /pause, /resume 은 Slack 이 이미 사용 중 (status emoji, DND 등)
    # 이므로 /{worker}-status 형식으로 네임스페이스 분리.
    cmd_prefix = f"/{worker_name}"

    @bolt.on_command(f"{cmd_prefix}-status")
    async def on_status(ack: Any, respond: Any, **_: Any) -> None:
        await ack()
        await respond(text=commands.handle_status())

    @bolt.on_command(f"{cmd_prefix}-pause")
    async def on_pause(ack: Any, respond: Any, **_: Any) -> None:
        await ack()
        await respond(text=commands.handle_pause())

    @bolt.on_command(f"{cmd_prefix}-resume")
    async def on_resume(ack: Any, respond: Any, **_: Any) -> None:
        await ack()
        await respond(text=commands.handle_resume())

    @bolt.on_command(f"{cmd_prefix}-budget")
    async def on_budget(ack: Any, respond: Any, **_: Any) -> None:
        await ack()
        await respond(text=commands.handle_budget())


async def _handle_review_request(
    *,
    text: str,
    channel: str,
    thread_ts: str,
    say: Any,
    claude: ClaudeAdapter,
    github: GitHubAppClient | None,
    default_repo: tuple[str, str] | None,
    commands: CommandHandler,
    loop_guard: LoopGuard,
    audit: AuditLogger,
    hitl: HitlGate,
) -> bool:
    """멘션 본문에서 PR 참조를 찾아 리뷰 실행. 처리했으면 True, 못 찾으면 False."""
    if github is None:
        await say(
            text=(
                "GitHub App 이 설정되지 않아 `/review` 를 실행할 수 없습니다. "
                "`cockpit/<worker>/github-app-id · github-private-key · github-installation-id` "
                "를 Keychain 에 등록해 주세요."
            ),
            thread_ts=thread_ts,
        )
        return True

    parsed = parse_pr_reference(text, default_repo=default_repo)
    if parsed is None:
        return False  # "/review" 는 있지만 PR 번호 못 찾음 → 일반 응답 폴백

    owner, repo, number = parsed
    audit.log_event(
        "review_requested",
        thread_id=thread_ts,
        extra={"owner": owner, "repo": repo, "pr": number},
    )

    await say(
        text=f"🔍 `{owner}/{repo}#{number}` 리뷰를 시작합니다...",
        thread_ts=thread_ts,
    )

    commands.track_thread_start(thread_ts)
    try:
        loop_guard.tick_turn(thread_ts)
        result = await review_pull_request(
            claude=claude,
            github=github,
            owner=owner,
            repo=repo,
            number=number,
            thread_id=thread_ts,
        )
    except BudgetExceeded as e:
        await say(text=f"🛑 예산 초과: {e}", thread_ts=thread_ts)
        commands.halt()
        return True
    except LoopGuardTripped as e:
        await say(text=f"🛑 루프 가드 발동: {e.layer}", thread_ts=thread_ts)
        return True
    except GitHubAppAuthError as e:
        await say(text=f"❗ GitHub 인증 실패: {e}", thread_ts=thread_ts)
        audit.log_event("error", thread_id=thread_ts, decision="github_auth")
        return True
    except Exception as e:
        log.exception("review_handler_error", thread=thread_ts)
        await say(text=f"❗ 리뷰 실행 오류: `{type(e).__name__}`", thread_ts=thread_ts)
        audit.log_event("error", thread_id=thread_ts, decision=type(e).__name__)
        return True
    finally:
        commands.track_thread_end(thread_ts)

    # Slack 에 결과 포스트
    slack_text = result.format_slack()
    posted = await say(text=slack_text, thread_ts=thread_ts)

    # 리뷰 결과에 승인 리액션 안내 추가
    await say(
        text=(
            "_리뷰를 GitHub PR 에 comment 로 포스트하려면 위 메시지에 "
            "✅ (`:white_check_mark:`) 리액션을 달아주세요. 10 분 타임아웃._"
        ),
        thread_ts=thread_ts,
    )

    audit.log_event(
        "review_posted",
        thread_id=thread_ts,
        tokens=result.claude.input_tokens + result.claude.output_tokens,
        extra={
            "pr": f"{owner}/{repo}#{number}",
            "analyzed": result.files_analyzed,
            "skipped": result.files_skipped,
        },
    )

    # HITL: 사용자가 ✅ 달면 GitHub 에도 comment 포스트
    posted_ts = posted.get("ts") if isinstance(posted, dict) else None
    if posted_ts:
        from cockpit_worker_runtime.hitl import ApprovalResult

        hitl_req = HitlRequest(
            channel=channel,
            ts=posted_ts,
            action=f"post review comment to {owner}/{repo}#{number}",
            timeout_seconds=600,
        )
        result_approval = await hitl.require(hitl_req)
        if result_approval == ApprovalResult.APPROVED:
            try:
                await github.post_issue_comment(
                    owner=owner,
                    repo=repo,
                    number=number,
                    body=f"## 🤖 CTO 리뷰\n\n{result.body}\n\n---\n_posted by cockpit CTO bot_",
                )
                await say(
                    text="✅ GitHub PR 에 리뷰 comment 포스트 완료.",
                    thread_ts=thread_ts,
                )
                audit.log_event("github_comment_posted", thread_id=thread_ts)
            except GitHubAppAuthError as e:
                await say(text=f"❗ GitHub 포스트 실패: {e}", thread_ts=thread_ts)
        elif result_approval == ApprovalResult.REJECTED:
            await say(text="⛔ GitHub 포스트 취소됨.", thread_ts=thread_ts)
        else:
            await say(text="⏲ 승인 타임아웃 — GitHub 포스트 생략.", thread_ts=thread_ts)

    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="cockpit-worker",
        description="claude-cockpit worker 단일 봇 기동",
    )
    parser.add_argument(
        "worker_dir",
        type=Path,
        help="worker 디렉토리 경로 (AGENT.md 포함)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Slack/Claude API 호출 없이 조립만 검증",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="structlog debug 레벨",
    )
    args = parser.parse_args()

    _configure_logging(verbose=args.verbose)

    worker_dir: Path = args.worker_dir.resolve()
    if not worker_dir.is_dir():
        log.error("worker_dir_invalid", path=str(worker_dir))
        return 2

    try:
        assembled = assemble(worker_dir, dry_run=args.dry_run)
    except (FileNotFoundError, ValueError, RuntimeError) as e:
        log.error("assemble_failed", error=str(e), path=str(worker_dir))
        return 3

    log.info(
        "worker_assembled",
        name=assembled.agent.name,
        role=assembled.agent.role,
        layer=assembled.agent.layer,
        dry_run=args.dry_run,
    )

    if args.dry_run:
        assembled.bolt.start()
        log.info("dry_run_complete", worker=assembled.agent.name)
        return 0

    # 실제 기동
    try:
        asyncio.run(assembled.bolt.start_async())
    except KeyboardInterrupt:
        log.info("worker_shutdown", worker=assembled.agent.name, reason="keyboard_interrupt")
        return 0
    except Exception as e:
        log.exception("worker_crashed", worker=assembled.agent.name, error=str(e))
        return 5
    return 0


def _configure_logging(*, verbose: bool) -> None:
    import logging

    logging.basicConfig(
        format="%(message)s",
        level=logging.DEBUG if verbose else logging.INFO,
    )
    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.dev.ConsoleRenderer(colors=sys.stdout.isatty()),
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
