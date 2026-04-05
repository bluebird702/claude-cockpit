#!/usr/bin/env bash
# scripts/project-link.sh
#
# cockpit을 submodule 로 추가한 소비 프로젝트에서, 원하는 영역만 심볼릭 링크로 노출합니다.
#
# 사용법 (소비 프로젝트 루트에서):
#   .cockpit/scripts/project-link.sh \
#     --with standards \
#     --with skills/dev \
#     --with skills/ci \
#     --with docs/process
#
#   --reapply   기존 링크를 모두 재생성 (submodule 업데이트 후 사용)
#   --dry-run   실제 링크 생성 없이 결과만 출력

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COCKPIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$COCKPIT_ROOT/scripts/lib/common.sh"
source "$COCKPIT_ROOT/scripts/lib/tui.sh"

# 프로젝트 루트 = cockpit 의 부모 (submodule 로 .cockpit 에 들어 있다고 가정)
PROJECT_ROOT="$(cd "$COCKPIT_ROOT/.." && pwd)"

declare -a WITH=()
OPT_REAPPLY=0
OPT_DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --with)      WITH+=("$2"); shift 2 ;;
    --with=*)    WITH+=("${1#*=}"); shift ;;
    --reapply)   OPT_REAPPLY=1; shift ;;
    --dry-run)   OPT_DRY_RUN=1; shift ;;
    --project)   PROJECT_ROOT="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $0 --with <area> [--with <area>...] [--reapply] [--dry-run]

Areas:
  standards          → <project>/docs/standards
  skills/<category>  → <project>/.claude/commands/<category>
  docs/<name>        → <project>/docs/<name>
  global/CLAUDE.md   → <project>/CLAUDE.md (없을 때만 복사, 링크 아님)

Examples:
  $0 --with standards --with skills/dev --with skills/ci --with docs/process
EOF
      exit 0 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

[ ${#WITH[@]} -eq 0 ] && die "--with 옵션이 하나 이상 필요합니다 (--help 참조)"

tui_banner "Claude Cockpit · Project Link" "프로젝트: $PROJECT_ROOT"
log_ok "cockpit root: $COCKPIT_ROOT"
log_ok "project root: $PROJECT_ROOT"

# 대상 매핑
# area → [src_abs, dst_abs]
resolve_link() {
  local area="$1"
  case "$area" in
    standards)
      echo "$COCKPIT_ROOT/core/standards|$PROJECT_ROOT/docs/standards"
      ;;
    skills/*)
      local cat="${area#skills/}"
      local src="$COCKPIT_ROOT/humans/skills/$cat"
      [ -d "$src" ] || die "존재하지 않는 카테고리: $area"
      echo "$src|$PROJECT_ROOT/.claude/commands/$cat"
      ;;
    docs/*)
      local name="${area#docs/}"
      local src="$COCKPIT_ROOT/docs/$name"
      [ -d "$src" ] || die "존재하지 않는 docs 영역: $area"
      echo "$src|$PROJECT_ROOT/docs/$name"
      ;;
    global/CLAUDE.md)
      # 링크 아닌 복사 대상
      echo "COPY|$COCKPIT_ROOT/core/standards/templates/CLAUDE.md.template|$PROJECT_ROOT/CLAUDE.md"
      ;;
    *)
      die "알 수 없는 영역: $area"
      ;;
  esac
}

do_link() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then
    log_warn "  원본 없음: $src (건너뜀)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    local current
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      log_dim "  = $dst → $src (이미 연결됨)"
      return 0
    fi
    if [ "$OPT_REAPPLY" = "1" ]; then
      [ "$OPT_DRY_RUN" = "1" ] || rm "$dst"
      log_dim "  ↻ $dst (재생성)"
    else
      die "다른 링크가 이미 존재합니다: $dst → $current (--reapply 필요)"
    fi
  elif [ -e "$dst" ]; then
    die "실제 파일/디렉토리가 이미 존재합니다: $dst"
  fi

  if [ "$OPT_DRY_RUN" = "1" ]; then
    log_info "  [dry-run] ln -s $src $dst"
  else
    ln -s "$src" "$dst"
    log_ok "  + $dst → $src"
  fi
}

do_copy_if_absent() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    log_dim "  = $dst 이미 존재 (건너뜀)"
    return 0
  fi
  if [ "$OPT_DRY_RUN" = "1" ]; then
    log_info "  [dry-run] cp $src $dst"
  else
    cp "$src" "$dst"
    log_ok "  + $dst (복사)"
  fi
}

log_step "링크 생성"
for area in "${WITH[@]}"; do
  mapping="$(resolve_link "$area")"
  if [[ "$mapping" == COPY\|* ]]; then
    IFS='|' read -r _ src dst <<< "$mapping"
    do_copy_if_absent "$src" "$dst"
  else
    IFS='|' read -r src dst <<< "$mapping"
    do_link "$src" "$dst"
  fi
done

printf '\n'
log_ok "project-link 완료"
log_dim "  되돌리기: .cockpit/scripts/project-unlink.sh --with ..."
