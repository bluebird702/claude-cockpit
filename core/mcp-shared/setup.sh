#!/usr/bin/env bash
# mcp/setup.sh - MCP 서버 TUI 설치 스크립트
#
# 3-Phase 구조:
#   Phase 1: 사전 점검
#   Phase 2: 입력 수집 및 요약 (파일 변경 없음)
#   Phase 3: 일괄 적용 (백업 → 비밀 저장 → settings.json 머지 → loader 생성)
#
# 비밀값은 macOS Keychain / libsecret 에 저장됩니다. 사용 불가 시 파일 폴백 (chmod 600).
# 공개값(URL, 이메일)은 ~/.config/claude-cockpit/mcp.public.env 에 평문 저장됩니다.
#
# 사용법:
#   mcp/setup.sh [--only github,jira] [--env-file <path>] [--yes] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"
# shellcheck source=../scripts/lib/tui.sh
source "$ROOT_DIR/scripts/lib/tui.sh"
# shellcheck source=../scripts/lib/jq_merge.sh
source "$ROOT_DIR/scripts/lib/jq_merge.sh"
# shellcheck source=../scripts/lib/secrets.sh
source "$ROOT_DIR/scripts/lib/secrets.sh"

SERVERS_JSON="$SCRIPT_DIR/servers.json"
SETTINGS_JSON="$(claude_home)/settings.json"
CONFIG_DIR="$HOME/.config/claude-cockpit"
PUBLIC_ENV="$CONFIG_DIR/mcp.public.env"
LOADER_SH="$CONFIG_DIR/load-mcp-env.sh"

# ─────────────────────────────────────────────
# bash 3.2 호환 key-value 스토어
# macOS 기본 /bin/bash (3.2) 는 `declare -A` 미지원.
# 입력 이름은 모두 [A-Z_]+ (GITHUB_TOKEN 등) 이므로 동적 변수명으로 안전하게 에뮬레이션.
# 키 순회는 ALL_INPUT_KEYS 배열로.
# ─────────────────────────────────────────────
iv_set() { printf -v "INPUT_VALUE_$1" '%s' "$2"; }
iv_get() { local _ref="INPUT_VALUE_$1"; printf '%s' "${!_ref-}"; }
iv_has() { local _ref="INPUT_VALUE_$1"; [ -n "${!_ref:-}" ]; }
is_set_secret() { printf -v "INPUT_SECRET_$1" '%s' "$2"; }
is_get_secret() { local _ref="INPUT_SECRET_$1"; printf '%s' "${!_ref:-false}"; }

OPT_ONLY=""
OPT_ENV_FILE=""
OPT_YES=0
OPT_DRY_RUN=0
OPT_EXPORT_RC=0

while [ $# -gt 0 ]; do
  case "$1" in
    --only)       OPT_ONLY="$2"; shift 2 ;;
    --only=*)     OPT_ONLY="${1#*=}"; shift ;;
    --env-file)   OPT_ENV_FILE="$2"; shift 2 ;;
    --env-file=*) OPT_ENV_FILE="${1#*=}"; shift ;;
    --yes|-y)     OPT_YES=1; shift ;;
    --dry-run)    OPT_DRY_RUN=1; shift ;;
    --export-rc)  OPT_EXPORT_RC=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]
  --only <a,b>      설치할 서버만 지정 (예: github,jira)
  --env-file <path> 입력값을 파일에서 로드 (Phase 2 건너뜀, 권한 600 필요)
  --yes             요약 확인 자동 승인
  --dry-run         실제 변경 없이 결과만 출력
  --export-rc       쉘 rc 에 로더 source 라인 추가 (기본 OFF, 보안상 비권장)
EOF
      exit 0 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

tui_banner "Claude Cockpit · MCP Setup" "Colima Docker 기반 — node:20-alpine · Playwright 브라우저"

# ─────────────────────────────────────────────
# Phase 1: 사전 점검
# ─────────────────────────────────────────────
tui_step 1 3 "사전 점검"
require_cmd jq
log_ok "jq   $(jq --version)"

