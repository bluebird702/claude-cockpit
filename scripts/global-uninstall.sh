#!/usr/bin/env bash
# scripts/global-uninstall.sh
# cockpit 소유의 심볼릭 링크를 ~/.claude 에서 제거합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/tui.sh"

tui_banner "Claude Cockpit · Global Uninstall" "심볼릭 링크 제거 (실제 파일은 건드리지 않음)"

CLAUDE_DIR="$(claude_home)"
BACKUP_DIR="$(make_backup_dir global-uninstall)"
log_ok "백업 디렉토리: $BACKUP_DIR"

remove_link() {
  local dst="$1"
  if [ -L "$dst" ]; then
    local target
    target="$(readlink "$dst")"
    case "$target" in
      "$ROOT_DIR"/*|"$ROOT_DIR")
        backup_path "$dst" "$BACKUP_DIR"
        rm "$dst"
        log_ok "  - $dst 제거 (→ $target)"
        ;;
      *)
        log_dim "  ~ $dst 는 cockpit 소유가 아님 (건너뜀)"
        ;;
    esac
  else
    log_dim "  · $dst 없음"
  fi
}

log_step "global 파일"
remove_link "$CLAUDE_DIR/CLAUDE.md"
remove_link "$CLAUDE_DIR/settings.json"
remove_link "$CLAUDE_DIR/keybindings.json"

log_step "skills 카테고리"
for cat_dir in "$ROOT_DIR"/skills/*/; do
  [ -d "$cat_dir" ] || continue
  cat_name="$(basename "$cat_dir")"
  remove_link "$CLAUDE_DIR/commands/$cat_name"
done

printf '\n'
log_ok "제거 완료"
log_dim "  백업: $BACKUP_DIR"
log_warn "MCP 설정은 별도입니다: mcp/clean.sh --purge-env"
