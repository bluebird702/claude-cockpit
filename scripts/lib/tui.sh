#!/usr/bin/env bash
# tui.sh - 순수 Bash TUI 컴포넌트
# source 로 사용. common.sh가 먼저 source 되어 있다고 가정합니다.

# ─────────────────────────────────────────────
# 배너
# ─────────────────────────────────────────────
tui_banner() {
  local title="$1"
  local sub="${2:-}"
  local width=55
  local bar
  bar="$(printf '─%.0s' $(seq 1 $width))"
  printf '\n%s┌%s┐%s\n' "$C_BOLD" "$bar" "$C_RESET"
  printf '%s│ %-*s │%s\n' "$C_BOLD" $((width-2)) "$title" "$C_RESET"
  if [ -n "$sub" ]; then
    printf '%s│ %-*s │%s\n' "$C_DIM" $((width-2)) "$sub" "$C_RESET"
  fi
  printf '%s└%s┘%s\n\n' "$C_BOLD" "$bar" "$C_RESET"
}

# tui_step <current> <total> <label>
tui_step() {
  printf '%s[%s/%s]%s %s\n' "$C_BOLD$C_CYAN" "$1" "$2" "$C_RESET" "$3"
}

tui_section() {
  printf '\n%s%s── %s ──%s\n' "$C_BOLD" "$C_MAGENTA" "$1" "$C_RESET"
}

# ─────────────────────────────────────────────
# 입력: ask <varname> <prompt> [default]
# ─────────────────────────────────────────────
tui_ask() {
  local var="$1" prompt="$2" default="${3:-}"
  local input
  if [ -n "$default" ]; then
    printf '  %s%s%s [%s%s%s]: ' "$C_BOLD" "$prompt" "$C_RESET" "$C_DIM" "$default" "$C_RESET"
  else
    printf '  %s%s%s: ' "$C_BOLD" "$prompt" "$C_RESET"
  fi
  IFS= read -r input </dev/tty || input=""
  [ -z "$input" ] && input="$default"
  printf -v "$var" '%s' "$input"
}

# tui_ask_secret <varname> <prompt>
tui_ask_secret() {
  local var="$1" prompt="$2" input
  printf '  %s%s%s (숨김): ' "$C_BOLD" "$prompt" "$C_RESET"
  stty -echo 2>/dev/null || true
  IFS= read -r input </dev/tty || input=""
  stty echo 2>/dev/null || true
  printf '\n'
  printf -v "$var" '%s' "$input"
}

# tui_confirm <prompt> [default=Y]  (0=yes, 1=no)
tui_confirm() {
  local prompt="$1" default="${2:-Y}" ans
  local hint="[Y/n]"
  [ "$default" = "N" ] && hint="[y/N]"
  printf '\n%s%s%s %s: ' "$C_BOLD" "$prompt" "$C_RESET" "$hint"
  IFS= read -r ans </dev/tty || ans=""
  [ -z "$ans" ] && ans="$default"
  case "$ans" in
    Y|y|yes|Yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ─────────────────────────────────────────────
# 다중 선택: tui_select_multi <result_var> <label1> <label2> ...
# 기본값은 모두 선택. 사용자가 번호를 스페이스 구분으로 입력해서 토글.
# 결과는 공백 구분 인덱스 목록 (1-based).
# ─────────────────────────────────────────────
tui_select_multi() {
  local result_var="$1"; shift
  local -a labels=("$@")
  local n=${#labels[@]}
  local -a selected=()
  local i
  for ((i=0; i<n; i++)); do selected[i]=1; done

  while :; do
    printf '\n'
    for ((i=0; i<n; i++)); do
      if [ "${selected[i]}" = "1" ]; then
        printf '  %s[x]%s %d. %s\n' "$C_GREEN" "$C_RESET" $((i+1)) "${labels[i]}"
      else
        printf '  [ ] %d. %s\n' $((i+1)) "${labels[i]}"
      fi
    done
    printf '\n  %s토글할 번호(공백 구분), 엔터=확정, a=모두선택, n=모두해제:%s ' "$C_DIM" "$C_RESET"
    local input
    IFS= read -r input </dev/tty || input=""
    if [ -z "$input" ]; then break; fi
    case "$input" in
      a|A) for ((i=0; i<n; i++)); do selected[i]=1; done ;;
      n|N) for ((i=0; i<n; i++)); do selected[i]=0; done ;;
      *)
        local tok
        for tok in $input; do
          if [[ "$tok" =~ ^[0-9]+$ ]] && [ "$tok" -ge 1 ] && [ "$tok" -le "$n" ]; then
            local idx=$((tok-1))
            if [ "${selected[idx]}" = "1" ]; then selected[idx]=0; else selected[idx]=1; fi
          fi
        done
        ;;
    esac
  done

  local out=""
  for ((i=0; i<n; i++)); do
    [ "${selected[i]}" = "1" ] && out="$out $((i+1))"
  done
  printf -v "$result_var" '%s' "${out# }"
}

# ─────────────────────────────────────────────
# 스피너 (백그라운드 프로세스)
# ─────────────────────────────────────────────
_TUI_SPIN_PID=""
tui_spinner_start() {
  local msg="$1"
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  (
    local i=0
    while :; do
      local f="${frames:i:1}"
      printf '\r  %s%s%s %s' "$C_CYAN" "$f" "$C_RESET" "$msg"
      i=$(( (i+1) % ${#frames} ))
      sleep 0.08
    done
  ) &
  _TUI_SPIN_PID=$!
  disown "$_TUI_SPIN_PID" 2>/dev/null || true
}

tui_spinner_stop() {
  local status="${1:-ok}" msg="${2:-}"
  if [ -n "$_TUI_SPIN_PID" ]; then
    kill "$_TUI_SPIN_PID" 2>/dev/null || true
    wait "$_TUI_SPIN_PID" 2>/dev/null || true
    _TUI_SPIN_PID=""
  fi
  printf '\r\033[K'
  case "$status" in
    ok)   printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$msg" ;;
    fail) printf '  %s✘%s %s\n' "$C_RED"   "$C_RESET" "$msg" ;;
    *)    printf '  • %s\n' "$msg" ;;
  esac
}

# trap으로 스피너 잔존 방지
trap 'tui_spinner_stop fail "중단됨" 2>/dev/null || true' INT TERM
