#!/usr/bin/env bash
# scripts/update.sh — 이미 설치된 머신을 최신 cockpit 으로 동기화
#
# 전체 재설치(install.sh)와 달리 doctor·대화형 MCP·플러그인을 건드리지 않고,
# git pull 이후 필요한 것만 갱신합니다. 재실행 안전(멱등).
#
# 갱신 항목:
#   U1  git pull --ff-only            (dirty 워킹트리면 스킵+경고)
#   U2  템플릿 재렌더                  (settings.json + memory-seed → .cockpit-local/)
#   U3  settings.json 동기화           — 심링크면 자동 반영 / 실파일 드리프트면 백업 후 jq 딥머지
#   U4  신규 스킬 카테고리·agents 링크 보강
#   U5  훅 실행권한·구문 검사
#   U6  메모리 시드                    — 신규만 추가 (+MEMORY.md 인덱스 누락 라인 보강)
#
# 사용법:
#   scripts/update.sh [--no-pull] [--reseed]
#     --no-pull   git pull 을 건너뜀 (직접 pull 한 경우)
#     --reseed    메모리 시드를 백업 후 렌더본으로 덮어씀 (USER_NAME 오검출 교정 등)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/scripts/lib/common.sh"

OPT_NO_PULL=0
OPT_RESEED=0

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-pull) OPT_NO_PULL=1; shift ;;
      --reseed)  OPT_RESEED=1; shift ;;
      -h|--help)
        sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
        exit 0 ;;
      *) die "알 수 없는 옵션: $1" ;;
    esac
  done
}

setup_globals() {
  if [ -f "$ROOT_DIR/.cockpit-local/.cockpit-env" ]; then
    source "$ROOT_DIR/.cockpit-local/.cockpit-env"
  fi

  require_cmd jq git
  CLAUDE_DIR="$(claude_home)"
  LOCAL_DIR="$ROOT_DIR/.cockpit-local"
  BACKUP_DIR="$(make_backup_dir update)"
}

pull_latest_changes() {
  log_step "U1 · git pull"

  if [ "$OPT_NO_PULL" = "1" ]; then
    log_dim "  · --no-pull — 건너뜀"
  elif [ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null)" ]; then
    log_warn "  워킹트리에 변경이 있어 pull 을 건너뜁니다 — 정리 후 다시 실행하거나 --no-pull 로 진행"
  elif ! git -C "$ROOT_DIR" symbolic-ref -q HEAD >/dev/null; then
    log_dim "  · detached HEAD (태그/특정 커밋) 상태이므로 pull 을 건너뜁니다."
  else
    local before after
    before="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"
    git -C "$ROOT_DIR" pull --ff-only || die "pull 실패 — 브랜치 상태를 확인하세요 (rebase 필요할 수 있음)"
    after="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"
    if [ "$before" = "$after" ]; then
      log_dim "  · 이미 최신 ($after)"
    else
      log_ok "  $before → $after"
    fi
  fi
}

