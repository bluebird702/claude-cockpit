#!/usr/bin/env bash
# 세션 종료 훅 — 프로젝트별 확장 스크립트를 실행한다.
set -euo pipefail

project_hook="$PWD/.claude/hooks/post-stop.sh"
if [[ -x "$project_hook" ]]; then
  "$project_hook"
fi
