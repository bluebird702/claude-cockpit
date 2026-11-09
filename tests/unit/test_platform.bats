#!/usr/bin/env bats

# scripts/lib/common.sh 의 환경 감지 함수 — 특정 PC 를 전제하지 않는지 검증
# uname·docker·패키지 매니저는 임시 bin 의 스텁으로 대체한다.

setup() {
	source "${BATS_TEST_DIRNAME}/../../scripts/lib/common.sh"
	export TEST_TEMP_DIR="$(mktemp -d)"
	STUB_BIN="$TEST_TEMP_DIR/bin"
	mkdir -p "$STUB_BIN"
	# PATH 를 스텁 디렉토리로만 제한 — /usr/bin 을 넣으면 CI 러너의 실제 apt-get·docker 가
	# 감지되어 결과가 호스트에 따라 달라진다. 함수가 쓰는 기본 유틸만 링크한다.
	local tool
	for tool in basename chmod rm; do
		ln -s "$(command -v "$tool")" "$STUB_BIN/$tool"
	done
	ORIG_PATH="$PATH"
	export PATH="$STUB_BIN"
}

teardown() {
	# 스텁 디렉토리를 지우기 전에 PATH 복원 (bats 내부 정리 단계가 rm 등을 호출)
	export PATH="$ORIG_PATH"
	rm -rf "$TEST_TEMP_DIR"
}

stub() {
	# stub <name> <script body> — 기존 항목(링크 포함)은 지우고 새로 작성
	rm -f "$STUB_BIN/$1"
	printf '#!/bin/sh\n%s\n' "$2" >"$STUB_BIN/$1"
	chmod +x "$STUB_BIN/$1"
}

@test "detect_package_manager: Linux prefers distro manager over Homebrew" {
	stub uname 'echo Linux'
	stub brew 'exit 0'
	stub pacman 'exit 0'
	run detect_package_manager
	[ "$output" = "pacman" ]
}

@test "detect_package_manager: macOS without Homebrew yields empty (no false brew)" {
	stub uname 'echo Darwin'
	run detect_package_manager
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "detect_docker_runtime: none when docker CLI is absent" {
	run detect_docker_runtime
	[ "$output" = "none" ]
}

@test "detect_docker_runtime: recognizes Docker Desktop, OrbStack, Colima by context" {
	stub docker 'case "$1" in context) echo desktop-linux ;; *) exit 1 ;; esac'
	run detect_docker_runtime
	[ "$output" = "docker-desktop" ]

	stub docker 'case "$1" in context) echo orbstack ;; *) exit 1 ;; esac'
	run detect_docker_runtime
	[ "$output" = "orbstack" ]

	stub docker 'case "$1" in context) echo colima-heavy ;; *) exit 1 ;; esac'
	run detect_docker_runtime
	[ "$output" = "colima" ]
}

@test "detect_docker_runtime: default context on Linux is native engine" {
	stub uname 'echo Linux'
	stub docker 'case "$1" in context) echo default ;; info) echo "Ubuntu 22.04.4 LTS" ;; esac'
	run detect_docker_runtime
	[ "$output" = "native" ]
}

@test "user_shell_rc: follows login shell and OS (macOS bash → .bash_profile, fish → none)" {
	HOME="$TEST_TEMP_DIR/h"
	unset ZDOTDIR

	SHELL=/bin/zsh run user_shell_rc
	[ "$output" = "$HOME/.zshrc" ]

	ZDOTDIR="$TEST_TEMP_DIR/zdot" SHELL=/bin/zsh run user_shell_rc
	[ "$output" = "$TEST_TEMP_DIR/zdot/.zshrc" ]

	stub uname 'echo Darwin'
	SHELL=/bin/bash run user_shell_rc
	[ "$output" = "$HOME/.bash_profile" ]

	stub uname 'echo Linux'
	SHELL=/bin/bash run user_shell_rc
	[ "$output" = "$HOME/.bashrc" ]

	SHELL=/usr/bin/fish run user_shell_rc
	[ -z "$output" ]
}

@test "pkg_install: unsupported or missing package manager returns failure" {
	PKG_MANAGER="nonexistent" run pkg_install jq
	[ "$status" -eq 1 ]
}