# Colima + docker CLI 자동 설치·시작 (cockpit 로컬 표준: Docker Desktop 금지)
ensure_colima_runtime() {
  local os
  os="$(uname -s)"

  # 1) colima / docker CLI 미설치 → brew 로 자동 설치
  local need_install=()
  command -v colima >/dev/null 2>&1 || need_install+=("colima")
  command -v docker >/dev/null 2>&1 || need_install+=("docker")

  if [ ${#need_install[@]} -gt 0 ]; then
    log_warn "미설치 도구: ${need_install[*]}"
    if [ "$os" != "Darwin" ]; then
      die "macOS 외 환경은 수동 설치가 필요합니다: ${need_install[*]}"
    fi
    if ! command -v brew >/dev/null 2>&1; then
      die "Homebrew 가 필요합니다. https://brew.sh 에서 설치 후 다시 실행하세요."
    fi
    if [ "$OPT_YES" = "1" ] || tui_confirm "Homebrew 로 '${need_install[*]}' 를 지금 설치하시겠습니까?"; then
      brew install "${need_install[@]}" || die "brew install 실패: ${need_install[*]}"
      log_ok "설치 완료: ${need_install[*]}"
    else
      die "colima/docker 가 필요합니다. 설치 후 다시 실행하세요."
    fi
  fi

  # 2) Colima 데몬 실행 확인 → 정지돼 있으면 자동 시작
  if ! colima status >/dev/null 2>&1; then
    log_warn "Colima 가 정지 상태입니다. 시작합니다 (수 분 소요 가능)..."
    colima start || die "colima start 실패 — 수동으로 'colima start' 확인 후 재실행"
    log_ok "colima 시작됨"
  fi

  # 3) docker daemon 최종 확인
  if ! docker info >/dev/null 2>&1; then
    die "Colima 는 실행 중이나 docker 데몬에 연결할 수 없습니다. 'docker context use colima' 확인 필요."
  fi
}

ensure_colima_runtime

DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
DOCKER_CTX=$(docker context show 2>/dev/null || echo "unknown")
log_ok "docker $DOCKER_VER (context: $DOCKER_CTX)"

json_ensure_file "$SETTINGS_JSON"
log_ok "settings.json OK ($SETTINGS_JSON)"

[ -f "$SERVERS_JSON" ] || die "servers.json 이 없습니다: $SERVERS_JSON"

SECRETS_BACKEND_LABEL="$(secrets_backend_label)"
log_ok "비밀 저장소: $SECRETS_BACKEND_LABEL"
if [ "$(secrets_backend)" = "file" ]; then
  log_warn "Keychain/libsecret을 사용할 수 없어 파일 폴백을 사용합니다."
  log_warn "보안을 위해 macOS 는 'security', Linux 는 'libsecret-tools' 설치를 권장합니다."
fi

# ─────────────────────────────────────────────
# 서버 목록 로드
# ─────────────────────────────────────────────
ALL_SERVERS=()
while IFS= read -r name; do ALL_SERVERS+=("$name"); done < <(jq -r '.servers | keys[]' "$SERVERS_JSON")

SELECTED_SERVERS=()
if [ -n "$OPT_ONLY" ]; then
  IFS=',' read -r -a ONLY_ARR <<< "$OPT_ONLY"
  for s in "${ONLY_ARR[@]}"; do
    s="$(echo "$s" | tr -d '[:space:]')"
    if jq -e --arg n "$s" '.servers[$n]' "$SERVERS_JSON" >/dev/null; then
      SELECTED_SERVERS+=("$s")
    else
      die "알 수 없는 서버: $s (사용 가능: ${ALL_SERVERS[*]})"
    fi
  done
else
  tui_step 2 3 "설치할 MCP 서버 선택"
  LABELS=()
  for s in "${ALL_SERVERS[@]}"; do
    label=$(jq -r --arg n "$s" '.servers[$n].label + " — " + .servers[$n].description' "$SERVERS_JSON")
    LABELS+=("$s  ($label)")
  done
  picked=""
  tui_select_multi picked "${LABELS[@]}"
  [ -z "$picked" ] && die "선택된 서버가 없습니다."
  for idx in $picked; do
    SELECTED_SERVERS+=("${ALL_SERVERS[$((idx-1))]}")
  done
fi

log_ok "선택된 서버: ${SELECTED_SERVERS[*]}"

# ─────────────────────────────────────────────
# Phase 2: 입력 수집 (비밀/공개 분리)
# ─────────────────────────────────────────────
tui_step 3 3 "입력 수집 (모든 입력을 먼저 받고, 이후 일괄 적용)"

# INPUT_VALUE_<NAME> / INPUT_SECRET_<NAME> 동적 변수로 저장 (bash 3.2 호환)
ALL_INPUT_KEYS=() # 입력 순서 보존

# env-file 로드 (Phase 2 프롬프트 생략)
if [ -n "$OPT_ENV_FILE" ]; then
  [ -f "$OPT_ENV_FILE" ] || die "env-file 이 존재하지 않습니다: $OPT_ENV_FILE"

  # 보안: env-file 은 심볼릭 링크 금지 + owner-only 권한만 허용 (600/400)
  if [ -L "$OPT_ENV_FILE" ]; then
    die "env-file 이 심볼릭 링크입니다 (거부). 실제 파일 경로를 지정하세요: $OPT_ENV_FILE"
  fi
  ef_perm="$(stat -f '%Lp' "$OPT_ENV_FILE" 2>/dev/null || stat -c '%a' "$OPT_ENV_FILE" 2>/dev/null || echo '???')"
  case "$ef_perm" in
    600|400) log_dim "  env-file 권한 OK ($ef_perm)" ;;
    *)  die "env-file 권한이 너무 느슨합니다 ($ef_perm). chmod 600 $OPT_ENV_FILE 후 다시 시도하세요." ;;
  esac
  ef_owner="$(stat -f '%u' "$OPT_ENV_FILE" 2>/dev/null || stat -c '%u' "$OPT_ENV_FILE" 2>/dev/null || echo '')"
  if [ -n "$ef_owner" ] && [ "$ef_owner" != "$(id -u)" ]; then
    die "env-file 소유자가 현재 사용자가 아닙니다 (uid=$ef_owner). 거부."
  fi

  log_info "env-file 로드: $OPT_ENV_FILE"
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key="$(echo "$key" | tr -d '[:space:]')"
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"
    iv_set "$key" "$val"
  done < "$OPT_ENV_FILE"
