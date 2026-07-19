#!/usr/bin/env bash
# post-install-check.sh - install.sh 의 마지막 Phase (설치 후 헬스체크)
#
# 설치 직후 "장비 재현"이 성공했는지 항목별 체크리스트를 출력합니다.
# exit 0: 모두 OK / exit 1: CRITICAL 실패
#
# 사용법:
#   scripts/post-install-check.sh [--help]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi
source "$SCRIPT_DIR/lib/common.sh"

ROOT="$(cockpit_root)"
CLAUDE_DIR="$(claude_home)"

log_step "Phase 9 · 설치 후 헬스체크"

FAIL=0
warn=0

verify_link() {
  local dst="$1" expected_src="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$expected_src" ]; then
    log_ok "link $dst"
  else
    log_err "link 누락/오염: $dst (기대 → $expected_src)"
    FAIL=$((FAIL+1))
  fi
}

verify_file() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    log_ok "$label"
  else
    log_err "$label 없음: $path"
    FAIL=$((FAIL+1))
  fi
}

verify_executable() {
  local path="$1"
  if [ -x "$path" ]; then
    log_ok "run $path"
  else
    log_err "실행 권한 없음: $path"
    FAIL=$((FAIL+1))
  fi
}

log_info "── 전역 링크 검증"
verify_link "$CLAUDE_DIR/CLAUDE.md"        "$ROOT/system/CLAUDE.md"
# settings.json 은 Claude Code 가 atomic write 로 심링크를 실파일로 대체할 수 있음(정상 드리프트).
# 심링크면 OK, 실파일이면 경고 + update.sh 안내 (실패 아님).
if [ -L "$CLAUDE_DIR/settings.json" ] && [ "$(readlink "$CLAUDE_DIR/settings.json")" = "$ROOT/.cockpit-local/settings.json" ]; then
  log_ok "link $CLAUDE_DIR/settings.json"
elif [ -f "$CLAUDE_DIR/settings.json" ] && [ ! -L "$CLAUDE_DIR/settings.json" ]; then
  log_warn "settings.json 이 실파일로 드리프트됨 — ./scripts/update.sh 가 baseline 을 머지해 동기화합니다"
  warn=$((warn+1))
else
  log_err "link 누락/오염: $CLAUDE_DIR/settings.json (기대 → $ROOT/.cockpit-local/settings.json)"
  FAIL=$((FAIL+1))
fi
verify_link "$CLAUDE_DIR/keybindings.json" "$ROOT/system/keybindings.json"

log_info "── JSON 유효성"
if jq empty "$ROOT/.cockpit-local/settings.json" 2>/dev/null; then
  log_ok "settings.json jq valid"
else
  log_err "settings.json JSON 파싱 실패"
  FAIL=$((FAIL+1))
fi
if jq empty "$ROOT/system/mcp-shared/servers.json" 2>/dev/null; then
  log_ok "mcp-shared/servers.json jq valid"
else
  log_err "system/mcp-shared/servers.json JSON 파싱 실패"
  FAIL=$((FAIL+1))
fi

