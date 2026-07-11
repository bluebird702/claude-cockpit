#!/usr/bin/env bash
# secrets.sh - OS별 안전한 비밀 저장소 추상화
#
# macOS: security (Keychain)
# Linux: secret-tool (libsecret / GNOME Keyring)
# 폴백 : ~/.config/claude-cockpit/secrets.env (chmod 600) — 경고 출력
#
# 모든 비밀은 service 이름 `claude-cockpit` 와 account 이름 `<KEY>` 로 저장됩니다.
# common.sh 가 먼저 source 되어 있다고 가정합니다.

set -euo pipefail

SECRETS_SERVICE="claude-cockpit"
SECRETS_FALLBACK_FILE="$HOME/.config/claude-cockpit/secrets.env"

# ─────────────────────────────────────────────
# 백엔드 감지: echo keychain | libsecret | file
# ─────────────────────────────────────────────
secrets_backend() {
  if [ "${COCKPIT_SECRETS_BACKEND:-}" != "" ]; then
    echo "$COCKPIT_SECRETS_BACKEND"
    return
  fi
  case "$(uname -s)" in
    Darwin)
      if command -v security >/dev/null 2>&1; then echo keychain; return; fi ;;
    Linux)
      if command -v secret-tool >/dev/null 2>&1; then echo libsecret; return; fi ;;
  esac
  echo file
}

secrets_backend_label() {
  case "$(secrets_backend)" in
    keychain) echo "macOS Keychain" ;;
    libsecret) echo "libsecret (GNOME Keyring)" ;;
    file)     echo "파일 폴백 (~/.config/claude-cockpit/secrets.env, chmod 600)" ;;
  esac
}

# ─────────────────────────────────────────────
# 저장: secrets_set <KEY> <VALUE>
# ─────────────────────────────────────────────
secrets_set() {
  local key="$1" value="$2"
  case "$(secrets_backend)" in
    keychain)
      # account 를 key 로 저장한다 — secrets_get 이 `-a "$key"` 로 조회하므로 일치 필수.
      # (이전의 `-a "$USER"` 저장은 get 이 못 읽는 고아였고, 모든 키가 동일 account 로
      #  충돌해 마지막 값만 남았음.) 기존 항목 제거 후 재저장으로 확실한 update.
      security delete-generic-password -a "$key" -s "$SECRETS_SERVICE" >/dev/null 2>&1 || true
      security add-generic-password \
        -a "$key" -s "$SECRETS_SERVICE" \
        -l "$SECRETS_SERVICE:$key" -D "claude-cockpit secret" \
        -w "$value" -U >/dev/null 2>&1 \
        || die "Keychain 저장 실패: $key"
      ;;
    libsecret)
      printf '%s' "$value" | secret-tool store --label="$SECRETS_SERVICE:$key" \
        service "$SECRETS_SERVICE" account "$key"
      ;;
    file)
      mkdir -p "$(dirname "$SECRETS_FALLBACK_FILE")"
      touch "$SECRETS_FALLBACK_FILE"
      chmod 600 "$SECRETS_FALLBACK_FILE"
      local tmp
      tmp="$(mktemp "${TMPDIR:-/tmp}/cckt-secrets-XXXXXX")"
      # 기존 동일 키 제거
      if [ -f "$SECRETS_FALLBACK_FILE" ]; then
        grep -v "^export ${key}=" "$SECRETS_FALLBACK_FILE" > "$tmp" || true
      fi
      # printf %q 로 shell-safe 인용 — source 로 정확히 복원된다. 이전의 수동
      # `'\''` 이스케이프는 작은따옴표 값에서 문법오류를 만들어(foo'bar → 빈 값)
      # store·get 양쪽이 깨져 있었다.
      printf 'export %s=%q\n' "$key" "$value" >> "$tmp"
      mv "$tmp" "$SECRETS_FALLBACK_FILE"
      chmod 600 "$SECRETS_FALLBACK_FILE"
      ;;
  esac
}

