#!/usr/bin/env bash
# scripts/global-uninstall.sh
#
# install.sh 와 대칭으로, cockpit 이 ~/.claude 에 설치한 항목을 제거합니다.
#
# 기본 동작 (안전): cockpit 소유 심볼릭 링크만 제거. 실제 파일·유저 데이터는 보존.
#
# 옵션:
#   --with-mcp       settings.json 에서 cockpit 관리 MCP 서버 제거
#   --purge-mcp      + Keychain 비밀·mcp.public.env·로더·rc source 라인 제거
#   --stop-colima    Colima 데몬 정지 (setup.sh 가 자동 시작한 것과 대칭)
#   --purge-memory   system/memory-seed 에 대응하는 ~/.claude/memory/*.md 제거
#                    (유저가 신규 작성한 파일·MEMORY.md 는 보존)
#   --all            위 모두 (--purge-memory 제외) + --with-mcp + --purge-mcp + --stop-colima
#   --yes, -y        확인 자동 승인

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/tui.sh"

OPT_WITH_MCP=0
OPT_PURGE_MCP=0
OPT_STOP_COLIMA=0
OPT_PURGE_MEMORY=0
OPT_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --with-mcp)     OPT_WITH_MCP=1; shift ;;
    --purge-mcp)    OPT_WITH_MCP=1; OPT_PURGE_MCP=1; shift ;;
    --stop-colima)  OPT_STOP_COLIMA=1; shift ;;
    --purge-memory) OPT_PURGE_MEMORY=1; shift ;;
    --all)          OPT_WITH_MCP=1; OPT_PURGE_MCP=1; OPT_STOP_COLIMA=1; shift ;;
    --yes|-y)       OPT_YES=1; shift ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

tui_banner "Claude Cockpit · Global Uninstall" "install.sh 대칭 제거 · 유저 데이터 보존"

CLAUDE_DIR="$(claude_home)"
BACKUP_DIR="$(make_backup_dir global-uninstall)"
log_ok "백업 디렉토리: $BACKUP_DIR"

# ─────────────────────────────────────────────
# 요약
# ─────────────────────────────────────────────
printf '\n  %s제거 대상:%s\n' "$C_BOLD" "$C_RESET"
printf '    · ~/.claude/{CLAUDE.md, settings.json, keybindings.json} (cockpit 링크만)\n'
printf '    · ~/.claude/commands/<skills 카테고리> (cockpit 링크만)\n'
printf '    · ~/.claude/agents (cockpit 링크만)\n'
[ "$OPT_WITH_MCP" = "1" ]     && printf '    · MCP 서버 (settings.json)\n'
[ "$OPT_PURGE_MCP" = "1" ]    && printf '    · MCP 비밀·공개 env·로더·rc source 라인\n'
[ "$OPT_STOP_COLIMA" = "1" ]  && printf '    · Colima 데몬 정지\n'
[ "$OPT_PURGE_MEMORY" = "1" ] && printf '    · ~/.claude/memory/ 시드 파일 (유저 신규 파일은 보존)\n'
printf '    · 가장 최근 설치(global-*) 시점의 백업본으로 롤백 (Colima, MCP 등 제외)\n'

printf '\n  %s보존:%s\n' "$C_BOLD" "$C_RESET"
printf '    · ~/.claude/backups/ (복구 자산)\n'
printf '    · ~/.claude/plugins/ (Claude Code 관리)\n'
[ "$OPT_PURGE_MEMORY" = "0" ] && printf '    · ~/.claude/memory/ (대화 자산)\n'
printf '    · Homebrew 로 설치된 colima/docker 바이너리\n'

if [ "$OPT_YES" = "0" ]; then
  if ! tui_confirm "이대로 진행하시겠습니까?" N; then
    log_warn "사용자 취소"
    exit 0
  fi
fi

# ─────────────────────────────────────────────
# 공통 helper
# ─────────────────────────────────────────────
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

remove_global_files() {
  log_step "Phase 1 · global 파일"
  remove_link "$CLAUDE_DIR/CLAUDE.md"
  remove_link "$CLAUDE_DIR/settings.json"
  remove_link "$CLAUDE_DIR/keybindings.json"
  remove_link "$HOME/.gitmessage"
  if command -v git > /dev/null 2>&1 \
     && [ "$(git config --global --get commit.template 2>/dev/null)" = "$HOME/.gitmessage" ]; then
    git config --global --unset commit.template
    log_ok "  - git commit.template 설정 해제"
  fi
}

unlink_skill_categories() {
  log_step "Phase 2 · skills 카테고리"
  for cat_dir in "$ROOT_DIR"/skills/*/; do
    [ -d "$cat_dir" ] || continue
    cat_name="$(basename "$cat_dir")"
    remove_link "$CLAUDE_DIR/commands/$cat_name"
  done
}

unlink_agy_skills() {
  log_step "Phase 2.5 · AGY(Gemini) skills"
  local AGY_SKILLS_DIR="$HOME/.gemini/antigravity-cli/skills"
  if [ -d "$AGY_SKILLS_DIR" ]; then
    for src_file in "$ROOT_DIR"/skills/*/*.md; do
      [ -f "$src_file" ] || continue
      [[ "$src_file" == *.ko.md ]] && continue
      
      local file_name
      file_name="$(basename "$src_file")"
      
      if [ -f "$AGY_SKILLS_DIR/$file_name" ]; then
        backup_path "$AGY_SKILLS_DIR/$file_name" "$BACKUP_DIR"
        rm -f "$AGY_SKILLS_DIR/$file_name"
        log_ok "  - $AGY_SKILLS_DIR/$file_name 제거"
      fi
    done
  else
    log_dim "  · $AGY_SKILLS_DIR 없음"
  fi
}

