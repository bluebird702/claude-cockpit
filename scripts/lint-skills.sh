#!/usr/bin/env bash
# lint-skills.sh — 스킬 마크다운 정합성 린트 (CI·로컬 공용, 결정적)
#
# 검사:
#   1) frontmatter 필수 6필드 존재 (name·description·type·category·follows-brain·enforcement)
#   2) follows-brain 가 가리키는 표준 파일이 brain/ 아래 실제 존재
#   3) 본문 @brain/@docs 참조가 dangling 인지 (경고)
#
# 종료코드: 0 통과 / 1 실패(필수 필드·경로 오류)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

init_globals() {
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$ROOT"

  REQUIRED=(name description type category follows-brain enforcement)
  fail=0
  warn=0
}

lint_frontmatter_presence() {
  local f="$1"
  fm="$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print} n>=2{exit}' "$f")"
  if [ -z "$fm" ]; then
    echo "✘ $f: frontmatter 없음"
    fail=$((fail + 1))
    return 1
  fi
  return 0
}

lint_frontmatter_fields() {
  local f="$1"
  for key in "${REQUIRED[@]}"; do
    printf '%s\n' "$fm" | grep -qE "^${key}:" || {
      echo "✘ $f: 필수 frontmatter 필드 누락 '$key'"
      fail=$((fail + 1))
    }
  done
}

lint_follows_brain_paths() {
  local f="$1"
  while IFS= read -r sp; do
    [ -n "$sp" ] || continue
    [ -f "$sp" ] || {
      echo "✘ $f: follows-brain 경로 없음 → $sp"
      fail=$((fail + 1))
    }
  done < <(printf '%s\n' "$fm" | awk '
    /^follows-brain:/ {g=1; next}
    g && /^[[:space:]]*-[[:space:]]/ {gsub(/^[[:space:]]*-[[:space:]]*/,""); print; next}
    g && /^[^[:space:]-]/ {g=0}
  ')
}

lint_dangling_references() {
  local f="$1"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in
      @brain/*) tgt="${ref#@}" ;;
      @docs/*) tgt="${ref#@}" ;;
      *) continue ;;
    esac
    [ -f "$tgt" ] || {
      echo "⚠ $f: dangling 참조 $ref (→ $tgt 없음)"
      warn=$((warn + 1))
    }
  done < <(grep -oE '@(brain|docs)/[A-Za-z0-9/._-]+\.md' "$f" 2>/dev/null | sort -u)
}

lint_all_skills() {
  for f in skills/*/*.md; do
    [ -f "$f" ] || continue

    if ! lint_frontmatter_presence "$f"; then
      continue
    fi

    lint_frontmatter_fields "$f"
    lint_follows_brain_paths "$f"
    lint_dangling_references "$f"
  done
}

print_summary() {
  echo ""
  echo "lint-skills: 실패 $fail · 경고 $warn"
  if [ "$fail" -eq 0 ]; then
    exit 0
  else
    echo "린트 실패 — 위 ✘ 항목을 수정하세요."
    exit 1
  fi
}

main() {
  init_globals
  lint_all_skills
  print_summary
}

main "$@"
