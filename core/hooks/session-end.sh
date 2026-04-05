#!/usr/bin/env bash
# session-end.sh - Stop 훅
#
# 세션이 끝날 때 현재 git 상태 스냅샷을 ~/.claude/session-snapshots/ 에 저장합니다.
# 다음 세션에서 "어디까지 했는지" 빠르게 복원하기 위한 기록.
#
# 성능: 비동기 실행 (& disown) — 훅이 세션 종료를 지연시키지 않음.

set -euo pipefail

snap_dir="$HOME/.claude/session-snapshots"
mkdir -p "$snap_dir"

cwd="$(pwd)"
ts="$(date +%Y%m%d-%H%M%S)"
repo_tag="$(basename "$cwd")"
snap_file="$snap_dir/${repo_tag}-${ts}.md"

{
  echo "# 세션 종료 스냅샷 — $repo_tag"
  echo
  echo "- **시각**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- **CWD**: \`$cwd\`"

  if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "- **브랜치**: \`$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)\`"
    echo "- **HEAD**: \`$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)\`"
    echo
    echo '## git status'
    echo '```'
    git -C "$cwd" status --short 2>/dev/null || true
    echo '```'
    echo
    echo '## 마지막 커밋 3건'
    echo '```'
    git -C "$cwd" log --oneline -3 2>/dev/null || true
    echo '```'
  fi
} > "$snap_file" 2>/dev/null &
disown 2>/dev/null || true

# 오래된 스냅샷 정리 (30일 초과)
find "$snap_dir" -name '*.md' -mtime +30 -delete 2>/dev/null &
disown 2>/dev/null || true

exit 0
