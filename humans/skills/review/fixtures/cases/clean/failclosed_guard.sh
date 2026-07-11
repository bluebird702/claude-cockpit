#!/usr/bin/env bash
# PreToolUse 가드 훅 — 위험 명령을 차단한다.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq 필요 — 파싱 불가 시 안전을 위해 차단합니다." >&2
  exit 2
fi

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
case "$cmd" in
  *"rm -rf /"*) echo "위험 명령 차단" >&2; exit 2 ;;
esac
exit 0