fi

validate_input() {
  local type="$1" value="$2"
  case "$type" in
    url)   [[ "$value" =~ ^https?:// ]] || return 1 ;;
    email) [[ "$value" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || return 1 ;;
    token) [ -n "$value" ] && [ "${#value}" -ge 8 ] || return 1 ;;
    path)  [ -n "$value" ] && [ -d "$value" ] || return 1 ;;
  esac
  return 0
}

collect_inputs_for_server() {
  local server="$1"
  local n_inputs
  n_inputs=$(jq -r --arg n "$server" '.servers[$n].inputs | length' "$SERVERS_JSON")
  [ "$n_inputs" = "0" ] && return 0

  tui_section "▸ $(jq -r --arg n "$server" '.servers[$n].label' "$SERVERS_JSON")"

  local i
  for ((i=0; i<n_inputs; i++)); do
    local name prompt default secret validate
    name=$(jq -r --arg n "$server" --argjson i "$i" '.servers[$n].inputs[$i].name' "$SERVERS_JSON")
    prompt=$(jq -r --arg n "$server" --argjson i "$i" '.servers[$n].inputs[$i].prompt' "$SERVERS_JSON")
    default=$(jq -r --arg n "$server" --argjson i "$i" '.servers[$n].inputs[$i].default // ""' "$SERVERS_JSON")
    secret=$(jq -r --arg n "$server" --argjson i "$i" '.servers[$n].inputs[$i].secret // false' "$SERVERS_JSON")
    validate=$(jq -r --arg n "$server" --argjson i "$i" '.servers[$n].inputs[$i].validate // ""' "$SERVERS_JSON")

    is_set_secret "$name" "$secret"
    ALL_INPUT_KEYS+=("$name")

    # env-file 에서 이미 받았으면 건너뜀
    if iv_has "$name"; then
      log_dim "  · $name (env-file에서 로드됨)"
      continue
    fi

    while :; do
      local val=""
      if [ "$secret" = "true" ]; then
        tui_ask_secret val "$prompt"
      else
        tui_ask val "$prompt" "$default"
      fi
      if [ -n "$validate" ] && ! validate_input "$validate" "$val"; then
        log_warn "  $name: '$validate' 형식이 아닙니다. 다시 입력하세요."
        continue
      fi
      if [ -z "$val" ]; then
        log_warn "  $name: 값이 비어 있습니다. 다시 입력하세요."
        continue
      fi
      iv_set "$name" "$val"
      break
    done
  done
}

for s in "${SELECTED_SERVERS[@]}"; do
  collect_inputs_for_server "$s"
done

