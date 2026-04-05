"""AGENT.md 스키마 v1 — 에이전트 고용 계약서.

각 worker 봇은 자신의 `AGENT.md` 한 파일에서 아래를 모두 선언합니다:
- 정체성 (name, role, slack_handle, github_app)
- 권한 (can_merge_pr 등 명시적 bool 필드)
- 채널 (home, allowed, forbidden)
- 예산 (usd_per_day, tokens_per_thread)
- 루프 방어 임계값
- 메모리 (seed 경로, long-term 경로)
- HITL 게이트 (어떤 액션에 승인 필요)
- 에스컬레이션 (누구에게 넘길지)

형식은 YAML frontmatter + 마크다운 본문. frontmatter 만 파싱합니다.

사용 예:
    agent = AgentMD.from_file(Path("workers/cto/AGENT.md"))
    if agent.permissions.can_merge_pr is False:
        ...
"""

from __future__ import annotations

from pathlib import Path
from typing import Literal

import frontmatter
from pydantic import BaseModel, ConfigDict, Field, field_validator


class Permissions(BaseModel):
    """명시적 권한 스위치. 기본값은 전부 보수적."""

    model_config = ConfigDict(extra="forbid")

    can_merge_pr: Literal[False] = False  # 하드 코딩: 모든 봇 false (vision.md)
    can_push_main: bool = False
    can_create_pr: bool = True
    can_comment_pr: bool = True
    can_close_issue: bool = False
    can_send_external: bool = False  # 외부 발송 (메일·파트너) — HITL 필수
    can_modify_prod: bool = False


class Budget(BaseModel):
    """봇별 예산 한도. 초과 시 runtime.budget 이 halt."""

    model_config = ConfigDict(extra="forbid")

    usd_per_day: float = Field(default=5.0, gt=0, le=200)
    tokens_per_thread: int = Field(default=50_000, gt=0, le=500_000)
    turns_per_thread: int = Field(default=10, gt=0, le=50)


class LoopGuardLimits(BaseModel):
    """5중 루프 방어 임계값."""

    model_config = ConfigDict(extra="forbid")

    max_chain_depth: int = Field(default=3, ge=1, le=10)  # 봇 → 봇 체인 깊이
    requests_per_hour: int = Field(default=60, gt=0, le=500)
    ignore_other_bots: bool = True  # 기본: 다른 봇 메시지 무시


class Channels(BaseModel):
    """Slack 채널 매트릭스."""

    model_config = ConfigDict(extra="forbid")

    home: list[str] = Field(default_factory=list)  # 홈 채널 (브리핑 기본 포스트)
    allowed: list[str] = Field(default_factory=list)  # 읽기·쓰기 가능
    read_only: list[str] = Field(default_factory=list)  # 읽기 전용
    forbidden: list[str] = Field(default_factory=list)  # 접근 금지

    @field_validator("home", "allowed", "read_only", "forbidden")
    @classmethod
    def validate_channel_names(cls, v: list[str]) -> list[str]:
        for name in v:
            if name.startswith("#"):
                raise ValueError(f"채널명에 # 접두사 금지 (받은 값: {name})")
        return v


class MemoryConfig(BaseModel):
    """메모리 저장 위치 설정."""

    model_config = ConfigDict(extra="forbid")

    seed_dir: str = "memory-seed"  # worker 디렉토리 기준 상대 경로 (불변)
    long_term_dir: str | None = None  # 절대 경로 (가변, 설정 없으면 ~/.cockpit-agents/<name>/memory)


class HitlGates(BaseModel):
    """HITL 승인이 필요한 액션 분류."""

    model_config = ConfigDict(extra="forbid")

    # 각 항목이 True 면 해당 액션 수행 전 Slack 리액션 승인 대기
    file_write: bool = False
    pr_create: bool = True
    pr_merge: bool = True  # can_merge_pr=False 와 별개 (수정도 승인)
    external_send: bool = True
    prod_deploy: bool = True
    db_migration: bool = True


class Escalation(BaseModel):
    """누구에게 넘길지."""

    model_config = ConfigDict(extra="forbid")

    on_budget_exceeded: str = "@ceo"  # 예산 초과 시 알림
    on_loop_tripped: str = "#agent-ops"
    on_auth_failure: str = "#agent-admin"
    on_unknown_error: str = "@ceo"


class AgentMD(BaseModel):
    """AGENT.md 전체 계약서. YAML frontmatter 를 파싱해 이 모델에 주입."""

    model_config = ConfigDict(extra="forbid")

    # 정체성
    name: str = Field(pattern=r"^[a-z][a-z0-9-]{1,30}$")  # 디렉토리명·컨테이너명 겸용
    role: str  # 한글 직함 (예: "개발 리더", "재무/회계")
    slack_handle: str = Field(pattern=r"^@[A-Za-z][A-Za-z0-9_-]{0,20}$")
    github_app: str | None = None  # GitHub App slug (개발 봇만)
    layer: Literal["secretary", "c-suite", "sub-worker"]  # 조직도 레이어
    reports_to: str | None = None  # 상위 봇 또는 "ceo"

    # 모델 티어링
    primary_model: Literal["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"] = (
        "claude-sonnet-4-6"
    )
    routing_model: Literal["claude-haiku-4-5"] = "claude-haiku-4-5"  # 분류·라우팅 전용

    # 권한·경계·예산
    permissions: Permissions = Field(default_factory=Permissions)
    channels: Channels = Field(default_factory=Channels)
    budget: Budget = Field(default_factory=Budget)
    loop_guard: LoopGuardLimits = Field(default_factory=LoopGuardLimits)

    # 메모리·HITL·에스컬레이션
    memory: MemoryConfig = Field(default_factory=MemoryConfig)
    hitl: HitlGates = Field(default_factory=HitlGates)
    escalation: Escalation = Field(default_factory=Escalation)

    # 도구 (tools.yaml 경로만 가리킴, 실제 로드는 런타임에서)
    tools_yaml: str = "tools.yaml"

    @classmethod
    def from_file(cls, path: Path) -> AgentMD:
        """AGENT.md 파일에서 frontmatter 를 파싱해 인스턴스 생성.

        파일이 없거나 frontmatter 가 비어있으면 ValueError.
        """
        if not path.exists():
            raise FileNotFoundError(f"AGENT.md 없음: {path}")

        post = frontmatter.load(str(path))
        if not post.metadata:
            raise ValueError(f"AGENT.md 에 YAML frontmatter 없음: {path}")

        return cls.model_validate(post.metadata)

    def validate_consistency(self) -> list[str]:
        """교차 필드 일관성 검증. 에러 목록 반환 (빈 리스트면 정상)."""
        errors: list[str] = []

        if self.layer == "sub-worker" and self.reports_to in (None, "ceo"):
            errors.append("sub-worker 레이어는 reports_to 가 ceo 가 아닌 리더여야 함")

        if self.layer == "c-suite" and self.reports_to != "ceo":
            errors.append("c-suite 레이어는 reports_to='ceo' 여야 함")

        if self.permissions.can_modify_prod and not self.hitl.prod_deploy:
            errors.append("can_modify_prod=True 이면 hitl.prod_deploy=True 필수")

        if self.budget.tokens_per_thread > 200_000 and self.primary_model == "claude-opus-4-6":
            errors.append(
                "tokens_per_thread 가 200k 초과인데 Opus 사용 — 비용 폭주 위험 (재검토)"
            )

        return errors