log_info "── 스킬 카테고리 링크"
for cat_dir in "$ROOT"/skills/*/; do
  [ -d "$cat_dir" ] || continue
  cat_name="$(basename "$cat_dir")"
  dst="$CLAUDE_DIR/commands/$cat_name"
  if [ -L "$dst" ]; then
    count=$(find "$cat_dir" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
    log_ok "commands/$cat_name (${count}개 스킬, 디렉토리 링크)"
  elif [ -d "$dst" ]; then
    linked=$(find "$dst" -maxdepth 1 -name '*.md' -type l 2>/dev/null | wc -l | tr -d ' ')
    if [ "$linked" -gt 0 ]; then
      log_ok "commands/$cat_name (${linked}개 스킬, 개별 파일 링크)"
    else
      log_warn "commands/$cat_name 링크 없음 (비어있는 카테고리일 수 있음)"
      warn=$((warn+1))
    fi
  else
    log_warn "commands/$cat_name 링크 없음"
    warn=$((warn+1))
  fi
done

log_info "── 서브에이전트 링크"
if [ -d "$ROOT/system/subagents" ]; then
  total=$(find "$ROOT/system/subagents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  if [ -L "$CLAUDE_DIR/agents" ]; then
    log_ok "agents (${total}개 에이전트, 디렉토리 링크)"
  elif [ -d "$CLAUDE_DIR/agents" ]; then
    # fallback: 개별 파일 심링크 모드 — cockpit 에이전트가 전부 링크되어 있는지 확인
    linked=0
    for src in "$ROOT"/system/subagents/*.md; do
      [ -f "$src" ] || continue
      dst="$CLAUDE_DIR/agents/$(basename "$src")"
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        linked=$((linked+1))
      fi
    done
    if [ "$linked" = "$total" ]; then
      log_ok "agents (${total}개 에이전트, 개별 파일 링크)"
    else
      log_warn "$HOME/.claude/agents: ${linked}/${total} 만 링크됨"
      warn=$((warn+1))
    fi
  else
    log_warn "$HOME/.claude/agents 링크 없음"
    warn=$((warn+1))
  fi
fi

log_info "── 훅 스크립트 실행 권한"
for h in "$ROOT"/system/hooks/*.sh; do
  [ -f "$h" ] || continue
  verify_executable "$h"
done

log_info "── 훅 구문 검사 (bash -n)"
for h in "$ROOT"/system/hooks/*.sh; do
  if bash -n "$h" 2>/dev/null; then
    log_ok "  $(basename "$h") syntax OK"
  else
    log_err "  $(basename "$h") syntax 에러"
    FAIL=$((FAIL+1))
  fi
done

log_info "── settings.json 훅 엔트리 일치"
if jq -e '.hooks.PreToolUse' "$ROOT/.cockpit-local/settings.json" >/dev/null 2>&1; then
  log_ok "PreToolUse hooks 등록됨"
else
  log_err "settings.json 에 PreToolUse hooks 없음"
  FAIL=$((FAIL+1))
fi

log_info "── 권한 모델"
deny_count=$(jq '.permissions.deny | length' "$ROOT/.cockpit-local/settings.json" 2>/dev/null || echo 0)
allow_count=$(jq '.permissions.allow | length' "$ROOT/.cockpit-local/settings.json" 2>/dev/null || echo 0)
ask_count=$(jq '.permissions.ask | length' "$ROOT/.cockpit-local/settings.json" 2>/dev/null || echo 0)
log_ok "allow $allow_count / ask $ask_count / deny $deny_count 엔트리"
if jq -e '.permissions.allow[] | select(. == "Bash(*)")' "$ROOT/.cockpit-local/settings.json" >/dev/null 2>&1; then
  log_err "위험: Bash(*) 전체 허용이 남아있음"
  FAIL=$((FAIL+1))
fi

log_info "── MCP 설정 (있으면)"
mcp_count="$(jq '.mcpServers // {} | length' "$CLAUDE_DIR/settings.json" 2>/dev/null || echo 0)"
if [ "$mcp_count" -gt 0 ]; then
  log_ok "MCP 서버 ${mcp_count}개 등록"
else
  log_dim "  · MCP 미설치 (./install.sh 는 기본 포함, 건너뛰었다면 ./system/mcp-shared/setup.sh)"
fi

log_info "── Secrets 백엔드"
source "$ROOT/scripts/lib/secrets.sh"
log_ok "백엔드: $(secrets_backend_label)"

printf '\n'
if [ $FAIL -eq 0 ]; then
  log_ok "헬스체크 통과 (경고 ${warn}개)"
  printf '\n  %s✓%s cockpit 준비 완료 — Claude Code 를 재시작하세요.\n\n' "$C_GREEN$C_BOLD" "$C_RESET"
  exit 0
else
  log_err "헬스체크 실패: $FAIL 개 문제 (경고 ${warn}개)"
  exit 1
fi