# ─────────────────────────────────────────────
# 입력 요약
# ─────────────────────────────────────────────
tui_section "입력 요약"
mask() {
  local v="$1"
  local len=${#v}
  if [ "$len" -le 6 ]; then printf '******'
  else printf '%s****%s' "${v:0:3}" "${v: -3}"
  fi
}

for s in "${SELECTED_SERVERS[@]}"; do
  n_inputs=$(jq -r --arg n "$s" '.servers[$n].inputs | length' "$SERVERS_JSON")
  if [ "$n_inputs" = "0" ]; then
    printf '  %-12s %s(입력 없음)%s\n' "$s" "$C_DIM" "$C_RESET"
    continue
  fi
  line=""
  for ((i=0; i<n_inputs; i++)); do
    name=$(jq -r --arg n "$s" --argjson i "$i" '.servers[$n].inputs[$i].name' "$SERVERS_JSON")
    val="$(iv_get "$name")"
    if [ "$(is_get_secret "$name")" = "true" ]; then
      line="$line  $name=$(mask "$val")"
    else
      line="$line  $name=$val"
    fi
  done
  printf '  %-12s%s\n' "$s" "$line"
done

printf '\n  %s비밀값 저장소:%s %s\n' "$C_BOLD" "$C_RESET" "$SECRETS_BACKEND_LABEL"
printf '  %s공개값 파일 :%s %s\n'    "$C_BOLD" "$C_RESET" "$PUBLIC_ENV"

# ─────────────────────────────────────────────
# 확인
# ─────────────────────────────────────────────
if [ "$OPT_DRY_RUN" = "1" ]; then
  log_warn "dry-run 모드: 실제 변경 없이 종료합니다."
  exit 0
fi

if [ "$OPT_YES" = "0" ]; then
  if ! tui_confirm "이대로 진행하시겠습니까?"; then
    log_warn "사용자 취소"
    exit 0
  fi
fi

# ─────────────────────────────────────────────
# Phase 3: 일괄 적용
# ─────────────────────────────────────────────
printf '\n'
log_step "Phase 3 · 일괄 적용"

# 1) 백업
BACKUP_DIR="$(make_backup_dir mcp)"
backup_path "$SETTINGS_JSON" "$BACKUP_DIR"
[ -f "$PUBLIC_ENV" ] && backup_path "$PUBLIC_ENV" "$BACKUP_DIR"
[ -f "$LOADER_SH" ] && backup_path "$LOADER_SH" "$BACKUP_DIR"
log_ok "백업: $BACKUP_DIR"

# 2) 비밀값 → Keychain/libsecret/파일폴백
SECRET_KEYS=()
for key in "${ALL_INPUT_KEYS[@]+"${ALL_INPUT_KEYS[@]}"}"; do
  if [ "$(is_get_secret "$key")" = "true" ]; then
    secrets_set "$key" "$(iv_get "$key")"
    SECRET_KEYS+=("$key")
  fi
done
if [ ${#SECRET_KEYS[@]} -gt 0 ]; then
  log_ok "비밀값 ${#SECRET_KEYS[@]}개 저장 완료 ($(secrets_backend))"
fi

# 3) 공개값 → mcp.public.env (멱등 갱신)
mkdir -p "$CONFIG_DIR"
tmp_pub="$(mktemp)"
if [ -f "$PUBLIC_ENV" ]; then
  # 이번에 덮어쓸 키들을 기존 파일에서 제거 (입력 없는 서버만 단독 등록 시 ALL_INPUT_KEYS 비어있을 수 있음)
  if [ "${#ALL_INPUT_KEYS[@]}" -gt 0 ]; then
    grep -v -E "^export ($(IFS='|'; echo "${ALL_INPUT_KEYS[*]}"))=" "$PUBLIC_ENV" > "$tmp_pub" 2>/dev/null || true
  else
    cp "$PUBLIC_ENV" "$tmp_pub"
  fi
fi
{
  echo "# claude-cockpit MCP 공개값 (자동 생성 — $(date '+%Y-%m-%d %H:%M:%S'))"
  echo "# 비밀값은 이 파일에 저장되지 않습니다 ($SECRETS_BACKEND_LABEL)."
  for key in "${ALL_INPUT_KEYS[@]+"${ALL_INPUT_KEYS[@]}"}"; do
    [ "$(is_get_secret "$key")" = "true" ] && continue
    val="$(iv_get "$key")"
    esc="${val//\'/\'\\\'\'}"
    echo "export $key='$esc'"
  done
} >> "$tmp_pub"
mv "$tmp_pub" "$PUBLIC_ENV"
chmod 600 "$PUBLIC_ENV"
log_ok "공개값 파일: $PUBLIC_ENV"

# 4) 로더 스크립트 생성 (쉘 rc 가 이것만 source 하면 끝)
#    SECRET_KEYS 가 비어 있어도 안전하도록 ${arr[@]+"${arr[@]}"} 패턴 사용
#    (시크릿 없는 서버만 단독 등록할 때 unbound variable 방지)
secrets_write_loader "$LOADER_SH" "$PUBLIC_ENV" ${SECRET_KEYS[@]+"${SECRET_KEYS[@]}"}
log_ok "로더 스크립트: $LOADER_SH"

# 5) 쉘 rc 에 source 한 줄 추가는 기본 비활성화 (보안)
#
# 이유: rc 에 로더를 넣으면 모든 서브쉘·VSCode 확장·잡다한 스크립트가 토큰을
#      환경변수로 읽을 수 있습니다. Claude Code 는 settings.json 의 env 치환으로
#      MCP 서버 프로세스에만 토큰을 전달할 수 있으므로 rc 노출은 불필요합니다.
#
# 필요하면 --export-rc 옵션으로 명시 옵트인 하세요.
if [ "${OPT_EXPORT_RC:-0}" = "1" ]; then
  append_source_line() {
    local rc="$1"
    local line="[ -f $LOADER_SH ] && source $LOADER_SH"
    [ -f "$rc" ] || touch "$rc"
    if grep -Fq "$LOADER_SH" "$rc" 2>/dev/null; then
      log_dim "  = $rc 에 이미 source 라인 존재"
      return 0
    fi
    printf '\n# claude-cockpit MCP\n%s\n' "$line" >> "$rc"
    log_ok "  + $rc 에 source 라인 추가 (--export-rc)"
  }
  case "${SHELL:-}" in
    */zsh)  append_source_line "$HOME/.zshrc" ;;
    */bash) append_source_line "$HOME/.bashrc" ;;
    *)      append_source_line "$HOME/.zshrc" ;;
  esac
