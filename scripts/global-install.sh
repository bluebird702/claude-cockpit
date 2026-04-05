#!/usr/bin/env bash
# scripts/global-install.sh
#
# cockpit의 global/, skills/* 를 ~/.claude 에 심볼릭 링크로 설치합니다.
# 원본 수정이 즉시 반영되며, 기존 파일은 백업됩니다.
#
# 사용법:
#   scripts/global-install.sh [--with-mcp] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/tui.sh"

OPT_MCP=0
OPT_FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --with-mcp) OPT_MCP=1; shift ;;
    --force)    OPT_FORCE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]
  --with-mcp   설치 후 mcp/setup.sh 를 이어서 실행
  --force      기존 실제 파일도 백업 후 덮어씀 (심볼릭 아닌 경우)
EOF
      exit 0 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

tui_banner "Claude Cockpit · Global Install" "~/.claude 에 심볼릭 링크 설치"

# 1) 사전 점검
log_step "사전 점검"
require_cmd jq
CLAUDE_DIR="$(claude_home)"
mkdir -p "$CLAUDE_DIR/commands"
log_ok "claude home: $CLAUDE_DIR"
log_ok "cockpit root: $ROOT_DIR"

# 2) 백업 디렉토리
BACKUP_DIR="$(make_backup_dir global)"
log_ok "백업 디렉토리: $BACKUP_DIR"

# 3) 단일 파일 링크 (global/CLAUDE.md, settings.json, keybindings.json)
log_step "global 파일 링크"

link_file() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      log_dim "  = $dst (이미 연결됨)"
      return 0
    fi
    backup_path "$dst" "$BACKUP_DIR"
    if [ -L "$dst" ]; then
      rm "$dst"
    elif [ "$OPT_FORCE" = "1" ]; then
      rm -f "$dst"
    else
      die "실제 파일이 존재합니다: $dst (--force 로 덮어쓰거나 수동 삭제 필요)"
    fi
  fi
  ln -s "$src" "$dst"
  log_ok "  + $dst → $src"
}

link_file "$ROOT_DIR/global/CLAUDE.md"        "$CLAUDE_DIR/CLAUDE.md"
link_file "$ROOT_DIR/global/settings.json"    "$CLAUDE_DIR/settings.json"
link_file "$ROOT_DIR/global/keybindings.json" "$CLAUDE_DIR/keybindings.json"

# 4) skills/<category> 디렉토리 링크 → ~/.claude/commands/<category>
log_step "skills 카테고리 링크"

for cat_dir in "$ROOT_DIR"/skills/*/; do
  [ -d "$cat_dir" ] || continue
  cat_name="$(basename "$cat_dir")"
  dst="$CLAUDE_DIR/commands/$cat_name"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$cat_dir" ] || [ "$(readlink "$dst")" = "${cat_dir%/}" ]; then
      log_dim "  = $dst (이미 연결됨)"
      continue
    fi
    backup_path "$dst" "$BACKUP_DIR"
    rm "$dst"
  elif [ -e "$dst" ]; then
    backup_path "$dst" "$BACKUP_DIR"
    if [ "$OPT_FORCE" = "1" ]; then
      rm -rf "$dst"
    else
      die "실제 디렉토리가 존재합니다: $dst (--force 필요)"
    fi
  fi
  ln -s "${cat_dir%/}" "$dst"
  log_ok "  + $dst → ${cat_dir%/}"
done

# 5) MCP 설치 (옵션)
if [ "$OPT_MCP" = "1" ]; then
  log_step "MCP 설정 이어서 실행"
  "$ROOT_DIR/mcp/setup.sh"
fi

printf '\n'
log_ok "전역 설치 완료"
log_dim "  백업:  $BACKUP_DIR"
log_dim "  확인:  ls -la $CLAUDE_DIR"
printf '\n  %sClaude Code를 재시작하고 %s/dev:review%s 처럼 호출해 보세요.%s\n\n' \
  "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_RESET"
