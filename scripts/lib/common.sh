#!/usr/bin/env bash
# common.sh - 공통 유틸리티 (로그, 색상, 심볼릭 링크 헬퍼, 백업)
# 이 파일은 source 로만 사용합니다.

set -euo pipefail

# ─────────────────────────────────────────────
# 색상 (tput 우선, 미지원 시 ANSI 코드)
# ─────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
	C_RESET=$(tput sgr0)
	C_BOLD=$(tput bold)
	C_DIM=$(tput dim)
	C_RED=$(tput setaf 1)
	C_GREEN=$(tput setaf 2)
	C_YELLOW=$(tput setaf 3)
	C_BLUE=$(tput setaf 4)
	# shellcheck disable=SC2034
	C_MAGENTA=$(tput setaf 5)
	C_CYAN=$(tput setaf 6)
else
	# shellcheck disable=SC2034
	C_RESET=''
	C_BOLD=''
	C_DIM=''
	# shellcheck disable=SC2034
	C_RED=''
	C_GREEN=''
	C_YELLOW=''
	C_BLUE=''
	C_MAGENTA=''
	C_CYAN=''
	export C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN
fi

# ─────────────────────────────────────────────
# 로그 함수
# ─────────────────────────────────────────────
log_info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_ok() { printf '%s ✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn() { printf '%s ⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err() { printf '%s ✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
log_step() { printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_CYAN" "$*" "$C_RESET"; }
log_dim() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

die() {
	log_err "$*"
	exit 1
}

# ─────────────────────────────────────────────
# 실행 환경
# ─────────────────────────────────────────────
require_cmd() {
	local cmd
	for cmd in "$@"; do
		command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' 명령이 필요합니다. 먼저 설치하세요."
	done
}

# 특정 장비를 전제하지 않도록, 사용자 환경은 아래 함수로 감지해서 씁니다.

# detect_package_manager — 이 OS 에서 실제로 쓸 수 있는 패키지 매니저 (없으면 빈 문자열)
# Linux 는 배포판 기본 매니저를 Homebrew 보다 우선합니다.
detect_package_manager() {
	local pm candidates
	case "$(uname -s)" in
	Darwin) candidates="brew port" ;;
	Linux) candidates="apt-get dnf yum pacman zypper apk brew" ;;
	MINGW* | MSYS* | CYGWIN*) candidates="choco scoop" ;;
	*) candidates="" ;;
	esac
	for pm in $candidates; do
		if command -v "$pm" >/dev/null 2>&1; then
			echo "$pm"
			return 0
		fi
	done
	echo ""
}

# as_root <cmd...> — root 면 그대로, 아니면 sudo 로 실행 (컨테이너처럼 sudo 가 없는 root 환경 대응)
as_root() {
	if [ "$(id -u)" = "0" ]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		log_err "root 권한이 필요하지만 sudo 가 없습니다: $*"
		return 1
	fi
}

# pkg_install <pkg...> — 감지된 패키지 매니저로 설치 (PKG_MANAGER 로 고정 가능). 미지원이면 1
pkg_install() {
	local pm="${PKG_MANAGER:-$(detect_package_manager)}"
	case "$pm" in
	brew) brew install "$@" ;;
	port) as_root port install "$@" ;;
	apt-get) as_root apt-get update && as_root apt-get install -y "$@" ;;
	dnf) as_root dnf install -y "$@" ;;
	yum) as_root yum install -y "$@" ;;
	pacman) as_root pacman -S --noconfirm --needed "$@" ;;
	zypper) as_root zypper --non-interactive install "$@" ;;
	apk) as_root apk add --no-cache "$@" ;;
	choco) choco install -y "$@" ;;
	scoop) scoop install "$@" ;;
	*) return 1 ;;
	esac
}

