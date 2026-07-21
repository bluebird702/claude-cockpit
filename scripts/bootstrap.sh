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
#   install.sh   ← --force / --no-mcp / --no-plugins / --skip-configure
#   uninstall.sh ← --with-mcp / --purge-mcp / --stop-colima / --purge-memory / --all / --yes

set -euo pipefail

parse_arguments() {
  OPT_CLEAN=0
  OPT_ALL=0
  OPT_NO_MCP=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --clean)  OPT_CLEAN=1; shift ;;
      --all)    OPT_ALL=1; shift ;;
      --no-mcp) OPT_NO_MCP=1; shift ;;
      *)        shift ;;
    esac
  done
}

setup_env() {
  COCKPIT_HOME="${COCKPIT_HOME:-$HOME/Work/claude-cockpit}"
  COCKPIT_REPO="${COCKPIT_REPO:-https://github.com/bluebird702/claude-cockpit.git}"
}

clone_or_pull_repo() {
  if [ ! -d "$COCKPIT_HOME/.git" ]; then
    if [ "$OPT_CLEAN" = "1" ]; then
      echo "이미 설치된 cockpit 레포지토리가 없습니다: $COCKPIT_HOME"
      exit 0
    fi
    echo "▶ Claude Cockpit 저장소 클론 ($COCKPIT_HOME)..."
    mkdir -p "$(dirname "$COCKPIT_HOME")"
    git clone "$COCKPIT_REPO" "$COCKPIT_HOME"
    cd "$COCKPIT_HOME"
  else
    echo "▶ 기존 저장소 감지됨. 최신화 중..."
    cd "$COCKPIT_HOME"
    git fetch origin main
    git reset --hard origin/main
  fi
}

run_action() {
  if [ "$OPT_CLEAN" = "1" ]; then
    echo "▶ uninstall.sh 실행..."
    local args=()
    [ "$OPT_ALL" = "1" ] && args+=("--all")
    bash scripts/global-uninstall.sh "${args[@]:-}"
    echo "✓ 삭제 성공. (레포지토리 폴더는 보존됨: $COCKPIT_HOME)"
  else
    echo "▶ install.sh 실행..."
    local args=()
    [ "$OPT_NO_MCP" = "1" ] && args+=("--no-mcp")
    bash install.sh "${args[@]:-}"
    echo "✓ 설치 성공. Claude Code 를 재시작하세요."
  fi
}

main() {
  parse_arguments "$@"
  setup_env
  clone_or_pull_repo
  run_action
}

main "$@"
