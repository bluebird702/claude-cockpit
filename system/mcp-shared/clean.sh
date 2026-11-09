#!/usr/bin/env bash
# mcp/clean.sh - cockpit MCP 서버 설정 제거
#
# 동작:
#   1) Claude Code user 범위에서 cockpit 이 등록한 서버 제거 (claude mcp remove --scope user)
#      — 소유 기록(mcp-servers.list)에 있는 것만. 사용자가 직접 추가한 동명 서버는 보존
#      — 구버전이 settings.json mcpServers 에 남긴 잔여 항목도 함께 정리
#   2) 비밀값을 Keychain/libsecret/파일폴백에서 삭제 (--purge-env 시)
#   3) 공개 env, 로더 스크립트 삭제 (--purge-env 시)
#   4) 쉘 rc 의 source 라인 제거 (--purge-env 시)
#   5) Colima 데몬 정지 (--stop-colima 시) — setup.sh 가 자동 시작한 것과 대칭
#
# 사용법:
#   mcp/clean.sh [--only github,jira] [--yes] [--purge-env] [--stop-colima]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/tui.sh"
source "$ROOT_DIR/scripts/lib/jq_merge.sh"
source "$ROOT_DIR/scripts/lib/secrets.sh"
source "$ROOT_DIR/scripts/lib/claude_mcp.sh"

SERVERS_JSON="$SCRIPT_DIR/servers.json"
# 구버전이 MCP 를 기록하던 위치 — 잔여 항목 정리용
SETTINGS_JSON="$(claude_home)/settings.json"
CONFIG_DIR="$HOME/.config/claude-cockpit"
PUBLIC_ENV="$CONFIG_DIR/mcp.public.env"
LOADER_SH="$CONFIG_DIR/load-mcp-env.sh"

OPT_ONLY=""
OPT_YES=0
OPT_PURGE=0
OPT_STOP_COLIMA=0

while [ $# -gt 0 ]; do
	case "$1" in
	--only)
		OPT_ONLY="$2"
		shift 2
		;;
	--only=*)
		OPT_ONLY="${1#*=}"
		shift
		;;
	--yes | -y)
		OPT_YES=1
		shift
		;;
	--purge-env)
		OPT_PURGE=1
		shift
		;;
	--stop-colima)
		OPT_STOP_COLIMA=1
		shift
		;;
	-h | --help)
		cat <<EOF
Usage: $0 [options]
  --only <a,b>   제거할 서버만 지정
  --yes          확인 자동 승인
  --purge-env    Keychain 비밀, mcp.public.env, 로더, rc source 라인 모두 제거
  --stop-colima  Colima 데몬 정지 (setup.sh 가 자동 시작한 것과 대칭)
EOF
		exit 0
		;;
	*) die "알 수 없는 옵션: $1" ;;
	esac
done

tui_banner "Claude Cockpit · MCP Clean" "cockpit 관리 MCP 설정 제거"