render_all_templates() {
  log_step "U2 · 템플릿 재렌더"

  mkdir -p "$LOCAL_DIR/memory-seed"
  detect_template_vars "$ROOT_DIR"
  log_dim "  · USER_NAME=$USER_NAME (오버라이드: COCKPIT_USER_NAME)"

  local tmp_settings
  tmp_settings="$(mktemp)"
  render_template "$ROOT_DIR/system/settings.json.template" "$tmp_settings"
  if [ -f "$LOCAL_DIR/settings.json" ]; then
    local merged
    merged="$(mktemp)"
    if jq -s '.[0] * .[1]' "$LOCAL_DIR/settings.json" "$tmp_settings" > "$merged" 2>/dev/null \
       && jq empty "$merged" 2>/dev/null; then
      mv "$merged" "$LOCAL_DIR/settings.json"
    else
      rm -f "$merged"
      mv "$tmp_settings" "$LOCAL_DIR/settings.json"
    fi
  else
    mv "$tmp_settings" "$LOCAL_DIR/settings.json"
  fi
  rm -f "$tmp_settings"
  log_ok "  ↻ .cockpit-local/settings.json (딥머지 완료)"

  for t in "$ROOT_DIR"/system/memory-seed/*.md.template; do
    [ -f "$t" ] || continue
    render_template "$t" "$LOCAL_DIR/memory-seed/$(basename "$t" .template)"
  done
  log_ok "  ↻ .cockpit-local/memory-seed/"
}

sync_settings_json() {
  log_step "U3 · settings.json 동기화"

  local dst="$CLAUDE_DIR/settings.json"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$LOCAL_DIR/settings.json" ]; then
    log_ok "  = 심링크 정상 — 렌더본이 곧 반영됨"
  elif [ -f "$dst" ] && [ ! -L "$dst" ]; then
    backup_path "$dst" "$BACKUP_DIR"
    local merged
    merged="$(mktemp)"
    if jq -s '.[0] * .[1]' "$dst" "$LOCAL_DIR/settings.json" > "$merged" 2>/dev/null \
       && jq empty "$merged" 2>/dev/null; then
      mv "$merged" "$dst"
      log_ok "  ↻ 실파일 드리프트 감지 → cockpit baseline 딥머지 (백업: $BACKUP_DIR)"
      log_dim "    · 심링크로 되돌리려면 ./install.sh --force (런타임 키는 렌더본에 없으면 유실)"
    else
      rm -f "$merged"
      die "settings.json 머지 실패 — $dst 를 수동 확인하세요 (백업: $BACKUP_DIR)"
    fi
  else
    log_warn "  $dst 상태 비정상 (링크 대상 상이 또는 부재) — ./install.sh 재실행 권장"
  fi
}

update_skill_and_agent_links() {
  log_step "U4 · 링크 보강"

  mkdir -p "$CLAUDE_DIR/commands"
  for cat_dir in "$ROOT_DIR"/skills/*/; do
    [ -d "$cat_dir" ] || continue
    local cat_name dst linked file_name base_name
    cat_name="$(basename "$cat_dir")"
    compgen -G "${cat_dir}*.md" > /dev/null || continue
    dst="$CLAUDE_DIR/commands/$cat_name"
    
    if [ -e "$dst" ] && [ ! -d "$dst" ]; then
      log_warn "  ~ commands/$cat_name 파일 존재 — ./install.sh --force 로 정리 필요"
      continue
    fi
    
    mkdir -p "$dst"
    linked=0
    for src_file in "$cat_dir"*.md; do
      [ -f "$src_file" ] || continue
      [[ "$src_file" == *.ko.md ]] && continue

      file_name="$(basename "$src_file")"
      base_name="${file_name%.md}"

      if [ ! -e "$dst/$file_name" ]; then
        if [ "${COCKPIT_LANG:-en}" = "ko" ] && [ -f "${cat_dir}${base_name}.ko.md" ]; then
          ln -s "${cat_dir}${base_name}.ko.md" "$dst/$file_name"
          linked=$((linked+1))
        else
          ln -s "$src_file" "$dst/$file_name"
          linked=$((linked+1))
        fi
      fi
    done
    
    if [ "$linked" -gt 0 ]; then
      log_ok "  + commands/$cat_name (신규 파일 ${linked}개)"
    else
      log_dim "  = commands/$cat_name"
    fi
  done

  if [ ! -e "$CLAUDE_DIR/agents" ] && compgen -G "$ROOT_DIR/system/subagents/*.md" > /dev/null; then
    ln -s "$ROOT_DIR/system/subagents" "$CLAUDE_DIR/agents"
    log_ok "  + agents 링크 복구"
  else
    log_dim "  = agents"
  fi
}

verify_security_hooks() {
  log_step "U5 · 훅 검증"

  for h in "$ROOT_DIR"/system/hooks/*.sh; do
    [ -f "$h" ] || continue
    chmod +x "$h"
    bash -n "$h" 2>/dev/null || die "훅 구문 오류: $h"
  done
  log_ok "  전체 통과 (chmod +x · bash -n)"
}

update_memory_seeds() {
  log_step "U6 · 메모리 시드"

  local MEMORY_DIR="$CLAUDE_DIR/memory"
  mkdir -p "$MEMORY_DIR"

  local seed_sources=()
  for src in "$LOCAL_DIR"/memory-seed/*.md; do
    [ -f "$src" ] && seed_sources+=("$src")
  done
  for src in "$ROOT_DIR"/system/memory-seed/*.md; do
    [ -f "$src" ] || continue
    case "$src" in *.template) continue ;; esac
    seed_sources+=("$src")
  done

  local seeded=0
  for src in ${seed_sources[@]+"${seed_sources[@]}"}; do
    local name dst
    name="$(basename "$src")"
    dst="$MEMORY_DIR/$name"
    if [ ! -e "$dst" ]; then
      cp "$src" "$dst"
      seeded=$((seeded+1))
      log_ok "  + $name (신규 시드)"
    elif [ "$OPT_RESEED" = "1" ] && ! cmp -s "$src" "$dst"; then
      backup_path "$dst" "$BACKUP_DIR"
      cp "$src" "$dst"
      log_ok "  ↻ $name (--reseed, 백업: $BACKUP_DIR)"
    fi
  done

  local INDEX="$MEMORY_DIR/MEMORY.md"
  if [ -f "$INDEX" ]; then
    for src in ${seed_sources[@]+"${seed_sources[@]}"}; do
      local name desc
      name="$(basename "$src")"
      if ! grep -q "($name)" "$INDEX" 2>/dev/null; then
        desc="$(awk -F': ' '/^description:/ {sub(/^description: */, ""); print; exit}' "$src")"
        echo "- [${name%.md}]($name) — $desc" >> "$INDEX"
        log_ok "  + MEMORY.md 인덱스: $name"
      fi
    done
  fi
  [ "$seeded" = "0" ] && log_dim "  · 신규 시드 없음"
}

summary() {
  printf '\n'
  log_ok "업데이트 완료 — Claude Code 재시작 시 반영됩니다"
  log_dim "  · 전체 검증: ./scripts/post-install-check.sh"
  log_dim "  · MCP·플러그인 변경이 필요하면: ./install.sh"
}

main() {
  parse_args "$@"
  setup_globals
  
  pull_latest_changes
  render_all_templates
  sync_settings_json
  update_skill_and_agent_links
  verify_security_hooks
  update_memory_seeds
  summary
}

main "$@"
