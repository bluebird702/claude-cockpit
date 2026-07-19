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
    if [ -d "$dir/core" ] && [ -d "$dir/humans" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  die "cockpit 루트를 찾을 수 없습니다 (core/, humans/ 존재 필요)."
}

claude_home() {
  echo "${CLAUDE_HOME:-$HOME/.claude}"
}

# ─────────────────────────────────────────────
# 템플릿 렌더링
# ─────────────────────────────────────────────
# detect_template_vars — 템플릿 치환에 쓸 환경 변수를 수집해 export
#
# 출력 (export):
#   COCKPIT_HOME   cockpit 레포 절대 경로 (호출 시 인자로 전달)
#   USER_NAME      COCKPIT_USER_NAME > $USER > git user.name > "user"
#                  (git user.name 은 회사 아이덴티티일 수 있어 로컬 계정을 우선)
#   GITHUB_ORG     gh api user --jq .login, 없으면 "<YOUR_ORG>"
#
# 사용:
#   detect_template_vars "$ROOT_DIR"
detect_template_vars() {
  export COCKPIT_HOME="${1:-$(pwd)}"
  export HOME_DIR="$HOME"  # sed 치환용 alias
  if [ -z "${USER_NAME:-}" ]; then
    USER_NAME="${COCKPIT_USER_NAME:-${USER:-}}"
    [ -z "$USER_NAME" ] && USER_NAME="$(git config --get user.name 2>/dev/null || true)"
    [ -z "$USER_NAME" ] && USER_NAME="user"
    USER_NAME="$(_sanitize_tvar "$USER_NAME")"
    export USER_NAME
  fi
  if [ -z "${GITHUB_ORG:-}" ]; then
    GITHUB_ORG="$(gh api user --jq .login 2>/dev/null || true)"
    GITHUB_ORG="$(_sanitize_tvar "$GITHUB_ORG")"
    # gh 가 에러 본문(JSON 등)을 뱉는 경우가 있어 GitHub 계정명 형식만 수용
    printf '%s' "$GITHUB_ORG" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]{0,38}$' || GITHUB_ORG=""
    [ -z "$GITHUB_ORG" ] && GITHUB_ORG="<YOUR_ORG>"
    export GITHUB_ORG
  fi
}

# _sanitize_tvar — 템플릿 치환값 정화: CR/개행 제거 + sed 메타문자(| & \) 이스케이프
_sanitize_tvar() {
  printf '%s' "$1" | tr -d '\r\n' | sed -e 's/[\\&|]/\\&/g'
}

# render_template <src> <dst>
# {{HOME}}, {{COCKPIT_HOME}}, {{USER_NAME}}, {{GITHUB_ORG}} 을 실제 값으로 치환
# detect_template_vars 를 먼저 호출해야 합니다.
render_template() {
  local src="$1" dst="$2"
  [ -f "$src" ] || die "템플릿 원본 없음: $src"
  [ -n "${COCKPIT_HOME:-}" ] || die "detect_template_vars 를 먼저 호출하세요"
  mkdir -p "$(dirname "$dst")"
  local safe_home
  safe_home="$(_sanitize_tvar "$HOME")"
  local safe_cockpit
  safe_cockpit="$(_sanitize_tvar "$COCKPIT_HOME")"
  
  sed \
    -e "s|{{HOME}}|${safe_home}|g" \
    -e "s|{{COCKPIT_HOME}}|${safe_cockpit}|g" \
    -e "s|{{USER_NAME}}|${USER_NAME}|g" \
    -e "s|{{GITHUB_ORG}}|${GITHUB_ORG}|g" \
    "$src" > "$dst"
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