# detect_docker_runtime — 이 장비가 쓰는 Docker 런타임 종류
# 출력: colima | orbstack | docker-desktop | rancher-desktop | podman | native | other | none
#   none = docker CLI 없음. 데몬 실행 여부와 무관하게 "무엇을 쓰는 장비인가" 만 판별
#   (실행 여부는 docker_daemon_up). 특정 런타임을 강제하지 않기 위한 감지입니다.
detect_docker_runtime() {
	command -v docker >/dev/null 2>&1 || {
		echo none
		return 0
	}
	local ctx os_name
	ctx="$(docker context show 2>/dev/null || true)"
	case "$ctx" in
	colima*)
		echo colima
		return 0
		;;
	orbstack)
		echo orbstack
		return 0
		;;
	desktop-linux | desktop-windows)
		echo docker-desktop
		return 0
		;;
	rancher-desktop)
		echo rancher-desktop
		return 0
		;;
	esac
	os_name="$(docker info --format '{{.OperatingSystem}}' 2>/dev/null || true)"
	case "$os_name" in
	*"Docker Desktop"*) echo docker-desktop ;;
	*OrbStack*) echo orbstack ;;
	*Rancher*) echo rancher-desktop ;;
	*podman* | *Podman*) echo podman ;;
	*) if [ "$(uname -s)" = "Linux" ]; then echo native; else echo other; fi ;;
	esac
}

docker_daemon_up() {
	command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

# user_shell_rc — 로그인 셸에 맞는 rc 파일 경로. bash/zsh 외(fish 등)는 빈 문자열
# macOS 의 bash 는 로그인 셸로 뜨므로 .bashrc 가 아니라 .bash_profile 을 읽습니다.
user_shell_rc() {
	case "$(basename "${SHELL:-}")" in
	zsh) echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
	bash)
		if [ "$(uname -s)" = "Darwin" ]; then
			echo "$HOME/.bash_profile"
		else
			echo "$HOME/.bashrc"
		fi
		;;
	*) echo "" ;;
	esac
}

# ─────────────────────────────────────────────
# 경로
# ─────────────────────────────────────────────
cockpit_root() {
	# scripts/*.sh 또는 mcp/*.sh 에서 호출될 수 있으므로 git rev-parse 또는 상대경로 탐색
	local here="${BASH_SOURCE[1]:-$0}"
	local dir
	dir="$(cd "$(dirname "$here")" && pwd)"
	while [ "$dir" != "/" ]; do
		if [ -d "$dir/system" ] && [ -d "$dir/skills" ]; then
			echo "$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	die "cockpit 루트를 찾을 수 없습니다 (system/, skills/ 존재 필요)."
}

claude_home() {
	echo "${CLAUDE_HOME:-$HOME/.claude}"
}

# ─────────────────────────────────────────────
# 템플릿 렌더링
# ─────────────────────────────────────────────
# detect_template_vars — 템플릿 치환에 쓸 환경 변수를 수집해 export
#
# 출력 (export):
#   COCKPIT_HOME   cockpit 레포 절대 경로 (호출 시 인자로 전달)
#   USER_NAME      COCKPIT_USER_NAME > $USER > git user.name > "user"
#                  (git user.name 은 회사 아이덴티티일 수 있어 로컬 계정을 우선)
#   GITHUB_ORG     gh api user --jq .login, 없으면 "<YOUR_ORG>"
#
# 사용:
#   detect_template_vars "$ROOT_DIR"
detect_template_vars() {
	export COCKPIT_HOME="${1:-$(pwd)}"
	export HOME_DIR="$HOME" # sed 치환용 alias
	if [ -z "${USER_NAME:-}" ]; then
		USER_NAME="${COCKPIT_USER_NAME:-${USER:-}}"
		[ -z "$USER_NAME" ] && USER_NAME="$(git config --get user.name 2>/dev/null || true)"
		[ -z "$USER_NAME" ] && USER_NAME="user"
	fi
	USER_NAME="$(_sanitize_tvar "$USER_NAME")"
	export USER_NAME
	if [ -z "${GITHUB_ORG:-}" ]; then
		GITHUB_ORG="$(gh api user --jq .login 2>/dev/null || true)"
		# gh 가 에러 본문(JSON 등)을 뱉는 경우가 있어 GitHub 계정명 형식만 수용
		printf '%s' "$GITHUB_ORG" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]{0,38}$' || GITHUB_ORG=""
		[ -z "$GITHUB_ORG" ] && GITHUB_ORG="<YOUR_ORG>"
	fi
	GITHUB_ORG="$(_sanitize_tvar "$GITHUB_ORG")"
	export GITHUB_ORG
}

