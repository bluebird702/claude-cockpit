#!/usr/bin/env bash
# uninstall.sh
#
# install.sh 대칭 wrapper — cockpit 이 ~/.claude 에 설치한 항목을 제거합니다.
# 내부적으로 `scripts/global-uninstall.sh "$@"` 를 호출합니다.
#
# 기본 동작 (안전): cockpit 소유 심볼릭 링크만 제거. 유저 데이터는 보존.
#
# 사용법:
#   ./uninstall.sh                  # 링크만 제거 (안전)
#   ./uninstall.sh --with-mcp       # + settings.json 에서 MCP 서버 제거
#   ./uninstall.sh --purge-mcp      # + MCP 비밀·공개 env·로더·rc 라인 제거
#   ./uninstall.sh --stop-colima    # + Colima 데몬 정지
#   ./uninstall.sh --purge-memory   # + core/memory-seed 대응 memory 파일 제거
#   ./uninstall.sh --all            # 링크 + MCP + purge-mcp + stop-colima
#   ./uninstall.sh --yes            # 확인 생략

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

exec "$SCRIPT_DIR/scripts/global-uninstall.sh" "$@"
