#!/usr/bin/env bash
# format.sh - PostToolUse(Write|Edit) 훅
#
# 방금 편집한 파일을 확장자별 포맷터로 정리합니다. 포맷터가 없으면 조용히 통과.
# 훅은 항상 exit 0 (포맷 실패가 작업 자체를 막아선 안 됩니다 — 로그만 남김).

set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
[ -z "$payload" ] && exit 0

tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
[ -z "$file" ] || [ ! -f "$file" ] && exit 0

# 큰 파일은 건너뜀 (500KB +)
size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
[ "$size" -gt 512000 ] && exit 0

run() { command -v "$1" >/dev/null 2>&1 && "$@" >/dev/null 2>&1 || true; }

# 보안: prettier 는 레포 로컬 JS 설정(.prettierrc.js·prettier.config.js 등)을
# 자기 프로세스에서 실행한다 → 신뢰되지 않은 레포를 편집만 해도 임의 코드 실행.
# JS 설정이 조상 경로에 있으면 --no-config 로 실행(선언적 JSON/YAML 설정·무설정은 그대로).
_has_exec_prettier_config() {
  local d
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || return 1
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in .prettierrc.js prettier.config.js .prettierrc.cjs .prettierrc.mjs prettier.config.cjs prettier.config.mjs; do
      [ -f "$d/$c" ] && return 0
    done
    d="$(dirname "$d")"
  done
  return 1
}

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.jsonc)
    if command -v biome >/dev/null 2>&1; then
      run biome format --write "$file"
    elif command -v prettier >/dev/null 2>&1; then
      if _has_exec_prettier_config "$file"; then
        run prettier --write --log-level silent --no-config "$file"
      else
        run prettier --write --log-level silent "$file"
      fi
    fi ;;
  *.css|*.scss|*.md)
    if command -v prettier >/dev/null 2>&1; then
      if _has_exec_prettier_config "$file"; then
        run prettier --write --log-level silent --no-config "$file"
      else
        run prettier --write --log-level silent "$file"
      fi
    fi ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      run ruff format "$file"
      run ruff check --fix --quiet "$file"
    elif command -v black >/dev/null 2>&1; then
      run black --quiet "$file"
    fi ;;
  *.go)
    run gofmt -w "$file"
    run goimports -w "$file" ;;
  *.rs)
    run rustfmt --edition 2021 "$file" ;;
  *.sh|*.bash)
    run shfmt -w -i 2 -ci "$file" ;;
  *.sql)
    run sqlfluff fix --disable-progress-bar "$file" ;;
  *.tf|*.tfvars)
    run terraform fmt "$file" ;;
  *.yaml|*.yml)
    run yamlfmt "$file" ;;
esac

exit 0
