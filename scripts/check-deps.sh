#!/usr/bin/env bash
# check-deps.sh - 설치 전 필수·권장 도구 존재 여부 확인
#
# 장비 교체 후 install.sh 한 번으로 완전 재현이 목표입니다.
# 이 스크립트는 **설치를 중단시키지 않고** 부족한 것만 리포트합니다.
# (필수 도구만 빠졌을 때 exit 1)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

tui_banner() { printf '\n%s%s%s\n' "$C_BOLD$C_CYAN" "$*" "$C_RESET"; }

tui_banner "▸ Phase 1 · Doctor (환경 진단)"

declare -a MISSING_REQUIRED=()
declare -a MISSING_RECOMMENDED=()

check() {
  # check <level> <cmd> <hint>
  local level="$1" cmd="$2" hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver="$("$cmd" --version 2>/dev/null | head -1 || echo '')"
    printf '  %s✔%s %-18s %s\n' "$C_GREEN" "$C_RESET" "$cmd" "${C_DIM}${ver}${C_RESET}"
  else
    if [ "$level" = "required" ]; then
      MISSING_REQUIRED+=("$cmd|$hint")
      printf '  %s✘%s %-18s %s%s%s\n' "$C_RED" "$C_RESET" "$cmd" "$C_DIM" "(필수) $hint" "$C_RESET"
    else
      MISSING_RECOMMENDED+=("$cmd|$hint")
      printf '  %s○%s %-18s %s%s%s\n' "$C_YELLOW" "$C_RESET" "$cmd" "$C_DIM" "(권장) $hint" "$C_RESET"
    fi
  fi
}

log_step "필수 도구"
check required git    "Xcode CLT 또는 brew install git"
check required jq     "brew install jq"
check required node   "brew install node"
check required npx    "Node 와 함께 설치됨"
check required curl   "macOS 기본 제공"

log_step "권장 개발 CLI"
check recommended gh        "brew install gh  # GitHub 작업 전반"
check recommended rg        "brew install ripgrep"
check recommended fd        "brew install fd"
check recommended bat       "brew install bat"
check recommended yq        "brew install yq"
check recommended tree      "brew install tree"
check recommended shfmt     "brew install shfmt  # 쉘 포맷 훅"
check recommended shellcheck "brew install shellcheck"

log_step "언어 런타임 (프로젝트에서 쓰는 것만 있으면 됨)"
check recommended python3 "brew install python@3.12 또는 uv"
check recommended uv      "curl -LsSf https://astral.sh/uv/install.sh | sh"
check recommended go      "brew install go"
check recommended cargo   "curl https://sh.rustup.rs -sSf | sh"
check recommended ruff    "brew install ruff 또는 uv pip install ruff"
check recommended biome   "brew install biome  # JS/TS 포맷 훅"
check recommended prettier "npm i -g prettier  # biome 대체"

log_step "컨테이너/인프라 (cockpit 전역 표준)"
check required    colima    "brew install colima  # Docker Desktop 금지 — MCP 런타임 필수"
check required    docker    "brew install docker  # MCP 런타임 필수"
check recommended kubectl   "brew install kubectl"
check recommended terraform "brew install terraform"

log_step "보안"
check recommended security "macOS Keychain CLI (기본 제공)"
check recommended op       "brew install 1password-cli  # 1Password CLI (선택)"

log_step "MCP 네트워크 필수"
check required node "이미 체크됨"

# gh 인증 상태
if command -v gh >/dev/null 2>&1; then
  log_step "GitHub CLI 인증 상태"
  if gh auth status >/dev/null 2>&1; then
    log_ok "gh 인증 OK"
  else
    log_warn "gh auth login 필요 (브라우저 기반 로그인 권장)"
    MISSING_RECOMMENDED+=("gh-auth|gh auth login")
  fi
fi

# Colima 상태
if command -v colima >/dev/null 2>&1; then
  log_step "Colima 상태"
  if colima status >/dev/null 2>&1; then
    log_ok "colima 실행 중"
  else
    log_warn "colima 정지됨 — 'colima start' 로 시작"
  fi
fi

# Git signing 설정 (선택)
if command -v git >/dev/null 2>&1; then
  log_step "Git 서명 설정"
  signingkey="$(git config --global user.signingkey 2>/dev/null || echo '')"
  if [ -n "$signingkey" ]; then
    log_ok "user.signingkey: $signingkey"
  else
    log_dim "  · signingkey 미설정 (선택) — git config --global user.signingkey <KEY>"
  fi
fi

printf '\n'

# colima/docker 자동 설치 (macOS + brew 에서만) — required 로 분류되지만 복구 가능
if [ ${#MISSING_REQUIRED[@]} -gt 0 ] && [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
  declare -a AUTO_INSTALL=()
  for item in "${MISSING_REQUIRED[@]}"; do
    name="${item%%|*}"
    case "$name" in colima|docker) AUTO_INSTALL+=("$name") ;; esac
  done
  if [ ${#AUTO_INSTALL[@]} -gt 0 ]; then
    log_step "Colima 런타임 자동 설치"
    log_info "Homebrew 로 '${AUTO_INSTALL[*]}' 설치 중..."
    if brew install "${AUTO_INSTALL[@]}"; then
      log_ok "설치 완료: ${AUTO_INSTALL[*]}"
      # MISSING_REQUIRED 에서 방금 설치한 것 제거
      declare -a REMAINING=()
      for item in "${MISSING_REQUIRED[@]}"; do
        name="${item%%|*}"
        case "$name" in
          colima|docker) : ;;
          *) REMAINING+=("$item") ;;
        esac
      done
      MISSING_REQUIRED=("${REMAINING[@]+"${REMAINING[@]}"}")
    else
      log_err "brew install 실패: ${AUTO_INSTALL[*]}"
    fi
  fi
fi

if [ ${#MISSING_REQUIRED[@]} -gt 0 ]; then
  log_err "필수 도구 ${#MISSING_REQUIRED[@]}개 누락 — 설치 후 다시 실행하세요:"
  for item in "${MISSING_REQUIRED[@]}"; do
    printf '    · %s\n' "${item#*|}"
  done
  exit 1
fi

if [ ${#MISSING_RECOMMENDED[@]} -gt 0 ]; then
  log_warn "권장 도구 ${#MISSING_RECOMMENDED[@]}개 누락 (설치는 계속됩니다)"
  log_dim "  일괄 설치 예시:"
  printf '  %sbrew install' "$C_DIM"
  for item in "${MISSING_RECOMMENDED[@]}"; do
    name="${item%%|*}"
    case "$name" in gh|rg|fd|bat|yq|tree|shfmt|shellcheck|colima|docker|kubectl|terraform|biome|ruff|op) printf ' %s' "$name" ;; esac
  done
  printf '%s\n' "$C_RESET"
fi

log_ok "환경 진단 완료"
exit 0
