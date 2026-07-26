#!/usr/bin/env bats

setup() {
	# 격리된 임시 환경 세팅
	export COCKPIT_HOME="${BATS_TMPDIR}/cockpit_test"
	export CLAUDE_HOME="${BATS_TMPDIR}/claude_home_test"
	mkdir -p "$COCKPIT_HOME"
	mkdir -p "$CLAUDE_HOME"
}

teardown() {
	# 테스트 종료 후 정리
	rm -rf "$COCKPIT_HOME"
	rm -rf "$CLAUDE_HOME"
}

@test "bootstrap.sh: prints already clean message when using --clean without clone" {
	run ${BATS_TEST_DIRNAME}/../scripts/bootstrap.sh --clean

	[ "$status" -eq 0 ]
	[[ "$output" == *"이미 설치된 cockpit 레포지토리가 없습니다"* ]]
}

@test "bootstrap.sh: fails when git is not installed" {
	# git 명령어를 가짜로 만들어서(mock) 실패하도록 유도
	command() {
		if [ "$1" = "-v" ] && [ "$2" = "git" ]; then
			return 1
		fi
		builtin command "$@"
	}
	export -f command

	run ${BATS_TEST_DIRNAME}/../scripts/bootstrap.sh

	[ "$status" -eq 1 ]
	[[ "$output" == *"git 필요"* ]]

	unset -f command
}