# ─────────────────────────────────────────────
# 조회: secrets_get <KEY>  (없으면 빈 문자열)
# ─────────────────────────────────────────────
secrets_get() {
  local key="$1"
  case "$(secrets_backend)" in
    keychain)
      security find-generic-password -a "$key" -s "$SECRETS_SERVICE" -w 2>/dev/null || true
      ;;
    libsecret)
      secret-tool lookup service "$SECRETS_SERVICE" account "$key" 2>/dev/null || true
      ;;
    file)
      [ -f "$SECRETS_FALLBACK_FILE" ] || return 0
      # 파일은 `export KEY='...'` shell 문이므로 shell 로 평가해 읽는다.
      # awk 파싱은 저장 시의 `'\''` 이스케이프를 되돌리지 못해 작은따옴표 포함
      # 값이 손상됨(예: foo'bar → foo'\''bar). 서브셸로 격리해 유출 방지.
      # shellcheck disable=SC1090
      ( set +u +e; source "$SECRETS_FALLBACK_FILE" 2>/dev/null; printf '%s' "${!key-}" )
      ;;
  esac
}

# ─────────────────────────────────────────────
# 삭제: secrets_delete <KEY>
# ─────────────────────────────────────────────
secrets_delete() {
  local key="$1"
  case "$(secrets_backend)" in
    keychain)
      security delete-generic-password -a "$key" -s "$SECRETS_SERVICE" >/dev/null 2>&1 || true
      ;;
    libsecret)
      secret-tool clear service "$SECRETS_SERVICE" account "$key" 2>/dev/null || true
      ;;
    file)
      [ -f "$SECRETS_FALLBACK_FILE" ] || return 0
      local tmp
      tmp="$(mktemp)"
      grep -v "^export ${key}=" "$SECRETS_FALLBACK_FILE" > "$tmp" || true
      mv "$tmp" "$SECRETS_FALLBACK_FILE"
      chmod 600 "$SECRETS_FALLBACK_FILE"
      ;;
  esac
}

# ─────────────────────────────────────────────
# 환경변수 로더 스크립트 생성
# 쉘 rc 에서 source 할 스크립트를 ~/.config/claude-cockpit/load-secrets.sh 로 생성.
# 호출 시 keychain/libsecret 에서 값을 읽어 export.
# ─────────────────────────────────────────────
# secrets_write_loader <loader_path> <non_secret_env_file> <secret_keys...>
secrets_write_loader() {
  local loader="$1" nonsecret="$2"; shift 2
  local keys=("$@")
  mkdir -p "$(dirname "$loader")"

  local backend
  backend="$(secrets_backend)"

  {
    echo "#!/usr/bin/env bash"
    echo "# claude-cockpit MCP 환경변수 로더 (자동 생성 — 직접 수정하지 마세요)"
    echo "# 생성: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# backend: $backend"
    echo ""
    echo "# 공개 값 (URL, 이메일 등)"
    echo "[ -f \"$nonsecret\" ] && source \"$nonsecret\""
    echo ""
    echo "# 비밀 값 ($(secrets_backend_label))"
    for key in ${keys[@]+"${keys[@]}"}; do
      case "$backend" in
        keychain)
          echo "export $key=\"\$(security find-generic-password -a '$key' -s '$SECRETS_SERVICE' -w 2>/dev/null)\""
          ;;
        libsecret)
          echo "export $key=\"\$(secret-tool lookup service '$SECRETS_SERVICE' account '$key' 2>/dev/null)\""
          ;;
        file)
          echo "# file 백엔드: secrets.env 를 직접 source"
          echo "[ -f \"$SECRETS_FALLBACK_FILE\" ] && source \"$SECRETS_FALLBACK_FILE\""
          break
          ;;
      esac
    done
  } > "$loader"
  chmod 600 "$loader"
}