run_preflight_checks_and_select() {
	tui_step 1 3 "사전 점검"
	require_cmd jq
	[ -f "$SERVERS_JSON" ] || die "servers.json 이 없습니다: $SERVERS_JSON"
	log_ok "servers.json OK"
	log_ok "등록 위치: $(claude_user_config) (user 범위)"

	COCKPIT_SERVERS=()
	while IFS= read -r name; do COCKPIT_SERVERS+=("$name"); done < <(jq -r '.servers | keys[]' "$SERVERS_JSON")

	TARGETS=()
	if [ -n "$OPT_ONLY" ]; then
		IFS=',' read -r -a ONLY_ARR <<<"$OPT_ONLY"
		for s in ${ONLY_ARR[@]+"${ONLY_ARR[@]}"}; do
			s="$(echo "$s" | tr -d '[:space:]')"
			for c in ${COCKPIT_SERVERS[@]+"${COCKPIT_SERVERS[@]}"}; do
				[ "$c" = "$s" ] && TARGETS+=("$s") && continue 2
			done
			die "알 수 없는 서버: $s"
		done
	else
		TARGETS=(${COCKPIT_SERVERS[@]+"${COCKPIT_SERVERS[@]}"})
	fi

	INSTALLED=() # cockpit 이 등록한 서버 (소유 기록 기준)
	LEGACY=()    # 구버전이 settings.json 에 남긴 잔여 항목
	for s in ${TARGETS[@]+"${TARGETS[@]}"}; do
		if mcp_manifest_has "$s"; then
			INSTALLED+=("$s")
		elif mcp_user_has "$s"; then
			log_dim "  · $s: cockpit 이 등록하지 않은 서버 — 보존"
		fi
		if mcp_legacy_has "$SETTINGS_JSON" "$s"; then
			LEGACY+=("$s")
		fi
	done

	if [ ${#INSTALLED[@]} -gt 0 ]; then
		require_cmd claude
	fi
}

show_removal_summary() {
	tui_step 2 3 "제거 대상 확인"
	if [ ${#INSTALLED[@]} -eq 0 ]; then
		log_warn "제거할 cockpit 관리 MCP 서버가 없습니다."
	else
		printf '  %s제거할 서버:%s\n' "$C_BOLD" "$C_RESET"
		for s in ${INSTALLED[@]+"${INSTALLED[@]}"}; do
			printf '    - %s\n' "$s"
		done
	fi

	if [ ${#LEGACY[@]} -gt 0 ]; then
		printf '\n  %s구버전 잔여 항목 정리 (%s):%s\n' "$C_BOLD" "$SETTINGS_JSON" "$C_RESET"
		for s in ${LEGACY[@]+"${LEGACY[@]}"}; do
			printf '    - mcpServers.%s\n' "$s"
		done
	fi

	if [ "$OPT_PURGE" = "1" ]; then
		printf '\n  %s추가 제거(--purge-env):%s\n' "$C_BOLD" "$C_RESET"
		printf '    - Keychain/libsecret 비밀값\n'
		printf '    - %s\n' "$PUBLIC_ENV"
		printf '    - %s\n' "$LOADER_SH"
		printf '    - 쉘 rc 의 cockpit source 라인\n'
	fi

	if [ "$OPT_STOP_COLIMA" = "1" ]; then
		printf '\n  %sColima 런타임(--stop-colima):%s\n' "$C_BOLD" "$C_RESET"
		if command -v colima >/dev/null 2>&1 && colima status >/dev/null 2>&1; then
			printf '    - colima 데몬 정지\n'
		else
			printf '    - (이미 정지 상태 또는 colima 미설치)\n'
		fi
	fi

	if [ ${#INSTALLED[@]} -eq 0 ] && [ ${#LEGACY[@]} -eq 0 ] && [ "$OPT_PURGE" = "0" ] && [ "$OPT_STOP_COLIMA" = "0" ]; then
		log_info "제거할 것이 없습니다. 종료."
		exit 0
	fi

	if [ "$OPT_YES" = "0" ]; then
		if ! tui_confirm "이대로 진행하시겠습니까?" N; then
			log_warn "사용자 취소"
			exit 0
		fi
	fi
}

execute_removal() {
	tui_step 3 3 "적용"

	BACKUP_DIR="$(make_backup_dir mcp-clean)"
	backup_path "$(claude_user_config)" "$BACKUP_DIR"
	[ -f "$SETTINGS_JSON" ] && backup_path "$SETTINGS_JSON" "$BACKUP_DIR"
	[ -f "$PUBLIC_ENV" ] && backup_path "$PUBLIC_ENV" "$BACKUP_DIR"
	[ -f "$LOADER_SH" ] && backup_path "$LOADER_SH" "$BACKUP_DIR"
	log_ok "백업: $BACKUP_DIR"

	for s in ${INSTALLED[@]+"${INSTALLED[@]}"}; do
		if mcp_user_unregister "$s"; then
			log_ok "  - $s 제거됨"
		else
			log_warn "  - $s 제거 실패 — 'claude mcp remove --scope user $s' 로 수동 확인"
		fi
	done

	for s in ${LEGACY[@]+"${LEGACY[@]}"}; do
		json_delete_mcp_server "$SETTINGS_JSON" "$s"
		log_ok "  - settings.json 잔여 항목 mcpServers.$s 제거됨"
	done

	if [ "$OPT_PURGE" = "1" ]; then
		local -a SECRET_KEYS=()
		while IFS= read -r key; do SECRET_KEYS+=("$key"); done < <(
			jq -r '.servers | to_entries[] | .value.inputs[]? | select(.secret==true) | .name' "$SERVERS_JSON"
		)
		for key in ${SECRET_KEYS[@]+"${SECRET_KEYS[@]}"}; do
			secrets_delete "$key"
			log_ok "  - 비밀 $key 제거됨 ($(secrets_backend))"
		done

		[ -f "$PUBLIC_ENV" ] && {
			rm "$PUBLIC_ENV"
			log_ok "  - $PUBLIC_ENV 제거됨"
		}
		[ -f "$LOADER_SH" ] && {
			rm "$LOADER_SH"
			log_ok "  - $LOADER_SH 제거됨"
		}

		remove_source_line() {
			local rc="$1"
			[ -f "$rc" ] || return 0
			if grep -Fq "$LOADER_SH" "$rc"; then
				local tmp
				tmp="$(mktemp)"
				awk -v loader="$LOADER_SH" '
          {
            if ($0 ~ /# claude-cockpit MCP/) { skip_next=1; next }
            if (skip_next) {
              skip_next=0
              if (index($0, loader) > 0) next
              else print "# claude-cockpit MCP"
            }
            print
          }
          END { if (skip_next) print "# claude-cockpit MCP" }
        ' "$rc" >"$tmp"
				mv "$tmp" "$rc"
				log_ok "  - $rc 에서 source 라인 제거"
			fi
		}
		# setup.sh --export-rc 가 셸·OS 별로 고른 rc 후보 전부 (없는 파일은 건너뜀)
		remove_source_line "${ZDOTDIR:-$HOME}/.zshrc"
		[ "${ZDOTDIR:-$HOME}" != "$HOME" ] && remove_source_line "$HOME/.zshrc"
		remove_source_line "$HOME/.bashrc"
		remove_source_line "$HOME/.bash_profile"
	fi

	if [ "$OPT_STOP_COLIMA" = "1" ]; then
		if command -v colima >/dev/null 2>&1 && colima status >/dev/null 2>&1; then
			log_info "colima 정지 중..."
			if colima stop; then
				log_ok "  - colima 정지됨"
			else
				log_warn "  - colima stop 실패 (수동으로 'colima stop' 확인)"
			fi
		else
			log_dim "  · colima 가 실행 중이 아님 (건너뜀)"
		fi
	fi

	[ -f "$SETTINGS_JSON" ] && jq empty "$SETTINGS_JSON"

	printf '\n'
	log_ok "MCP 제거 완료"
	log_dim "  백업: $BACKUP_DIR"
}

main() {
	run_preflight_checks_and_select
	show_removal_summary
	execute_removal
}

main "$@"
