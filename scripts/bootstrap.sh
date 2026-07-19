#!/usr/bin/env bash
# scripts/bootstrap.sh
#
# claude-cockpit 원클릭 부트스트랩.
# 새 장비에서 cockpit 환경을 1줄로 설치하거나, 설치된 링크를 1줄로 제거합니다.
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --no-mcp
#   curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --clean
#   curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --clean --all
#
# 동작:
#   - 기본 (--clean 없음): clone(없으면) + fetch/pull → install.sh 위임
#   - --clean: clone(없으면 skip) + fetch/pull → uninstall.sh 위임
#   - 두 경우 모두 멱등 (재실행 안전). cockpit 레포는 절대 자동 삭제하지 않음.
#
# 환경변수:
#   COCKPIT_HOME — 클론 위치 (기본: $HOME/Work/claude-cockpit)
#   COCKPIT_REPO — 원격 URL (기본: https://github.com/bluebird702/claude-cockpit.git)
#   COCKPIT_REF  — 브랜치/태그 (기본: main)
#
# 인자 패스스루:
#   install.sh   ← --force / --no-mcp / --no-plugins / --skip-doctor
#   uninstall.sh ← --with-mcp / --purge-mcp / --stop-colima / --purge-memory / --all / --yes

set -euo pipefail

TARGET="${COCKPIT_HOME:-$HOME/Work/claude-cockpit}"
REPO="${COCKPIT_REPO:-https://github.com/bluebird702/claude-cockpit.git}"
REF="${COCKPIT_REF:-main}"

bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
ok()     { printf '\033[32m✓\033[0m %s\n' "$*"; }
step()   { printf '\033[34m→\033[0m %s\n' "$*"; }
warn()   { printf '\033[33m⚠\033[0m %s\n' "$*"; }
die()    { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# --clean 플래그 추출 (나머지 인자는 위임 대상으로 패스스루)
DO_CLEAN=0
DELEGATE_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --clean) DO_CLEAN=1 ;;
    *)       DELEGATE_ARGS+=("$arg") ;;
  esac
done

bold "🛰  claude-cockpit bootstrap"

command -v git >/dev/null 2>&1 || die "git 필요 — 먼저 설치하세요 (macOS: xcode-select --install)"

# 클론 상태 처리
if [ -d "$TARGET/.git" ]; then
  step "기존 cockpit 갱신: $TARGET"
  git -C "$TARGET" fetch --quiet origin
  git -C "$TARGET" checkout --quiet "$REF"
  if git -C "$TARGET" symbolic-ref -q HEAD >/dev/null; then
    git -C "$TARGET" pull --ff-only --quiet
  fi
  ok "최신 $REF 동기화 완료"
elif [ "$DO_CLEAN" = "1" ]; then
  warn "cockpit 클론 없음 ($TARGET) — 이미 깨끗한 상태입니다."
  exit 0
else
  step "cockpit 클론: $REPO → $TARGET"
  mkdir -p "$(dirname "$TARGET")"
  git clone --quiet --branch "$REF" "$REPO" "$TARGET"
  ok "클론 완료"
fi

# 위임 (install.sh or uninstall.sh)
if [ "$DO_CLEAN" = "1" ]; then
  step "uninstall.sh 실행 (${DELEGATE_ARGS[*]:-})"
  exec "$TARGET/uninstall.sh" ${DELEGATE_ARGS[@]+"${DELEGATE_ARGS[@]}"}
else
  step "install.sh 실행 (${DELEGATE_ARGS[*]:-})"
  exec "$TARGET/install.sh" ${DELEGATE_ARGS[@]+"${DELEGATE_ARGS[@]}"}
fi
