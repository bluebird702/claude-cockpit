#!/usr/bin/env bash
# scripts/sync-i18n.sh
#
# 한국어 스킬 파일(*.ko.md)을 영어 원본(*.md)으로 자동 번역하여 동기화합니다.
# 사용법: ./scripts/sync-i18n.sh [파일경로 또는 폴더경로]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_arguments() {
	case "${1:-}" in
	-h | --help)
		cat <<EOF
Usage: $0 [파일경로 또는 폴더경로]

한국어 스킬 파일(*.ko.md)을 영어 원본(*.md)으로 번역·동기화합니다.
영어본이 더 최신이면 건너뜁니다. 기본 대상: skills

요구: claude CLI
EOF
		exit 0
		;;
	esac
	TARGET="${1:-skills}"
}

check_dependencies() {
	require_cmd claude
}

translate_file() {
	local ko_file="$1"
	local en_file="${ko_file%.ko.md}.md"

	if [ -f "$en_file" ] && [ "$ko_file" -ot "$en_file" ]; then
		log_dim "건너뜀: $ko_file (영어본이 최신)"
		return 0
	fi

	log_info "번역 중: $ko_file → $en_file"

	# Claude Code를 사용해 인라인 번역 실행
	claude -p "Translate the following markdown file to professional Software Engineering English. Keep all YAML frontmatter keys exactly the same, only translate their string values if necessary. Keep all XML tags like <thinking> exactly the same. Do not output anything except the translated markdown. File content: $(cat "$ko_file")" >"$en_file"

	log_ok "번역 완료: $en_file"
}

sync_all_files() {
	find "$TARGET" -name "*.ko.md" | while read -r ko_file; do
		translate_file "$ko_file"
	done
}

main() {
	parse_arguments "$@"
	check_dependencies
	sync_all_files
	echo "🎉 All files synced."
}

main "$@"
