#!/usr/bin/env bash
# jq_merge.sh - settings.json 안전 편집 헬퍼
# common.sh가 먼저 source 되어 있다고 가정합니다.
#
# MCP 서버 "등록"은 여기서 하지 않습니다 — Claude Code 는 settings.json 의
# mcpServers 를 읽지 않으므로 scripts/lib/claude_mcp.sh (claude mcp add-json) 를 씁니다.
# 이 파일의 삭제 헬퍼는 구버전이 settings.json 에 남긴 항목을 정리하는 용도입니다.

set -euo pipefail

# json_ensure_file <path>
# 파일이 없거나 빈 JSON이면 "{}" 로 초기화.
json_ensure_file() {
	local path="$1"
	mkdir -p "$(dirname "$path")"
	if [ ! -f "$path" ] || [ ! -s "$path" ]; then
		echo '{}' >"$path"
	fi
	jq empty "$path" 2>/dev/null || die "유효하지 않은 JSON: $path"
}

# json_delete_mcp_server <settings_path> <name>
# settings.mcpServers[name] 삭제. 비게 된 mcpServers 객체도 함께 제거.
# 심볼릭 링크를 보존하도록 원본 경로에 덮어씁니다 (mv 대신 cat >).
json_delete_mcp_server() {
	local settings="$1" name="$2"
	[ -f "$settings" ] || return 0
	local tmp
	tmp="$(mktemp)"
	jq --arg name "$name" \
		'if .mcpServers then .mcpServers |= del(.[$name]) | (if .mcpServers == {} then del(.mcpServers) else . end) else . end' \
		"$settings" >"$tmp" || {
		rm -f "$tmp"
		die "jq 삭제 실패: $settings"
	}
	jq empty "$tmp" 2>/dev/null || {
		rm -f "$tmp"
		die "삭제 결과 JSON이 유효하지 않습니다."
	}
	cat "$tmp" >"$settings"
	rm -f "$tmp"
}
