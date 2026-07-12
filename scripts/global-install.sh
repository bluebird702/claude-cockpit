#!/usr/bin/env bash
# scripts/global-install.sh
#
# 장비 교체 후 이 스크립트 한 번으로 cockpit 기반 Claude 환경을 완전 재현합니다.
#
# Phase 순서:
#   1. doctor                — 필수·권장 도구 진단 (필수 누락 시 중단)
#   1.5 render templates     — core/**/*.template → .cockpit-local/ (HOME·COCKPIT_HOME·USER_NAME 치환)
#   2. global link           — CLAUDE.md, settings.json, keybindings.json  (core/)
#   3. skills link           — humans/skills/<cat> → ~/.claude/commands/<cat>
#   4. agents link           — humans/subagents/ → ~/.claude/agents
#   5. hooks verify          — core/hooks/*.sh 실행 권한·구문 검사
#   6. memory seed           — core/memory-seed/*.md(+.template 렌더본) → ~/.claude/memory/ (없을 때만)
#   7. MCP (옵션)            — mcp/setup.sh
#   7.5 plugins              — GitHub 플러그인 다운로드·설치 (claude-hud 등)
#   8. post-install check    — 전체 검증
#
# 사용법:
#   scripts/global-install.sh [--with-mcp] [--force] [--skip-doctor] [--no-plugins]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/tui.sh"

OPT_MCP=0
OPT_FORCE=0
OPT_SKIP_DOCTOR=0
OPT_NO_PLUGINS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --with-mcp)    OPT_MCP=1; shift ;;
    --force)       OPT_FORCE=1; shift ;;
    --skip-doctor) OPT_SKIP_DOCTOR=1; shift ;;
    --no-plugins)  OPT_NO_PLUGINS=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]
  --with-mcp      Phase 7 에서 mcp/setup.sh 실행
  --force         기존 실제 파일도 백업 후 덮어씀
  --skip-doctor   Phase 1 (환경 진단) 건너뜀
  --no-plugins    Phase 7.5 (플러그인 설치) 건너뜀
EOF
      exit 0 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

tui_banner "Claude Cockpit · Global Install" "장비 재현 · 보안 기본값 · 생산성 확장"

# ─────────────────────────────────────────────
# Phase 1: Doctor
# ─────────────────────────────────────────────
if [ "$OPT_SKIP_DOCTOR" = "0" ]; then
  "$ROOT_DIR/scripts/check-deps.sh" || die "환경 진단 실패 — 필수 도구 설치 후 다시 실행"
else
  log_warn "Phase 1 (doctor) 건너뜀"
fi

require_cmd jq
CLAUDE_DIR="$(claude_home)"
mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/memory"

BACKUP_DIR="$(make_backup_dir global)"
log_ok "백업 디렉토리: $BACKUP_DIR"

# ─────────────────────────────────────────────
# Phase 1.5: 템플릿 렌더 (.cockpit-local/)
# ─────────────────────────────────────────────
log_step "Phase 1.5 · 템플릿 렌더"

LOCAL_DIR="$ROOT_DIR/.cockpit-local"
mkdir -p "$LOCAL_DIR/memory-seed"

detect_template_vars "$ROOT_DIR"
log_dim "  · COCKPIT_HOME=$COCKPIT_HOME"
log_dim "  · USER_NAME=$USER_NAME"
log_dim "  · GITHUB_ORG=$GITHUB_ORG"

render_template "$ROOT_DIR/core/settings.json.template" "$LOCAL_DIR/settings.json"
log_ok "  + .cockpit-local/settings.json"

for t in "$ROOT_DIR"/core/memory-seed/*.md.template; do
  [ -f "$t" ] || continue
  base="$(basename "$t" .template)"
  render_template "$t" "$LOCAL_DIR/memory-seed/$base"
  log_ok "  + .cockpit-local/memory-seed/$base"
done

# ─────────────────────────────────────────────
# Phase 2: global 파일 링크
# ─────────────────────────────────────────────
log_step "Phase 2 · global 파일 링크"

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

link_file "$ROOT_DIR/core/CLAUDE.md"        "$CLAUDE_DIR/CLAUDE.md"
link_file "$LOCAL_DIR/settings.json"        "$CLAUDE_DIR/settings.json"
link_file "$ROOT_DIR/core/keybindings.json" "$CLAUDE_DIR/keybindings.json"

# git 커밋 메시지 템플릿 (~/.gitmessage → core/git/gitmessage)
link_file "$ROOT_DIR/core/git/gitmessage" "$HOME/.gitmessage"
if command -v git > /dev/null 2>&1; then
  git config --global commit.template "$HOME/.gitmessage"
  log_ok "  + git config --global commit.template ~/.gitmessage"
fi

# ─────────────────────────────────────────────
# Phase 3: skills 카테고리 링크
# ─────────────────────────────────────────────
log_step "Phase 3 · skills 카테고리 링크"

for cat_dir in "$ROOT_DIR"/humans/skills/*/; do
  [ -d "$cat_dir" ] || continue
  cat_name="$(basename "$cat_dir")"
  # 비어있는 카테고리는 건너뜀
  if ! compgen -G "${cat_dir}*.md" > /dev/null; then
    log_dim "  · humans/skills/$cat_name 비어있음 (건너뜀)"
    continue
  fi
  dst="$CLAUDE_DIR/commands/$cat_name"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "${cat_dir%/}" ] || [ "$(readlink "$dst")" = "$cat_dir" ]; then
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

# ─────────────────────────────────────────────
# Phase 4: agents 링크
# ─────────────────────────────────────────────
log_step "Phase 4 · agents 링크"

