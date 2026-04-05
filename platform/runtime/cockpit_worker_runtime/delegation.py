"""리더 → 서브워커 위임 프로토콜.

CTO 가 요청을 받으면 `workers/cto/delegates.yaml` 에 정의된 규칙에 따라
backend-dev / frontend-dev / qa / devops / infra 중 적절한 서브워커를 호출.

Sprint 0 시점에선 라우팅 로직 + YAML 스키마만 정의. 실제 Task 툴 연동은
Sprint 3 (CTO 서브워커 전개) 에서 구현.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict, Field


class PathRule(BaseModel):
    """경로 패턴 기반 라우팅 규칙."""

    model_config = ConfigDict(extra="forbid")

    pattern: str  # glob 또는 prefix (예: "platform/frontend/**")
    delegate_to: str  # worker 이름 (예: "frontend-dev")


class LabelRule(BaseModel):
    """PR 라벨 기반 라우팅 규칙."""

    model_config = ConfigDict(extra="forbid")

    label: str
    delegate_to: str


class DelegatesConfig(BaseModel):
    """delegates.yaml 전체 스키마."""

    model_config = ConfigDict(extra="forbid")

    path_rules: list[PathRule] = Field(default_factory=list)
    label_rules: list[LabelRule] = Field(default_factory=list)
    default: str | None = None  # 매칭 없을 때 fallback worker. None 이면 리더 본인이 처리.
    escalate_if_ambiguous: bool = True  # 여러 규칙이 매칭되면 CEO 에게 에스컬레이션

    @classmethod
    def from_file(cls, path: Path) -> DelegatesConfig:
        if not path.exists():
            return cls()  # 빈 설정 — 리더가 전부 직접 처리
        data = yaml.safe_load(path.read_text("utf-8")) or {}
        return cls.model_validate(data)


@dataclass
class DelegationDecision:
    """라우팅 결과."""

    delegate_to: str | None  # None 이면 리더 본인이 처리
    matched_rules: list[str]
    ambiguous: bool


class Router:
    """경로·라벨을 입력받아 어느 서브워커로 보낼지 결정.

    실제 Task 툴 호출은 Sprint 3 에서 bolt_adapter + claude_adapter 가 담당.
    이 모듈은 **결정** 만 한다.
    """

    def __init__(self, config: DelegatesConfig) -> None:
        self.config = config

    def route(
        self,
        *,
        changed_paths: list[str] | None = None,
        labels: list[str] | None = None,
    ) -> DelegationDecision:
        matched: set[str] = set()
        matched_rules: list[str] = []

        changed_paths = changed_paths or []
        labels = labels or []

        for rule in self.config.path_rules:
            if any(self._path_match(p, rule.pattern) for p in changed_paths):
                matched.add(rule.delegate_to)
                matched_rules.append(f"path:{rule.pattern}→{rule.delegate_to}")

        for rule in self.config.label_rules:
            if rule.label in labels:
                matched.add(rule.delegate_to)
                matched_rules.append(f"label:{rule.label}→{rule.delegate_to}")

        if not matched:
            return DelegationDecision(
                delegate_to=self.config.default,
                matched_rules=[],
                ambiguous=False,
            )

        if len(matched) == 1:
            return DelegationDecision(
                delegate_to=matched.pop(),
                matched_rules=matched_rules,
                ambiguous=False,
            )

        # 여러 서브워커가 매칭 — escalate_if_ambiguous 에 따라 결정
        if self.config.escalate_if_ambiguous:
            return DelegationDecision(
                delegate_to=None,  # 리더가 직접 처리하거나 CEO 에게 에스컬레이션
                matched_rules=matched_rules,
                ambiguous=True,
            )
        # 첫 매칭 우선
        return DelegationDecision(
            delegate_to=sorted(matched)[0],
            matched_rules=matched_rules,
            ambiguous=False,
        )

    @staticmethod
    def _path_match(path: str, pattern: str) -> bool:
        """간단한 glob 매칭. `**` 는 재귀 매칭."""
        from fnmatch import fnmatch

        # `**` 를 `*` 로 변환 (fnmatch 는 `**` 를 특별 취급 안 함)
        if "**" in pattern:
            prefix = pattern.split("**")[0].rstrip("/")
            return path.startswith(prefix)
        return fnmatch(path, pattern)
