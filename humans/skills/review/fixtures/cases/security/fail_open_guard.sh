#!/usr/bin/env bash
# PreToolUse 가드 훅 — 위험 명령을 차단한다.
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
case "$cmd" in
  *"rm -rf /"*) echo "위험 명령 차단" >&2; exit 2 ;;
esac
exit 0