if [ -d "$ROOT_DIR/humans/subagents" ] && compgen -G "$ROOT_DIR/humans/subagents/*.md" > /dev/null; then
  dst="$CLAUDE_DIR/agents"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$ROOT_DIR/humans/subagents" ]; then
      log_dim "  = $dst (이미 연결됨)"
    else
      backup_path "$dst" "$BACKUP_DIR"
      rm "$dst"
      ln -s "$ROOT_DIR/humans/subagents" "$dst"
      log_ok "  ↻ $dst → $ROOT_DIR/humans/subagents"
    fi
  elif [ -d "$dst" ] && [ ! -L "$dst" ]; then
    # 실제 디렉토리가 이미 있으면 개별 파일만 링크 (기존 설정 보존)
    log_warn "  ~ $dst 는 실제 디렉토리 — 개별 에이전트 파일만 링크"
    for f in "$ROOT_DIR"/humans/subagents/*.md; do
      [ -f "$f" ] || continue
      link_file "$f" "$dst/$(basename "$f")"
    done
  else
    ln -s "$ROOT_DIR/humans/subagents" "$dst"
    log_ok "  + $dst → $ROOT_DIR/humans/subagents"
  fi
  count=$(find "$ROOT_DIR/humans/subagents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  log_dim "  · ${count}개 에이전트 로드됨"
else
  log_dim "  · humans/subagents/ 비어있음 (건너뜀)"
fi

# ─────────────────────────────────────────────
# Phase 5: hooks 검증
# ─────────────────────────────────────────────
log_step "Phase 5 · 보안 훅 검증"

if [ -d "$ROOT_DIR/core/hooks" ]; then
  for h in "$ROOT_DIR"/core/hooks/*.sh; do
    [ -f "$h" ] || continue
    chmod +x "$h"
    if bash -n "$h" 2>/dev/null; then
      log_ok "  $(basename "$h")"
    else
      die "훅 구문 오류: $h"
    fi
  done
else
  log_warn "  core/hooks 디렉토리 없음"
fi

# ─────────────────────────────────────────────
# Phase 6: 메모리 시드
# ─────────────────────────────────────────────
log_step "Phase 6 · 메모리 시드"

MEMORY_DIR="$CLAUDE_DIR/memory"
mkdir -p "$MEMORY_DIR"

if [ -d "$ROOT_DIR/core/memory-seed" ]; then
  seeded=0
  skipped=0

  # 수집: 렌더본(.cockpit-local/memory-seed/*.md) + 정적 원본(core/memory-seed/*.md, .template 제외)
  seed_sources=()
  for src in "$LOCAL_DIR"/memory-seed/*.md; do
    [ -f "$src" ] && seed_sources+=("$src")
  done
  for src in "$ROOT_DIR"/core/memory-seed/*.md; do
    [ -f "$src" ] || continue
    case "$src" in
      *.template) continue ;;
    esac
    seed_sources+=("$src")
  done

  for src in ${seed_sources[@]+"${seed_sources[@]}"}; do
    name="$(basename "$src")"
    dst="$MEMORY_DIR/$name"
    if [ -e "$dst" ]; then
      skipped=$((skipped+1))
      log_dim "  = $name (이미 존재, 보존)"
    else
      cp "$src" "$dst"
      seeded=$((seeded+1))
      log_ok "  + $name"
    fi
  done

  INDEX="$MEMORY_DIR/MEMORY.md"
  if [ ! -f "$INDEX" ]; then
    {
      echo "# Memory Index"
      echo ""
      for src in ${seed_sources[@]+"${seed_sources[@]}"}; do
        name="$(basename "$src")"
        desc="$(awk -F': ' '/^description:/ {sub(/^description: */, ""); print; exit}' "$src")"
        echo "- [${name%.md}]($name) — $desc"
      done
    } > "$INDEX"
    log_ok "  + MEMORY.md 인덱스 생성"
  else
    log_dim "  = MEMORY.md (이미 존재, 보존)"
  fi

  log_dim "  · 신규 ${seeded}개 / 보존 ${skipped}개"
else
  log_dim "  · core/memory-seed/ 없음 (건너뜀)"
fi

# ─────────────────────────────────────────────
# Phase 7: MCP (옵션)
# ─────────────────────────────────────────────
if [ "$OPT_MCP" = "1" ]; then
  log_step "Phase 7 · MCP 설정"
  "$ROOT_DIR/core/mcp-shared/setup.sh"
else
  log_dim "  · Phase 7 (MCP) 건너뜀 — 필요 시 --with-mcp 또는 ./core/mcp-shared/setup.sh"
fi

# ─────────────────────────────────────────────
# Phase 7.5: 플러그인 설치
# ─────────────────────────────────────────────
if [ "$OPT_NO_PLUGINS" = "0" ]; then
  PLUGIN_ARGS=()
  [ "$OPT_FORCE" = "1" ] && PLUGIN_ARGS+=(--force)
  "$ROOT_DIR/scripts/claude-plugins.sh" "${PLUGIN_ARGS[@]+"${PLUGIN_ARGS[@]}"}" \
    || log_warn "플러그인 설치 실패 — 네트워크 없이도 Claude Code 는 동작합니다"
else
  log_dim "  · Phase 7.5 (plugins) 건너뜀 — --no-plugins"
fi

# ─────────────────────────────────────────────
# Phase 8: 헬스체크
# ─────────────────────────────────────────────
"$ROOT_DIR/scripts/post-install-check.sh" || die "헬스체크 실패"

printf '\n'
log_ok "전역 설치 완료"
log_dim "  백업:  $BACKUP_DIR"
log_dim "  확인:  ls -la $CLAUDE_DIR"
printf '\n  %sClaude Code 재시작 후 %s/review:all%s, %s/mgmt:standup%s, %s/dev:hotspot%s 등을 사용해 보세요.%s\n\n' \
  "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RESET"
