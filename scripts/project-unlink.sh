#!/usr/bin/env bash
# scripts/project-unlink.sh
# project-link.sh 로 만든 심볼릭 링크를 제거합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COCKPIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$COCKPIT_ROOT/scripts/lib/common.sh"
source "$COCKPIT_ROOT/scripts/lib/tui.sh"

PROJECT_ROOT="$(cd "$COCKPIT_ROOT/.." && pwd)"
declare -a WITH=()
OPT_ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --with)    WITH+=("$2"); shift 2 ;;
    --with=*)  WITH+=("${1#*=}"); shift ;;
    --all)     OPT_ALL=1; shift ;;
    --project) PROJECT_ROOT="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--with <area>... | --all]
  --all  cockpit 소유의 모든 링크 제거 (standards, skills/*, docs/*)
EOF
      exit 0 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

tui_banner "Claude Cockpit · Project Unlink" "프로젝트: $PROJECT_ROOT"

try_remove() {
  local dst="$1"
  if [ -L "$dst" ]; then
    local target
    target="$(readlink "$dst")"
    case "$target" in
      "$COCKPIT_ROOT"/*)
        rm "$dst"
        log_ok "  - $dst (→ $target)"
        ;;
      *)
        log_dim "  ~ $dst 는 cockpit 소유가 아님"
        ;;
    esac
  else
    log_dim "  · $dst 링크 아님/없음"
  fi
}

if [ "$OPT_ALL" = "1" ]; then
  try_remove "$PROJECT_ROOT/docs/standards"
  for cat_dir in "$COCKPIT_ROOT"/humans/skills/*/; do
    [ -d "$cat_dir" ] || continue
    try_remove "$PROJECT_ROOT/.claude/commands/$(basename "$cat_dir")"
  done
  for d in "$COCKPIT_ROOT"/docs/*/; do
    [ -d "$d" ] || continue
    try_remove "$PROJECT_ROOT/docs/$(basename "$d")"
  done
else
  [ ${#WITH[@]} -eq 0 ] && die "--with 또는 --all 이 필요합니다"
  for area in "${WITH[@]}"; do
    case "$area" in
      standards)    try_remove "$PROJECT_ROOT/docs/standards" ;;
      skills/*)     try_remove "$PROJECT_ROOT/.claude/commands/${area#skills/}" ;;
      docs/*)       try_remove "$PROJECT_ROOT/docs/${area#docs/}" ;;
      *) log_warn "알 수 없는 영역: $area" ;;
    esac
  done
fi

printf '\n'
log_ok "project-unlink 완료"
