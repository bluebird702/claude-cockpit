"""메모리 레이어 단위 테스트."""

from __future__ import annotations

from pathlib import Path

import pytest

from cockpit_worker_runtime.agent_md import MemoryConfig
from cockpit_worker_runtime.memory import Memory


def _build_worker_dir(tmp_path: Path) -> Path:
    worker = tmp_path / "test-bot"
    seed = worker / "memory-seed"
    seed.mkdir(parents=True)
    (seed / "role.md").write_text("역할: 테스트 봇\n", encoding="utf-8")
    (seed / "boundaries.md").write_text("경계: 실험 전용\n", encoding="utf-8")
    (seed / "conventions.md").write_text("컨벤션: AAA 패턴\n", encoding="utf-8")
    return worker


def test_seed_files_loaded_sorted(tmp_path: Path) -> None:
    worker = _build_worker_dir(tmp_path)
    mem = Memory(
        worker_name="test-bot",
        worker_root=worker,
        config=MemoryConfig(long_term_dir=str(tmp_path / "long-term")),
    )
    loaded = mem.load()
    # 알파벳 순: boundaries → conventions → role
    idx_b = loaded.immutable_text.index("boundaries")
    idx_c = loaded.immutable_text.index("conventions")
    idx_r = loaded.immutable_text.index("role")
    assert idx_b < idx_c < idx_r


def test_long_term_append(tmp_path: Path) -> None:
    worker = _build_worker_dir(tmp_path)
    long_term = tmp_path / "long-term"
    mem = Memory(
        worker_name="test-bot",
        worker_root=worker,
        config=MemoryConfig(long_term_dir=str(long_term)),
    )
    mem.load()
    note = mem.append_long_term("learned", "CEO 가 이렇게 하라고 했음")
    assert note.exists()
    assert "CEO" in note.read_text("utf-8")


def test_append_rejects_unsafe_names(tmp_path: Path) -> None:
    worker = _build_worker_dir(tmp_path)
    mem = Memory(
        worker_name="test-bot",
        worker_root=worker,
        config=MemoryConfig(long_term_dir=str(tmp_path / "lt")),
    )
    for bad in ["../escape", "sub/dir", ".hidden"]:
        with pytest.raises(ValueError):
            mem.append_long_term(bad, "content")


def test_missing_seed_dir_returns_empty(tmp_path: Path) -> None:
    worker = tmp_path / "empty"
    worker.mkdir()
    mem = Memory(
        worker_name="empty",
        worker_root=worker,
        config=MemoryConfig(long_term_dir=str(tmp_path / "lt")),
    )
    loaded = mem.load()
    assert loaded.immutable_text == ""
