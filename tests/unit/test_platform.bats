#!/usr/bin/env bats

# scripts/lib/common.sh 의 환경 감지 함수 — 특정 PC 를 전제하지 않는지 검증
# uname·docker·패키지 매니저는 임시 bin 의 스텁으로 대체한다.

setup() {
	source "${BATS_TEST_DIRNAME}/../../scripts/lib/common.sh"
	export TEST_TEMP_DIR="$(mktemp -d)"
	STUB_BIN="$TEST_TEMP_DIR/bin"
	mkdir -p "$STUB_BIN"
	# 스텁 + 기본 유틸만 보이게 (호스트의 brew·docker 등이 결과에 섞이지 않도록)
	export PATH="$STUB_BIN:/usr/bin:/bin"
}

teardown() {
	rm -rf "$TEST_TEMP_DIR"
}

stub() {
	# stub <name> <script body>
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
