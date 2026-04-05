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
      # -U : update if exists
      security add-generic-password \
        -a "$USER" \
        -s "$SECRETS_SERVICE" \
        -l "$SECRETS_SERVICE:$key" \
        -D "claude-cockpit secret" \
        -c "cckt" \
        -C "cckt" \
        -U \
        -w "$value" \
        -T "" \
        "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null || \
      security add-generic-password \
        -a "$key" -s "$SECRETS_SERVICE" -U -w "$value" 2>/dev/null || \
      die "Keychain 저장 실패: $key"
      # 단순화: account 를 key 로 해서 다시 저장 (신뢰성)
      security delete-generic-password -a "$key" -s "$SECRETS_SERVICE" >/dev/null 2>&1 || true
      security add-generic-password -a "$key" -s "$SECRETS_SERVICE" -w "$value" -U >/dev/null
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
      tmp="$(mktemp)"
      # 기존 동일 키 제거
      if [ -f "$SECRETS_FALLBACK_FILE" ]; then
        grep -v "^export ${key}=" "$SECRETS_FALLBACK_FILE" > "$tmp" || true
      fi
      local esc="${value//\'/\'\\\'\'}"
      echo "export ${key}='${esc}'" >> "$tmp"
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
      awk -F'=' -v k="$key" '
        $1 == "export " k {
          sub(/^export [^=]+=/, "")
          gsub(/^'\''|'\''$/, "")
          print
          exit
        }' "$SECRETS_FALLBACK_FILE"
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
    for key in "${keys[@]}"; do
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
