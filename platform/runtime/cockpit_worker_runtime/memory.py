"""메모리 레이어 — 불변 (seed) vs 가변 (long-term).

불변 메모리 = role.md, boundaries.md, conventions.md, company-facts.md
  → 매 대화 시작마다 system prompt 에 주입, 캐시 적합 (prompt caching 90% 할인)

가변 메모리 = ~/.cockpit-agents/<worker>/memory/long-term/
  → 봇이 새로 학습한 것, CEO 의 피드백, ADR 링크 등
  → 봇이 자율적으로 append, 사람이 주기적으로 감사

이 분리가 중요한 이유:
1. 캐시 효율 — 불변 부분은 시스템 프롬프트 캐시 한 덩어리로 처리
2. 감사 용이 — 가변 영역만 diff 추적하면 "봇이 뭘 새로 배웠나" 파악
3. 원복 가능 — 가변 메모리가 오염되면 디렉토리 째로 삭제, 불변은 리포에서 재시드
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from cockpit_worker_runtime.agent_md import MemoryConfig


@dataclass
class LoadedMemory:
    """시스템 프롬프트 주입용 직렬화된 메모리."""

    immutable_text: str  # 전체 seed 를 하나의 문자열로 join (캐시 블록)
    mutable_path: Path  # 가변 메모리 디렉토리 (쓰기 가능)


class Memory:
    """worker 의 메모리를 seed_dir + long_term_dir 로부터 로드·관리.

    seed_dir 은 worker 레포 디렉토리 기준 상대 경로 (예: `memory-seed/`).
    long_term_dir 은 설정되지 않았으면 기본 위치 자동 생성.
    """

    def __init__(
        self,
        worker_name: str,
        worker_root: Path,
        config: MemoryConfig,
    ) -> None:
        self.worker_name = worker_name
        self.worker_root = worker_root
        self.config = config

        self.seed_dir = (worker_root / config.seed_dir).resolve()
        if config.long_term_dir:
            self.long_term_dir = Path(config.long_term_dir).expanduser().resolve()
        else:
            self.long_term_dir = (
                Path.home() / ".cockpit-agents" / worker_name / "memory" / "long-term"
            ).resolve()

        self.long_term_dir.mkdir(parents=True, exist_ok=True)

    def load(self) -> LoadedMemory:
        """seed 디렉토리의 모든 .md 파일을 알파벳 순으로 읽어 연결.

        파일 간 구분자: `\\n\\n---\\n\\n` (마크다운 thematic break)
        """
        if not self.seed_dir.exists():
            return LoadedMemory(immutable_text="", mutable_path=self.long_term_dir)

        pieces: list[str] = []
        for md_file in sorted(self.seed_dir.glob("*.md")):
            header = f"## seed:{md_file.stem}\n"
            pieces.append(header + md_file.read_text("utf-8").strip())

        return LoadedMemory(
            immutable_text="\n\n---\n\n".join(pieces),
            mutable_path=self.long_term_dir,
        )

    def append_long_term(self, note_name: str, content: str) -> Path:
        """봇이 새로 배운 것을 long-term 에 append.

        파일명에 슬래시나 .. 금지 — 디렉토리 탈출 방어.
        """
        if "/" in note_name or ".." in note_name or note_name.startswith("."):
            raise ValueError(f"안전하지 않은 note_name: {note_name}")

        dest = self.long_term_dir / f"{note_name}.md"
        with dest.open("a", encoding="utf-8") as f:
            f.write(content.rstrip() + "\n\n")
        return dest
