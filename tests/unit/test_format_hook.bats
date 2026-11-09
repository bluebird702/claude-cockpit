#!/usr/bin/env bats

# system/hooks/format.sh 의 셸 포맷 기준 선택 검증
# — 프로젝트 .editorconfig 가 있으면 그 규칙, 없으면 개인 기본값(2칸)

setup() {
	command -v shfmt >/dev/null 2>&1 || skip "shfmt 미설치"
	command -v jq >/dev/null 2>&1 || skip "jq 미설치"

	HOOK="${BATS_TEST_DIRNAME}/../../system/hooks/format.sh"
	export TEST_TEMP_DIR="$(mktemp -d)"
	mkdir -p "$TEST_TEMP_DIR/project/scripts"
	SCRIPT="$TEST_TEMP_DIR/project/scripts/sample.sh"
	printf 'if true; then\necho hi\nfi\n' >"$SCRIPT"
}

teardown() {
	rm -rf "$TEST_TEMP_DIR"
}

run_hook() {
	printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$SCRIPT" | bash "$HOOK"
}

@test "format.sh: follows ancestor .editorconfig (tabs) when present" {
	printf 'root = true\n[*.sh]\nindent_style = tab\n' >"$TEST_TEMP_DIR/project/.editorconfig"

	run run_hook
	[ "$status" -eq 0 ]
	[ "$(sed -n 2p "$SCRIPT")" = "$(printf '\techo hi')" ]
}

@test "format.sh: falls back to 2-space indent without .editorconfig" {
	run run_hook
	[ "$status" -eq 0 ]
	[ "$(sed -n 2p "$SCRIPT")" = "  echo hi" ]
}
