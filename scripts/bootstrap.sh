#!/usr/bin/env bash
# scripts/bootstrap.sh
#
# claude-cockpit 원클릭 부트스트랩.
# 새 장비에서 cockpit 환경을 1줄로 설치합니다.
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/bluebird702/claude-cockpit/main/scripts/bootstrap.sh | bash -s -- --no-mcp
#
# 환경변수:
#   COCKPIT_HOME — 클론 위치 (기본: $HOME/Work/claude-cockpit)
#   COCKPIT_REPO — 원격 URL (기본: https://github.com/bluebird702/claude-cockpit.git)
#   COCKPIT_REF  — 브랜치/태그 (기본: main)
#
# install.sh 인자는 그대로 전달됩니다: --force / --no-mcp / --no-plugins / --skip-doctor

set -euo pipefail

TARGET="${COCKPIT_HOME:-$HOME/Work/claude-cockpit}"
REPO="${COCKPIT_REPO:-https://github.com/bluebird702/claude-cockpit.git}"
REF="${COCKPIT_REF:-main}"

bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
ok()     { printf '\033[32m✓\033[0m %s\n' "$*"; }
step()   { printf '\033[34m→\033[0m %s\n' "$*"; }
die()    { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

bold "🛰  claude-cockpit bootstrap"

command -v git >/dev/null 2>&1 || die "git 필요 — 먼저 설치하세요 (macOS: xcode-select --install)"

if [ -d "$TARGET/.git" ]; then
  step "기존 cockpit 갱신: $TARGET"
  git -C "$TARGET" fetch --quiet origin
  git -C "$TARGET" checkout --quiet "$REF"
  git -C "$TARGET" pull --ff-only --quiet
  ok "최신 $REF 동기화 완료"
else
  step "cockpit 클론: $REPO → $TARGET"
  mkdir -p "$(dirname "$TARGET")"
  git clone --quiet --branch "$REF" "$REPO" "$TARGET"
  ok "클론 완료"
fi

step "install.sh 실행 ($*)"
exec "$TARGET/install.sh" "$@"
