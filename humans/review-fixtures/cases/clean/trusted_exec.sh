#!/usr/bin/env bash
# 세션 종료 훅 — 사용자가 옵트인한 신뢰 경로의 스크립트만 실행한다.
set -euo pipefail

# 신뢰 경계: 레포가 아니라 사용자 홈의 스크립트 + 명시 옵트인.
user_hook="$HOME/.config/cockpit/post-stop.sh"
if [[ "${COCKPIT_ALLOW_HOOKS:-0}" == "1" && -x "$user_hook" ]]; then
  "$user_hook"
fi
