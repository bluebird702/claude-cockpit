#!/usr/bin/env bash
# common.sh - 공통 유틸리티 (로그, 색상, 심볼릭 링크 헬퍼, 백업)
# 이 파일은 source 로만 사용합니다.

set -euo pipefail

# ─────────────────────────────────────────────
# 색상 (tput 우선, 미지원 시 ANSI 코드)
# ─────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET=$(tput sgr0)
  C_BOLD=$(tput bold)
  C_DIM=$(tput dim)
  C_RED=$(tput setaf 1)
  C_GREEN=$(tput setaf 2)
  C_YELLOW=$(tput setaf 3)
  C_BLUE=$(tput setaf 4)
  C_MAGENTA=$(tput setaf 5)
  C_CYAN=$(tput setaf 6)
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''
fi

# ─────────────────────────────────────────────
# 로그 함수
# ─────────────────────────────────────────────
log_info()    { printf '%s[INFO]%s %s\n'  "$C_BLUE"   "$C_RESET" "$*"; }
log_ok()      { printf '%s ✔%s %s\n'       "$C_GREEN"  "$C_RESET" "$*"; }
log_warn()    { printf '%s ⚠%s %s\n'       "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()     { printf '%s ✘%s %s\n'       "$C_RED"    "$C_RESET" "$*" >&2; }
log_step()    { printf '\n%s%s▸ %s%s\n'    "$C_BOLD"   "$C_CYAN" "$*" "$C_RESET"; }
log_dim()     { printf '%s%s%s\n'          "$C_DIM"    "$*"       "$C_RESET"; }

die() { log_err "$*"; exit 1; }

# ─────────────────────────────────────────────
# 실행 환경
# ─────────────────────────────────────────────
require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' 명령이 필요합니다. 먼저 설치하세요."
  done
}

# ─────────────────────────────────────────────
# 경로
# ─────────────────────────────────────────────
cockpit_root() {
  # scripts/*.sh 또는 mcp/*.sh 에서 호출될 수 있으므로 git rev-parse 또는 상대경로 탐색
  local here="${BASH_SOURCE[1]:-$0}"
  local dir
  dir="$(cd "$(dirname "$here")" && pwd)"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/standards" ] && [ -d "$dir/skills" ] && [ -d "$dir/global" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  die "cockpit 루트를 찾을 수 없습니다 (standards/, skills/, global/ 존재 필요)."
}

claude_home() {
  echo "${CLAUDE_HOME:-$HOME/.claude}"
}

# ─────────────────────────────────────────────
# 백업
# ─────────────────────────────────────────────
make_backup_dir() {
  local tag="${1:-cockpit}"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local dir
  dir="$(claude_home)/backups/${tag}-${ts}"
  mkdir -p "$dir"
  echo "$dir"
}

backup_path() {
  # backup_path <src_path> <backup_dir>
  local src="$1" dir="$2"
  [ -e "$src" ] || return 0
  local name
  name="$(basename "$src")"
  if [ -L "$src" ]; then
    cp -P "$src" "$dir/$name"
  elif [ -d "$src" ]; then
    cp -R "$src" "$dir/$name"
  else
    cp "$src" "$dir/$name"
  fi
}

# ─────────────────────────────────────────────
# 심볼릭 링크 (멱등)
# ─────────────────────────────────────────────
# link_idempotent <src> <dst>
# - dst가 이미 src를 가리키면 no-op
# - dst가 다른 곳을 가리키는 symlink면 교체 (백업은 호출자 책임)
# - dst가 실제 파일/디렉토리면 오류 (덮어쓰기 방지)
link_idempotent() {
  local src="$1" dst="$2"
  [ -e "$src" ] || die "링크 원본이 존재하지 않습니다: $src"
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    local current
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      log_dim "  = $dst → $src (이미 연결됨)"
      return 0
    fi
    rm "$dst"
    ln -s "$src" "$dst"
    log_ok "  ↻ $dst → $src (교체)"
    return 0
  fi

  if [ -e "$dst" ]; then
    die "실제 파일/디렉토리가 이미 존재합니다: $dst (먼저 백업·제거 필요)"
  fi

  ln -s "$src" "$dst"
  log_ok "  + $dst → $src"
}

unlink_if_cockpit() {
  # unlink_if_cockpit <dst> <cockpit_root>
  # dst가 cockpit 내부를 가리키는 symlink일 때만 제거
  local dst="$1" root="$2"
  [ -L "$dst" ] || return 0
  local target
  target="$(readlink "$dst")"
  case "$target" in
    "$root"/*|"$root") rm "$dst"; log_ok "  - $dst 제거됨" ;;
    *)                 log_dim "  ~ $dst 는 cockpit 소유가 아님 (건너뜀)" ;;
  esac
}
