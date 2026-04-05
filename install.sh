#!/usr/bin/env bash
# install.sh
#
# 전역 설치(global-install)와 MCP 설정(mcp/setup)을 한 번에 실행하는 래퍼.
# 내부적으로 `scripts/global-install.sh --with-mcp "$@"` 와 동일합니다.
#
# 사용법:
#   ./install.sh               # 전역 + MCP + 플러그인 설치
#   ./install.sh --force       # 기존 실제 파일도 백업 후 덮어씀
#   ./install.sh --no-mcp      # MCP 단계 건너뜀
#   ./install.sh --no-plugins  # 플러그인 설치 건너뜀 (오프라인 환경)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_MCP=1
PASS_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --no-mcp) WITH_MCP=0; shift ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) PASS_ARGS+=("$1"); shift ;;
  esac
done

if [ "$WITH_MCP" = "1" ]; then
  exec "$SCRIPT_DIR/scripts/global-install.sh" --with-mcp ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
else
  exec "$SCRIPT_DIR/scripts/global-install.sh" ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
fi
