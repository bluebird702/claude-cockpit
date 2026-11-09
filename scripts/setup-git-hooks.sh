#!/usr/bin/env bash
# scripts/setup-git-hooks.sh
# 로컬 개발 환경에 Git Hook을 설치합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_arguments() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			cat <<EOF
Usage: $0

cockpit 레포의 pre-commit 훅을 .git/hooks/ 에 심볼릭 링크로 설치합니다.
멱등 — 이미 설치돼 있으면 링크만 갱신합니다.
EOF
			exit 0
			;;
		*) die "알 수 없는 옵션: $1" ;;
		esac
	done
}

install_pre_commit_hook() {
	[ -d "$ROOT_DIR/.git/hooks" ] ||
		die ".git/hooks 디렉토리를 찾을 수 없습니다. Git 레포지토리가 맞는지 확인해주세요."

	ln -sf "$ROOT_DIR/system/git/pre-commit" "$ROOT_DIR/.git/hooks/pre-commit"
	chmod +x "$ROOT_DIR/system/git/pre-commit"
	log_ok "Git pre-commit 훅이 설치되었습니다. (.git/hooks/pre-commit)"
}

main() {
	parse_arguments "$@"
	install_pre_commit_hook
}

main "$@"
