#!/usr/bin/env bash
# jq_merge.sh - settings.json 안전 머지 헬퍼
# common.sh가 먼저 source 되어 있다고 가정합니다.

set -euo pipefail

# json_ensure_file <path>
# 파일이 없거나 빈 JSON이면 "{}" 로 초기화.
json_ensure_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ] || [ ! -s "$path" ]; then
    echo '{}' > "$path"
  fi
  jq empty "$path" 2>/dev/null || die "유효하지 않은 JSON: $path"
}

# json_merge_mcp_server <settings_path> <name> <server_json>
# settings.mcpServers[name] = server_json 로 머지 (다른 서버 보존).
json_merge_mcp_server() {
  local settings="$1" name="$2" server_json="$3"
  json_ensure_file "$settings"
  local tmp
  tmp="$(mktemp)"
  jq --arg name "$name" --argjson server "$server_json" \
     '.mcpServers = (.mcpServers // {}) | .mcpServers[$name] = $server' \
     "$settings" > "$tmp" || { rm -f "$tmp"; die "jq 머지 실패: $settings"; }
  jq empty "$tmp" 2>/dev/null || { rm -f "$tmp"; die "머지 결과 JSON이 유효하지 않습니다."; }
  cat "$tmp" > "$settings"
  rm -f "$tmp"
}

# json_delete_mcp_server <settings_path> <name>
json_delete_mcp_server() {
  local settings="$1" name="$2"
  [ -f "$settings" ] || return 0
  local tmp
  tmp="$(mktemp)"
  jq --arg name "$name" 'if .mcpServers then .mcpServers |= del(.[$name]) else . end' \
     "$settings" > "$tmp" || { rm -f "$tmp"; die "jq 삭제 실패: $settings"; }
  jq empty "$tmp" 2>/dev/null || { rm -f "$tmp"; die "삭제 결과 JSON이 유효하지 않습니다."; }
  cat "$tmp" > "$settings"
  rm -f "$tmp"
}

# json_list_mcp_servers <settings_path>
# mcpServers 키 목록을 개행 출력.
json_list_mcp_servers() {
  local settings="$1"
  [ -f "$settings" ] || return 0
  jq -r '.mcpServers // {} | keys[]' "$settings" 2>/dev/null || true
}
