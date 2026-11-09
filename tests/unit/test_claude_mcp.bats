#!/usr/bin/env bats

# scripts/lib/claude_mcp.sh — user 범위 MCP 등록·해제와 소유권 규칙 검증
# claude CLI 는 tests/mocks/claude 목업(실제 CLI 와 같은 실패 규칙)으로 대체한다.

setup() {
	command -v jq >/dev/null 2>&1 || skip "jq 미설치"

	export TEST_TEMP_DIR="$(mktemp -d)"
	export HOME="$TEST_TEMP_DIR/home"
	mkdir -p "$HOME"
	unset CLAUDE_CONFIG_DIR
	export COCKPIT_MCP_MANIFEST="$HOME/.config/claude-cockpit/mcp-servers.list"

	mkdir -p "$TEST_TEMP_DIR/bin"
	cp "${BATS_TEST_DIRNAME}/../mocks/claude" "$TEST_TEMP_DIR/bin/claude"
	chmod +x "$TEST_TEMP_DIR/bin/claude"
	export PATH="$TEST_TEMP_DIR/bin:$PATH"

	source "${BATS_TEST_DIRNAME}/../../scripts/lib/common.sh"
	source "${BATS_TEST_DIRNAME}/../../scripts/lib/jq_merge.sh"
	source "${BATS_TEST_DIRNAME}/../../scripts/lib/claude_mcp.sh"

	CFG="$HOME/.claude.json"
	SERVER='{"type":"stdio","command":"docker","env":{"TOKEN":"${GITHUB_TOKEN}"}}'
}

teardown() {
	rm -rf "$TEST_TEMP_DIR"
}

@test "claude_mcp: register adds server to ~/.claude.json and records ownership" {
	run mcp_user_register github "$SERVER"
	[ "$status" -eq 0 ]
	[ "$(jq -r '.mcpServers.github.command' "$CFG")" = "docker" ]
	# 비밀값은 참조 그대로 저장되어야 한다 (치환된 값이 남으면 안 됨)
	[ "$(jq -r '.mcpServers.github.env.TOKEN' "$CFG")" = '${GITHUB_TOKEN}' ]
	grep -Fxq github "$COCKPIT_MCP_MANIFEST"
}

@test "claude_mcp: re-register replaces a cockpit-owned server" {
	mcp_user_register github "$SERVER"
	run mcp_user_register github '{"type":"stdio","command":"updated"}'
	[ "$status" -eq 0 ]
	[ "$(jq -r '.mcpServers.github.command' "$CFG")" = "updated" ]
	[ "$(grep -cFx github "$COCKPIT_MCP_MANIFEST")" -eq 1 ]
}

@test "claude_mcp: register skips (rc 2) a same-name server not owned by cockpit" {
	claude mcp add-json --scope user github '{"type":"http","url":"https://user.example/mcp"}'

	run mcp_user_register github "$SERVER"
	[ "$status" -eq 2 ]
	[ "$(jq -r '.mcpServers.github.url' "$CFG")" = "https://user.example/mcp" ]
	! mcp_manifest_has github
}

@test "claude_mcp: register with force replaces a foreign server and takes ownership" {
	claude mcp add-json --scope user github '{"type":"http","url":"https://user.example/mcp"}'

	run mcp_user_register github "$SERVER" 1
	[ "$status" -eq 0 ]
	[ "$(jq -r '.mcpServers.github.command' "$CFG")" = "docker" ]
	mcp_manifest_has github
}

@test "claude_mcp: unregister removes only cockpit-owned servers" {
	mcp_user_register github "$SERVER"
	claude mcp add-json --scope user jira '{"type":"stdio","command":"mine"}'

	run mcp_user_unregister github
	[ "$status" -eq 0 ]
	[ "$(jq -r '.mcpServers.github // "gone"' "$CFG")" = "gone" ]
	! mcp_manifest_has github

	run mcp_user_unregister jira
	[ "$status" -eq 2 ]
	[ "$(jq -r '.mcpServers.jira.command' "$CFG")" = "mine" ]
}

@test "claude_mcp: unregister clears ownership when server was already removed" {
	mcp_user_register github "$SERVER"
	claude mcp remove --scope user github

	run mcp_user_unregister github
	[ "$status" -eq 0 ]
	! mcp_manifest_has github
}

@test "claude_mcp: legacy settings.json entry is detected and deleted with empty object" {
	SETTINGS="$HOME/settings.json"
	echo '{"theme":"dark","mcpServers":{"github":{"command":"old"}}}' >"$SETTINGS"

	mcp_legacy_has "$SETTINGS" github
	json_delete_mcp_server "$SETTINGS" github
	! mcp_legacy_has "$SETTINGS" github
	[ "$(jq -r 'has("mcpServers")' "$SETTINGS")" = "false" ]
	[ "$(jq -r '.theme' "$SETTINGS")" = "dark" ]
}
