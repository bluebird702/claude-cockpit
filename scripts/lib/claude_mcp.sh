#!/usr/bin/env bash
# claude_mcp.sh - Claude Code user 범위 MCP 서버 등록·해제 헬퍼
# common.sh 가 먼저 source 되어 있다고 가정합니다.
#
# Claude Code 는 user 범위 MCP 서버를 ~/.claude.json 에서만 읽습니다.
# (~/.claude/settings.json 의 mcpServers 는 읽지 않음 — 구버전 cockpit 이 쓰던 위치)
# 쓰기는 공식 CLI(claude mcp add-json / remove --scope user)로만 하고,
# ~/.claude.json 은 존재 확인 용도로만 읽습니다.
#
# 소유권: cockpit 이 등록한 서버 이름만 매니페스트에 기록합니다.
# 매니페스트에 없는 동명 서버(사용자가 직접 추가한 것)는 덮어쓰거나 지우지 않습니다.

set -euo pipefail

COCKPIT_MCP_MANIFEST="${COCKPIT_MCP_MANIFEST:-$HOME/.config/claude-cockpit/mcp-servers.list}"

# Claude Code 의 user 설정 파일 경로 (CLAUDE_CONFIG_DIR 지정 시 그 아래)
claude_user_config() {
	printf '%s/.claude.json' "${CLAUDE_CONFIG_DIR:-$HOME}"
}

# mcp_user_has <name> — user 범위에 같은 이름의 서버가 있는지
mcp_user_has() {
	local cfg
	cfg="$(claude_user_config)"
	[ -f "$cfg" ] && jq -e --arg n "$1" '.mcpServers[$n]' "$cfg" >/dev/null 2>&1
}

mcp_manifest_has() {
	[ -f "$COCKPIT_MCP_MANIFEST" ] && grep -Fxq -- "$1" "$COCKPIT_MCP_MANIFEST"
}

mcp_manifest_add() {
	mcp_manifest_has "$1" && return 0
	mkdir -p "$(dirname "$COCKPIT_MCP_MANIFEST")"
	printf '%s\n' "$1" >>"$COCKPIT_MCP_MANIFEST"
	chmod 600 "$COCKPIT_MCP_MANIFEST"
}

mcp_manifest_remove() {
	[ -f "$COCKPIT_MCP_MANIFEST" ] || return 0
	local tmp
	tmp="$(mktemp)"
	grep -Fxv -- "$1" "$COCKPIT_MCP_MANIFEST" >"$tmp" || true
	mv "$tmp" "$COCKPIT_MCP_MANIFEST"
	chmod 600 "$COCKPIT_MCP_MANIFEST"
}

# mcp_user_register <name> <server_json> [force]
# 반환: 0 등록됨 · 1 실패 · 2 건너뜀(cockpit 이 등록하지 않은 동명 서버가 이미 있음)
# cockpit 소유 서버는 remove 후 add 로 갱신 (add-json 은 동명 서버가 있으면 실패하므로)
mcp_user_register() {
	local name="$1" json="$2" force="${3:-0}" out
	if mcp_user_has "$name"; then
		if ! mcp_manifest_has "$name" && [ "$force" != "1" ]; then
			return 2
		fi
		out="$(claude mcp remove --scope user "$name" 2>&1)" || {
			log_err "$out"
			return 1
		}
	fi
	out="$(claude mcp add-json --scope user "$name" "$json" 2>&1)" || {
		log_err "$out"
		return 1
	}
	mcp_manifest_add "$name"
}

# mcp_user_unregister <name>
# 반환: 0 제거됨(이미 없으면 매니페스트만 정리) · 1 실패 · 2 건너뜀(cockpit 소유 아님)
mcp_user_unregister() {
	local name="$1" out
	mcp_manifest_has "$name" || return 2
	if mcp_user_has "$name"; then
		out="$(claude mcp remove --scope user "$name" 2>&1)" || {
			log_err "$out"
			return 1
		}
	fi
	mcp_manifest_remove "$name"
}

# mcp_legacy_has <settings_path> <name> — 구버전이 settings.json 에 남긴(로드되지 않는) 항목
mcp_legacy_has() {
	[ -f "$1" ] && jq -e --arg n "$2" '.mcpServers[$n]' "$1" >/dev/null 2>&1
}
