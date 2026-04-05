"""AGENT.md Pydantic 스키마 단위 테스트."""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from cockpit_worker_runtime.agent_md import AgentMD


def _write_agent_md(
    tmp_path: Path,
    frontmatter: str,
    body: str = "# Test\n",
) -> Path:
    path = tmp_path / "AGENT.md"
    path.write_text(f"---\n{frontmatter}\n---\n{body}", encoding="utf-8")
    return path


class TestBasicLoading:
    def test_minimal_valid(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: cto\n"
                "role: 개발 리더\n"
                "slack_handle: '@CTO'\n"
                "layer: c-suite\n"
                "reports_to: ceo\n"
            ),
        )
        agent = AgentMD.from_file(md)
        assert agent.name == "cto"
        assert agent.layer == "c-suite"
        assert agent.permissions.can_merge_pr is False  # 하드코딩 검증

    def test_missing_file(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            AgentMD.from_file(tmp_path / "nope.md")

    def test_empty_frontmatter(self, tmp_path: Path) -> None:
        path = tmp_path / "AGENT.md"
        path.write_text("no frontmatter here\n", encoding="utf-8")
        with pytest.raises(ValueError, match="frontmatter"):
            AgentMD.from_file(path)


class TestValidation:
    def test_invalid_name_pattern(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: CTO_BAD\n"  # 대문자 + 언더스코어 금지
                "role: 개발 리더\n"
                "slack_handle: '@CTO'\n"
                "layer: c-suite\n"
                "reports_to: ceo\n"
            ),
        )
        with pytest.raises(ValidationError):
            AgentMD.from_file(md)

    def test_can_merge_pr_cannot_be_true(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: cto\n"
                "role: 개발 리더\n"
                "slack_handle: '@CTO'\n"
                "layer: c-suite\n"
                "reports_to: ceo\n"
                "permissions:\n"
                "  can_merge_pr: true\n"
            ),
        )
        with pytest.raises(ValidationError):
            AgentMD.from_file(md)

    def test_channel_name_must_not_have_hash(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: cto\n"
                "role: 개발 리더\n"
                "slack_handle: '@CTO'\n"
                "layer: c-suite\n"
                "reports_to: ceo\n"
                "channels:\n"
                "  home: ['#engineering']\n"  # # 금지
            ),
        )
        with pytest.raises(ValidationError):
            AgentMD.from_file(md)


class TestConsistency:
    def test_c_suite_must_report_to_ceo(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: cto\n"
                "role: 개발 리더\n"
                "slack_handle: '@CTO'\n"
                "layer: c-suite\n"
                "reports_to: cfo\n"  # 잘못됨
            ),
        )
        agent = AgentMD.from_file(md)
        errors = agent.validate_consistency()
        assert any("c-suite" in e for e in errors)

    def test_sub_worker_cannot_report_to_ceo(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: backend-dev\n"
                "role: 백엔드 서브워커\n"
                "slack_handle: '@backend-dev'\n"
                "layer: sub-worker\n"
                "reports_to: ceo\n"  # 잘못됨
            ),
        )
        agent = AgentMD.from_file(md)
        errors = agent.validate_consistency()
        assert any("sub-worker" in e for e in errors)

    def test_secretary_reports_to_ceo(self, tmp_path: Path) -> None:
        md = _write_agent_md(
            tmp_path,
            frontmatter=(
                "name: secretary\n"
                "role: CEO 운영 보조\n"
                "slack_handle: '@Secretary'\n"
                "layer: secretary\n"
                "reports_to: ceo\n"
            ),
        )
        agent = AgentMD.from_file(md)
        assert agent.validate_consistency() == []