# _sanitize_tvar — 템플릿 치환값 정화: CR/개행 제거 + sed 메타문자(| & \) 이스케이프
_sanitize_tvar() {
	printf '%s' "$1" | tr -d '\r\n' | sed -e 's/[\\&|]/\\&/g'
}

# render_template <src> <dst>
# {{HOME}}, {{COCKPIT_HOME}}, {{USER_NAME}}, {{GITHUB_ORG}} 을 실제 값으로 치환
# detect_template_vars 를 먼저 호출해야 합니다.
render_template() {
	local src="$1" dst="$2"
	[ -f "$src" ] || die "템플릿 원본 없음: $src"
	[ -n "${COCKPIT_HOME:-}" ] || die "detect_template_vars 를 먼저 호출하세요"
	mkdir -p "$(dirname "$dst")"
	local safe_home
	safe_home="$(_sanitize_tvar "$HOME")"
	local safe_cockpit
	safe_cockpit="$(_sanitize_tvar "$COCKPIT_HOME")"

	sed \
		-e "s|{{HOME}}|${safe_home}|g" \
		-e "s|{{COCKPIT_HOME}}|${safe_cockpit}|g" \
		-e "s|{{USER_NAME}}|${USER_NAME}|g" \
		-e "s|{{GITHUB_ORG}}|${GITHUB_ORG}|g" \
		"$src" >"$dst"
}

# ─────────────────────────────────────────────
# 백업
# ─────────────────────────────────────────────
make_backup_dir() {
	local tag="${1:-cockpit}"
	local ts
	ts="$(date +%Y%m%d-%H%M%S)"
	local dir
	dir="$(claude_home)/backups/${tag}-${ts}"
	mkdir -p "$dir"
	echo "$dir"
}

backup_path() {
	# backup_path <src_path> <backup_dir>
	local src="$1" dir="$2"
	[ -e "$src" ] || return 0
	local name
	name="$(basename "$src")"
	if [ -L "$src" ]; then
		cp -P "$src" "$dir/$name"
	elif [ -d "$src" ]; then
		cp -R "$src" "$dir/$name"
	else
		cp "$src" "$dir/$name"
	fi
}

# ─────────────────────────────────────────────
# 심볼릭 링크 (멱등)
# ─────────────────────────────────────────────
# link_idempotent <src> <dst>
# - dst가 이미 src를 가리키면 no-op
# - dst가 다른 곳을 가리키는 symlink면 교체 (백업은 호출자 책임)
# - dst가 실제 파일/디렉토리면 오류 (덮어쓰기 방지)
link_idempotent() {
	local src="$1" dst="$2"
	[ -e "$src" ] || die "링크 원본이 존재하지 않습니다: $src"
	mkdir -p "$(dirname "$dst")"

	if [ -L "$dst" ]; then
		local current
		current="$(readlink "$dst")"
		if [ "$current" = "$src" ]; then
			log_dim "  = $dst → $src (이미 연결됨)"
			return 0
		fi
		rm "$dst"
		ln -s "$src" "$dst"
		log_ok "  ↻ $dst → $src (교체)"
		return 0
	fi

	if [ -e "$dst" ]; then
		die "실제 파일/디렉토리가 이미 존재합니다: $dst (먼저 백업·제거 필요)"
	fi

	ln -s "$src" "$dst"
	log_ok "  + $dst → $src"
}

unlink_if_cockpit() {
	# unlink_if_cockpit <dst> <cockpit_root>
	# dst가 cockpit 내부를 가리키는 symlink일 때만 제거
	local dst="$1" root="$2"
	[ -L "$dst" ] || return 0
	local target
	target="$(readlink "$dst")"
	case "$target" in
	"$root"/* | "$root")
		rm "$dst"
		log_ok "  - $dst 제거됨"
		;;
	*) log_dim "  ~ $dst 는 cockpit 소유가 아님 (건너뜀)" ;;
	esac
}
