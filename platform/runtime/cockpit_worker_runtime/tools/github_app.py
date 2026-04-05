"""GitHub App 인증 + PR 작업 클라이언트.

책임:
1. GitHub App 의 JWT 생성 (App ID + private key)
2. Installation access token 교환 (1시간 TTL, 자동 갱신)
3. PR diff 가져오기
4. PR review comment 포스트
5. 브랜치 생성 + 파일 패치 + PR 생성 (HITL 후 호출)

인증 흐름:
    App ID + private key → JWT (10분 TTL)
        → GET /app/installations/{id}/access_tokens
        → installation access token (1시간 TTL)
        → REST API 호출 시 Bearer 로 사용

시크릿:
    Keychain: cockpit/<worker>/github-app-id
              cockpit/<worker>/github-private-key  (PEM 전체)
              cockpit/<worker>/github-installation-id

이 모듈은 `PyJWT` 와 `aiohttp` 를 사용합니다.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Any

import aiohttp
import structlog

from cockpit_worker_runtime.secrets import get_keychain_secret

log = structlog.get_logger(__name__)

GITHUB_API = "https://api.github.com"


class GitHubAppAuthError(RuntimeError):
    """GitHub App 인증 실패."""


@dataclass
class GitHubAppCredentials:
    """GitHub App 인증에 필요한 3종 세트."""

    app_id: str
    private_key_pem: str
    installation_id: str

    @classmethod
    def from_keychain(cls, worker_name: str) -> "GitHubAppCredentials":
        app_id = get_keychain_secret(f"cockpit/{worker_name}/github-app-id")
        pem = get_keychain_secret(f"cockpit/{worker_name}/github-private-key")
        inst = get_keychain_secret(f"cockpit/{worker_name}/github-installation-id")
        if not (app_id and pem and inst):
            missing = [
                k
                for k, v in [
                    ("github-app-id", app_id),
                    ("github-private-key", pem),
                    ("github-installation-id", inst),
                ]
                if not v
            ]
            raise GitHubAppAuthError(
                f"Keychain 에 다음 시크릿 필요: {missing} "
                f"(서비스: cockpit/{worker_name}/*)"
            )
        return cls(app_id=app_id, private_key_pem=pem, installation_id=inst)


@dataclass
class PullRequest:
    """PR 요약 정보 (전체 응답은 raw 에)."""

    owner: str
    repo: str
    number: int
    title: str
    head_ref: str
    base_ref: str
    state: str
    draft: bool
    raw: dict[str, Any]


@dataclass
class FileChange:
    """PR 의 파일 한 개 변경 정보."""

    filename: str
    status: str  # added / modified / removed / renamed
    additions: int
    deletions: int
    patch: str  # unified diff 조각


class GitHubAppClient:
    """Installation access token 기반 GitHub API 클라이언트.

    토큰은 자동 갱신 (만료 60초 전 재발급).
    """

    def __init__(self, credentials: GitHubAppCredentials) -> None:
        self.credentials = credentials
        self._installation_token: str | None = None
        self._token_expires_at: float = 0.0

    # ─── 인증 ───────────────────────────────────────

    def _generate_jwt(self) -> str:
        """App 자격의 JWT 생성 (10분 TTL)."""
        try:
            import jwt  # PyJWT
        except ImportError as e:
            raise GitHubAppAuthError(
                "PyJWT 미설치. poetry add pyjwt[crypto] 필요"
            ) from e

        now = int(time.time())
        payload = {
            "iat": now - 30,  # 시계 편차 보정
            "exp": now + 540,  # 9분 뒤 만료 (GitHub 상한 10분)
            "iss": self.credentials.app_id,
        }
        return jwt.encode(payload, self.credentials.private_key_pem, algorithm="RS256")

    async def _get_installation_token(self) -> str:
        """installation access token 반환 (필요 시 갱신)."""
        now = time.time()
        if self._installation_token and now < self._token_expires_at - 60:
            return self._installation_token

        app_jwt = self._generate_jwt()
        url = f"{GITHUB_API}/app/installations/{self.credentials.installation_id}/access_tokens"
        headers = {
            "Authorization": f"Bearer {app_jwt}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers) as resp:
                if resp.status != 201:
                    body = await resp.text()
                    raise GitHubAppAuthError(
                        f"installation token 교환 실패 (status={resp.status}): {body}"
                    )
                data = await resp.json()

        self._installation_token = data["token"]
        # expires_at 은 ISO 문자열, 파싱해서 epoch 로 변환
        from datetime import datetime

        expires_iso = data.get("expires_at", "")
        try:
            exp_dt = datetime.fromisoformat(expires_iso.replace("Z", "+00:00"))
            self._token_expires_at = exp_dt.timestamp()
        except ValueError:
            self._token_expires_at = now + 3600  # 안전 기본값

        log.info(
            "github.token_issued",
            installation=self.credentials.installation_id,
            expires_in_sec=int(self._token_expires_at - now),
        )
        return self._installation_token

    async def _api(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, Any] | None = None,
        accept: str = "application/vnd.github+json",
    ) -> dict[str, Any]:
        """인증된 REST API 호출. 반환값은 파싱된 JSON dict."""
        token = await self._get_installation_token()
        url = f"{GITHUB_API}{path}"
        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": accept,
            "X-GitHub-Api-Version": "2022-11-28",
        }

        async with aiohttp.ClientSession() as session:
            async with session.request(method, url, headers=headers, json=json_body) as resp:
                if resp.status >= 400:
                    body = await resp.text()
                    raise GitHubAppAuthError(
                        f"{method} {path} 실패 (status={resp.status}): {body[:500]}"
                    )
                if accept == "application/vnd.github.diff":
                    return {"diff": await resp.text()}
                return await resp.json()

    # ─── PR 작업 ─────────────────────────────────

    async def fetch_pull_request(self, *, owner: str, repo: str, number: int) -> PullRequest:
        data = await self._api("GET", f"/repos/{owner}/{repo}/pulls/{number}")
        return PullRequest(
            owner=owner,
            repo=repo,
            number=number,
            title=data.get("title", ""),
            head_ref=data.get("head", {}).get("ref", ""),
            base_ref=data.get("base", {}).get("ref", ""),
            state=data.get("state", "unknown"),
            draft=bool(data.get("draft", False)),
            raw=data,
        )

    async def fetch_pr_diff(self, *, owner: str, repo: str, number: int) -> str:
        """PR 의 unified diff 전체. 대용량 PR 엔 crop 필요 (호출자 책임)."""
        data = await self._api(
            "GET",
            f"/repos/{owner}/{repo}/pulls/{number}",
            accept="application/vnd.github.diff",
        )
        return data.get("diff", "")

    async def fetch_pr_files(
        self, *, owner: str, repo: str, number: int
    ) -> list[FileChange]:
        """PR 의 파일 목록 + 각 파일의 patch."""
        data = await self._api("GET", f"/repos/{owner}/{repo}/pulls/{number}/files")
        # 응답은 list, 하지만 _api 는 dict 반환 — 별도 처리
        if isinstance(data, dict):
            files = data.get("files", [])
        else:
            files = data
        return [
            FileChange(
                filename=f.get("filename", ""),
                status=f.get("status", ""),
                additions=f.get("additions", 0),
                deletions=f.get("deletions", 0),
                patch=f.get("patch", ""),
            )
            for f in files
        ]

    async def post_issue_comment(
        self,
        *,
        owner: str,
        repo: str,
        number: int,
        body: str,
    ) -> dict[str, Any]:
        """PR/issue 에 일반 comment 포스트 (리뷰 comment 와 다름)."""
        return await self._api(
            "POST",
            f"/repos/{owner}/{repo}/issues/{number}/comments",
            json_body={"body": body},
        )

    async def post_review(
        self,
        *,
        owner: str,
        repo: str,
        number: int,
        body: str,
        event: str = "COMMENT",  # COMMENT / APPROVE / REQUEST_CHANGES (can_merge_pr=false 이므로 APPROVE 금지)
    ) -> dict[str, Any]:
        """PR 리뷰 포스트. 봇은 APPROVE 금지 (AGENT.md 에서 막음)."""
        if event == "APPROVE":
            raise GitHubAppAuthError("봇은 PR APPROVE 금지 — COMMENT 또는 REQUEST_CHANGES 만 허용")
        return await self._api(
            "POST",
            f"/repos/{owner}/{repo}/pulls/{number}/reviews",
            json_body={"body": body, "event": event},
        )


# 편의 파서: Slack 메시지에서 PR URL 또는 "PR #123" 추출
import re

_PR_URL_RE = re.compile(
    r"https://github\.com/([\w.-]+)/([\w.-]+)/pull/(\d+)"
)
_PR_SHORT_RE = re.compile(r"(?:^|\s)(?:PR|#)\s*#?(\d+)", re.IGNORECASE)


def parse_pr_reference(text: str, default_repo: tuple[str, str] | None = None) -> tuple[str, str, int] | None:
    """텍스트에서 (owner, repo, number) 추출.

    인식 형식:
        https://github.com/<owner>/<repo>/pull/123
        PR #123 (default_repo 필요)
        #123 (default_repo 필요)
    """
    m = _PR_URL_RE.search(text)
    if m:
        return m.group(1), m.group(2), int(m.group(3))

    m = _PR_SHORT_RE.search(text)
    if m and default_repo:
        return default_repo[0], default_repo[1], int(m.group(1))

    return None
