#!/usr/bin/env bash
# pin-images.sh — MCP 서버 Docker 이미지를 digest(@sha256)로 고정한다.
#
# 롤링 태그(node:20-alpine 등)는 시간이 지나면 다른 바이트를 가리켜 공급망 리스크가
# 된다. 이 스크립트는 온라인에서 각 이미지 태그를 **불변 digest** 로 해석해
# core/mcp-shared/servers.json 에 `img:tag@sha256:...` 형태로 고정한다.
#
# 요구: docker(buildx) 또는 crane 또는 skopeo. 오프라인이면 아무 것도 바꾸지 않는다.
# 사용:
#   scripts/pin-images.sh            # servers.json 을 in-place 로 digest 핀
#   scripts/pin-images.sh --check    # 핀이 필요한 이미지만 출력(변경 없음)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/core/mcp-shared/servers.json"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

command -v jq >/dev/null 2>&1 || { echo "jq 필요"; exit 1; }
[ -f "$FILE" ] || { echo "없음: $FILE"; exit 1; }

# 이미지 ref 추출: 태그(:) 는 있고 digest(@) 는 없는 args 문자열.
# (bash 3.2 호환 — mapfile 미사용)
IMAGES=()
while IFS= read -r _img; do
  [ -n "$_img" ] && IMAGES+=("$_img")
done < <(jq -r '
  [.servers[].args[]?]
  | map(select(type=="string"
        and test("^[a-z0-9.]+([/][a-z0-9._-]+)*:[a-zA-Z0-9._-]+$")
        and (contains("@sha256:") | not)))
  | unique[]' "$FILE")

if [ "${#IMAGES[@]}" -eq 0 ]; then
  echo "핀이 필요한 이미지 없음 (모두 digest 고정됨)."
  exit 0
fi

resolve_digest() { # $1=image → sha256:... (stdout) / 실패 시 빈 문자열
  local img="$1" d=""
  if command -v docker >/dev/null 2>&1; then
    d="$(docker buildx imagetools inspect "$img" 2>/dev/null | awk '/[Dd]igest:/{print $2; exit}')" || true
  fi
  if [ -z "$d" ] && command -v crane >/dev/null 2>&1; then
    d="$(crane digest "$img" 2>/dev/null)" || true
  fi
  if [ -z "$d" ] && command -v skopeo >/dev/null 2>&1; then
    d="$(skopeo inspect "docker://$img" 2>/dev/null | jq -r '.Digest // empty')" || true
  fi
  printf '%s' "$d"
}

changed=0
for img in "${IMAGES[@]}"; do
  if [ "$CHECK_ONLY" = "1" ]; then
    echo "핀 필요: $img"
    continue
  fi
  digest="$(resolve_digest "$img")"
  if [ -z "$digest" ]; then
    echo "⚠ $img digest 해석 실패 (docker/crane/skopeo 필요·온라인 필요) — 건너뜀" >&2
    continue
  fi
  # servers.json 의 정확한 따옴표 문자열을 교체 (모든 등장 위치)
  tmp="$(mktemp "${TMPDIR:-/tmp}/servers-XXXXXX")"
  jq --arg img "$img" --arg new "${img}@${digest}" '
    .servers |= map_values(
      .args |= if type == "array" then map(if type == "string" and . == $img then $new else . end) else . end
    )
  ' "$FILE" > "$tmp"
  if jq -e . "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$FILE"
    echo "✓ 핀: $img → @${digest:0:19}…"
    changed=$((changed + 1))
  else
    rm -f "$tmp"
    echo "⚠ $img 치환 후 JSON 파손 — 롤백" >&2
  fi
done

[ "$CHECK_ONLY" = "1" ] && exit 0
echo ""
echo "완료: ${changed}개 이미지 digest 고정. 변경을 검토 후 커밋하세요."