else
  log_dim "  · 쉘 rc 자동 추가 생략 (기본값). 필요하면 --export-rc 옵션."
  log_dim "    토큰은 MCP 서버 프로세스에만 전달되며, 일반 쉘 환경에는 노출되지 않습니다."
fi

# 6) settings.json 에 서버별 머지
i=0
total=${#SELECTED_SERVERS[@]}
for s in "${SELECTED_SERVERS[@]}"; do
  i=$((i+1))
  tui_spinner_start "[$i/$total] $s · settings.json 머지 중..."
  # 원격(URL) 서버와 로컬(command) 서버를 구분해 추출
  server_type=$(jq -r --arg n "$s" '.servers[$n].type // "command"' "$SERVERS_JSON")
  if [ "$server_type" = "url" ]; then
    server_json=$(jq --arg n "$s" '.servers[$n] | {type, url}' "$SERVERS_JSON")
  else
    server_json=$(jq --arg n "$s" '.servers[$n] | {command, args, env}' "$SERVERS_JSON")
  fi

  # 비밀이 아닌 입력값을 args 에 치환 (예: filesystem 볼륨 마운트 경로)
  # 비밀값은 Claude Code 가 프로세스 환경에서 치환하므로 여기서 건드리지 않음
  # sed replacement 에서 &, |, \ 는 특수문자이므로 이스케이프 필요
  for _sub_key in "${ALL_INPUT_KEYS[@]+"${ALL_INPUT_KEYS[@]}"}"; do
    if [ "$(is_get_secret "$_sub_key")" != "true" ]; then
      _sub_val="$(iv_get "$_sub_key")"
      _sub_val_esc=$(printf '%s' "$_sub_val" | sed -e 's/[\\&|]/\\&/g')
      server_json=$(printf '%s' "$server_json" | sed "s|\${${_sub_key}}|${_sub_val_esc}|g")
    fi
  done

  if json_merge_mcp_server "$SETTINGS_JSON" "$s" "$server_json"; then
    tui_spinner_stop ok "[$i/$total] $s 완료"
  else
    tui_spinner_stop fail "[$i/$total] $s 실패"
    log_err "백업에서 복원: cp $BACKUP_DIR/settings.json $SETTINGS_JSON"
    exit 1
  fi
done

# 7) 최종 검증
jq empty "$SETTINGS_JSON" || die "최종 settings.json JSON 유효성 검사 실패"

printf '\n'
log_ok "MCP 설치 완료 ($total/$total)"
log_dim "  백업:       $BACKUP_DIR"
log_dim "  비밀:       $SECRETS_BACKEND_LABEL"
log_dim "  공개 env:   $PUBLIC_ENV"
log_dim "  로더:       $LOADER_SH"
log_dim "  settings:   $SETTINGS_JSON"
printf '\n  다음 단계: %s새 셸을 열거나%s %ssource %s%s, Claude Code 재시작 후 %s/mcp%s 로 확인하세요.\n\n' \
  "$C_BOLD" "$C_RESET" "$C_CYAN" "$LOADER_SH" "$C_RESET" "$C_CYAN" "$C_RESET"
