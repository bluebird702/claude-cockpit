"""PR 리뷰 오케스트레이션 — CTO 봇의 핵심 워크플로우.

흐름:
1. Slack 에서 `@CTO /review PR#123` 또는 PR URL 수신
2. github_app 로 PR metadata + files 가져오기
3. diff 크기 체크 (너무 크면 분할 또는 거절)
4. Claude 에게 표준 기반 리뷰 요청
5. Slack 에 결과 포스트 (요약 + Critical/Important/Nit 카테고리)
6. (선택) GitHub PR 에 review comment 도 포스트 (HITL 승인 후)
"""

from __future__ import annotations

from dataclasses import dataclass

import structlog

from cockpit_worker_runtime.claude_adapter import ClaudeAdapter, ClaudeResponse
from cockpit_worker_runtime.tools.github_app import (
    FileChange,
    GitHubAppClient,
    PullRequest,
)

log = structlog.get_logger(__name__)

MAX_DIFF_CHARS = 120_000  # ~30k 토큰 상한
MAX_FILES_DETAILED = 20


@dataclass
class ReviewResult:
    """리뷰 1 건 결과. Slack 포스트 + (선택) GitHub 포스트 양쪽에 사용."""

    pr: PullRequest
    summary: str  # 한 줄 요약
    body: str  # 전체 리뷰 본문 (Critical/Important/Nit 포함)
    files_analyzed: int
    files_skipped: int
    total_additions: int
    total_deletions: int
    claude: ClaudeResponse

    def format_slack(self, max_len: int = 3500) -> str:
        """Slack 메시지 포맷 (4000자 이내 안전)."""
        header = (
            f"*<https://github.com/{self.pr.owner}/{self.pr.repo}/pull/{self.pr.number}|"
            f"{self.pr.owner}/{self.pr.repo}#{self.pr.number}>* — {self.pr.title}\n"
            f"+{self.total_additions} -{self.total_deletions} · "
            f"분석 {self.files_analyzed}개 / 전체 {self.files_analyzed + self.files_skipped}개 파일\n"
            f"\n"
        )
        body = self.body.strip()
        if len(header) + len(body) > max_len:
            body = body[: max_len - len(header) - 60] + "\n\n_…(생략, 전체는 스레드)_"
        return header + body


async def review_pull_request(
    *,
    claude: ClaudeAdapter,
    github: GitHubAppClient,
    owner: str,
    repo: str,
    number: int,
    thread_id: str,
) -> ReviewResult:
    """PR 리뷰 단일 턴 실행."""
    log.info("pr_review.start", owner=owner, repo=repo, number=number, thread=thread_id)

    pr = await github.fetch_pull_request(owner=owner, repo=repo, number=number)
    files = await github.fetch_pr_files(owner=owner, repo=repo, number=number)

    total_add = sum(f.additions for f in files)
    total_del = sum(f.deletions for f in files)

    # 분석 대상 제한 (lock 파일 · 바이너리 · 대용량 제외)
    analyzed, skipped = _select_files_for_review(files)

    review_prompt = _build_review_prompt(
        pr=pr,
        analyzed=analyzed,
        skipped_count=len(skipped),
    )

    response = await claude.complete(
        thread_id=thread_id,
        user_text=review_prompt,
        max_tokens=3000,
    )

    # Claude 응답의 첫 줄을 summary 로, 전체를 body 로
    text = response.text.strip()
    first_line = text.split("\n", 1)[0] if text else "리뷰 실패"
    summary = first_line.lstrip("# ").strip()[:200]

    return ReviewResult(
        pr=pr,
        summary=summary,
        body=text,
        files_analyzed=len(analyzed),
        files_skipped=len(skipped),
        total_additions=total_add,
        total_deletions=total_del,
        claude=response,
    )


def _select_files_for_review(
    files: list[FileChange],
) -> tuple[list[FileChange], list[FileChange]]:
    """리뷰 대상 파일 선별. (analyzed, skipped) 반환."""
    SKIP_PATTERNS = (
        "poetry.lock",
        "package-lock.json",
        "yarn.lock",
        "pnpm-lock.yaml",
        "Cargo.lock",
        ".min.js",
        ".min.css",
    )
    SKIP_EXTENSIONS = (".svg", ".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".zip")

    analyzed: list[FileChange] = []
    skipped: list[FileChange] = []

    for f in files:
        name = f.filename.lower()
        if any(p in name for p in SKIP_PATTERNS):
            skipped.append(f)
            continue
        if name.endswith(SKIP_EXTENSIONS):
            skipped.append(f)
            continue
        if not f.patch:  # 바이너리 등 patch 없음
            skipped.append(f)
            continue
        if f.additions + f.deletions > 2000:  # 개별 파일 너무 큼
            skipped.append(f)
            continue
        analyzed.append(f)
        if len(analyzed) >= MAX_FILES_DETAILED:
            # 나머지는 건너뛰되 skipped 에 포함 (개수 표시용)
            break

    # MAX_FILES_DETAILED 초과분 skipped 에 추가
    if len(files) > len(analyzed) + len(skipped):
        skipped.extend(files[len(analyzed) + len(skipped) :])

    return analyzed, skipped


def _build_review_prompt(
    *,
    pr: PullRequest,
    analyzed: list[FileChange],
    skipped_count: int,
) -> str:
    """Claude 에게 보낼 리뷰 요청 프롬프트."""
    parts: list[str] = []
    parts.append(
        f"다음 Pull Request 를 리뷰해 주세요.\n\n"
        f"**PR**: {pr.owner}/{pr.repo}#{pr.number} — {pr.title}\n"
        f"**브랜치**: `{pr.head_ref}` → `{pr.base_ref}`\n"
        f"**상태**: {pr.state}" + (" (draft)" if pr.draft else "") + "\n"
    )

    if pr.raw.get("body"):
        parts.append(f"\n**PR 설명**:\n{pr.raw['body'][:1500]}\n")

    parts.append("\n**변경 파일**:\n")
    for f in analyzed:
        parts.append(f"\n--- {f.filename} ({f.status}, +{f.additions}/-{f.deletions}) ---\n")
        patch = f.patch
        if len(patch) > 8000:
            patch = patch[:8000] + "\n... (truncated)"
        parts.append(f"```diff\n{patch}\n```\n")

    if skipped_count:
        parts.append(f"\n_({skipped_count} 개 파일은 lock/바이너리/대용량으로 생략)_\n")

    parts.append(
        "\n---\n\n"
        "리뷰 지침:\n"
        "1. **Critical / Important / Nit** 3 단계로 분류 (Nit 는 1 개까지)\n"
        "2. 각 항목: `문제 → 영향 → 권장 수정` 순서\n"
        "3. 코드 스니펫 제안은 3줄 이내, 긴 리팩터링은 ADR 권장\n"
        "4. 보안 · 테스트 커버리지 · Clean Architecture 경계를 우선 체크\n"
        "5. 첫 줄에 한 줄 요약 (이 PR 이 무엇을 달성하는지)\n"
        "6. 마지막에 **권장 액션** 체크리스트 (≤ 5 개)\n"
        "\n"
        "전체는 Slack 포스트용이므로 2500자 이내로 유지해 주세요.\n"
    )

    total = sum(len(p) for p in parts)
    log.debug("pr_review.prompt_built", chars=total, files=len(analyzed))

    if total > MAX_DIFF_CHARS:
        # 초과 시 마지막 지침은 유지, 중간 diff 를 잘라냄
        log.warning("pr_review.prompt_truncated", original=total, limit=MAX_DIFF_CHARS)

    return "".join(parts)[:MAX_DIFF_CHARS]