unlink_subagents() {
  log_step "Phase 3 · agents 링크"
  local AGENTS_DST="$CLAUDE_DIR/agents"
  if [ -L "$AGENTS_DST" ]; then
    remove_link "$AGENTS_DST"
  elif [ -d "$AGENTS_DST" ] && [ ! -L "$AGENTS_DST" ]; then
    log_dim "  · $AGENTS_DST 는 실제 디렉토리 — 개별 cockpit 링크만 제거"
    for f in "$AGENTS_DST"/*.md; do
      [ -L "$f" ] || continue
      remove_link "$f"
    done
  else
    log_dim "  · $AGENTS_DST 없음"
  fi
}

clean_mcp_servers() {
  if [ "$OPT_WITH_MCP" = "1" ] || [ "$OPT_STOP_COLIMA" = "1" ]; then
    log_step "Phase 4 · MCP"
    local CLEAN_ARGS=(--yes)
    [ "$OPT_PURGE_MCP" = "1" ]   && CLEAN_ARGS+=(--purge-env)
    [ "$OPT_STOP_COLIMA" = "1" ] && CLEAN_ARGS+=(--stop-colima)
    "$ROOT_DIR/system/mcp-shared/clean.sh" "${CLEAN_ARGS[@]}" \
      || log_warn "MCP clean 중 일부 단계 실패 — 로그 확인 필요"
  else
    log_dim "  · Phase 4 (MCP) 건너뜀 — 필요 시 --with-mcp / --purge-mcp / --stop-colima"
  fi
}

purge_memory_seeds() {
  if [ "$OPT_PURGE_MEMORY" = "1" ]; then
    log_step "Phase 5 · memory 시드 제거"
    local MEMORY_DIR="$CLAUDE_DIR/memory"
    local SEED_DIR="$ROOT_DIR/system/memory-seed"
    local LOCAL_DIR="$ROOT_DIR/.cockpit-local"
    if [ -d "$MEMORY_DIR" ] && [ -d "$SEED_DIR" ]; then
      local removed=0
      for src in "$LOCAL_DIR"/memory-seed/*.md "$SEED_DIR"/*.md; do
        [ -f "$src" ] || continue
        case "$src" in *.template) continue ;; esac
        local name dst
        name="$(basename "$src")"
        dst="$MEMORY_DIR/$name"
        if [ -f "$dst" ]; then
          backup_path "$dst" "$BACKUP_DIR"
          rm "$dst"
          log_ok "  - $name 제거 (백업됨)"
          removed=$((removed+1))
        fi
      done
      log_dim "  · ${removed}개 시드 파일 제거. MEMORY.md 및 유저 신규 파일은 보존"
    else
      log_dim "  · memory 또는 seed 디렉토리 없음 (건너뜀)"
    fi
  else
    log_dim "  · Phase 5 (memory) 건너뜀 — 필요 시 --purge-memory"
  fi
}

rollback_to_latest_backup() {
  log_step "Phase 6 · 이전 설치 상태 롤백"
  local LATEST_BACKUP
  LATEST_BACKUP="$(find "$CLAUDE_DIR/backups" -maxdepth 1 -type d -name "global-[0-9]*" 2>/dev/null | sort -r | head -n 1 || true)"

  if [ -n "$LATEST_BACKUP" ]; then
    if [ "$OPT_YES" = "1" ] || tui_confirm "최근 설치 시점의 백업($LATEST_BACKUP)으로 롤백하시겠습니까?" Y; then
      log_info "롤백 진행 중..."
      if [ "$(ls -A "$LATEST_BACKUP")" ]; then
        cp -a "$LATEST_BACKUP/"* "$CLAUDE_DIR/" 2>/dev/null || log_warn "일부 파일 롤백 실패"
        log_ok "  - 롤백 성공: $LATEST_BACKUP 의 내용을 복원했습니다."
      else
        log_dim "  · 백업본이 비어있어 롤백할 내용이 없습니다."
      fi
    else
      log_dim "  · 사용자가 롤백을 건너뛰었습니다."
    fi
  else
    log_dim "  · 이전 백업을 찾을 수 없어 롤백을 생략합니다."
  fi
}

summary() {
  printf '\n'
  log_ok "제거 완료"
  log_dim "  백업: $BACKUP_DIR"
  [ "$OPT_WITH_MCP" = "0" ] && log_dim "  MCP 는 그대로입니다 — 필요 시 uninstall.sh --with-mcp 또는 --purge-mcp" || true
  exit 0
}

main() {
  remove_global_files
  unlink_skill_categories
  unlink_agy_skills
  unlink_subagents
  clean_mcp_servers
  purge_memory_seeds
  rollback_to_latest_backup
  summary
}

main "$@"
