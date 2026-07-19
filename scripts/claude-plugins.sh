#!/usr/bin/env bash
# scripts/claude-plugins.sh
#
# Claude Code 플러그인 설치 단계.
# settings.json 의 extraKnownMarketplaces + enabledPlugins 에 선언된
# GitHub 마켓플레이스 플러그인을 다운로드·설치합니다.
#
# 사용법:
#   scripts/claude-plugins.sh [--force]
#   --force   이미 설치된 버전도 최신으로 재설치

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/tui.sh"

OPT_FORCE=0
OPT_ALLOW_UNPINNED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force) OPT_FORCE=1; shift ;;
    --allow-unpinned) OPT_ALLOW_UNPINNED=1; shift ;;
    --help)
      echo "Usage: claude-plugins.sh [--force] [--allow-unpinned]"
      echo "  settings.json 의 enabledPlugins 에 선언된 GitHub 마켓플레이스 플러그인을 설치합니다."
      echo "  --force            이미 설치된 버전도 최신으로 재설치"
      echo "  --allow-unpinned   태그/SHA 미고정 플러그인 설치 허용(기본은 fail-closed 차단)"
      exit 0 ;;
    *)       shift ;;
  esac
done

require_cmd curl jq tar

CLAUDE_DIR="$(claude_home)"
REGISTRY="$CLAUDE_DIR/plugins/installed_plugins.json"

if [ ! -f "$REGISTRY" ]; then
  mkdir -p "$(dirname "$REGISTRY")"
  echo '{"version": 2, "plugins": {}}' > "$REGISTRY"
fi

# ─────────────────────────────────────────────
# install_github_plugin <plugin_key> <marketplace_id> <plugin_name> <github_repo>
#
#   plugin_key      registered_plugins.json 키   예) claude-hud@claude-hud
#   marketplace_id  캐시 경로 상위 디렉터리      예) claude-hud
#   plugin_name     캐시 경로 하위 디렉터리      예) claude-hud
#   github_repo     owner/repo                    예) jarrodwatts/claude-hud
# ─────────────────────────────────────────────
install_github_plugin() {
  local plugin_key="$1" marketplace_id="$2" plugin_name="$3" github_repo="$4"
  local pinned_ref="${5:-}" expected_sha="${6:-}"
  local cache_dir="$CLAUDE_DIR/plugins/cache/$marketplace_id/$plugin_name"

  # 이미 설치된 경우 건너뜀
  if [ "$OPT_FORCE" = "0" ] \
     && jq -e --arg k "$plugin_key" '.plugins[$k]' "$REGISTRY" > /dev/null 2>&1; then
    local cur_ver
    cur_ver=$(jq -r --arg k "$plugin_key" '.plugins[$k][0].version' "$REGISTRY")
    log_dim "  = $plugin_key v${cur_ver} (이미 설치됨)"
    return 0
  fi

  # ── 릴리스 태그 결정 (핀 우선, 미고정 시 경고) ──
  local tag version
  if [ -n "$pinned_ref" ]; then
    tag="$pinned_ref"
    log_info "  · $plugin_key 고정 태그 ${tag}"
  else
    # 안전 기본값(fail-closed): 미고정 플러그인은 기본 차단. 명시 옵트인 시에만 진행.
    if [ "$OPT_ALLOW_UNPINNED" != "1" ]; then
      log_warn "  ✗ $plugin_key 버전 미고정 — 공급망 안전을 위해 차단. 태그+SHA 고정 또는 --allow-unpinned 로 허용."
      return 1
    fi
    log_warn "  ! $plugin_key 버전 미고정(latest, --allow-unpinned) — 공급망 리스크."
    local release
    release=$(curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$github_repo/releases/latest") || {
      log_warn "  ! GitHub API 접근 실패 — 네트워크 연결을 확인하세요"
      return 1
    }
    tag=$(echo "$release" | jq -r '.tag_name')
  fi
  version="${tag#v}"          # v0.0.12 → 0.0.12

  local install_dir="$cache_dir/$version"

  # ── 커밋 SHA 취득 (다운로드 前) ────────────
  # lightweight tag: refs API → .object.sha 가 바로 커밋 SHA
  # annotated  tag: refs API → .object.sha 가 tag-object SHA → 한 번 더 조회
  local commit_sha=""
  local ref_obj
  ref_obj=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$github_repo/git/ref/tags/${tag}" 2>/dev/null) || true

  if [ -n "$ref_obj" ]; then
    local obj_type obj_sha
    obj_type=$(echo "$ref_obj" | jq -r '.object.type // ""')
    obj_sha=$(echo  "$ref_obj" | jq -r '.object.sha  // ""')

    if [ "$obj_type" = "tag" ]; then
      commit_sha=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$github_repo/git/tags/${obj_sha}" 2>/dev/null \
        | jq -r '.object.sha // ""') || true
    else
      commit_sha="$obj_sha"
    fi
  fi

  # ── 무결성 검증 (다운로드·전개 前에 차단) ────
  if [ -n "$expected_sha" ]; then
    if [ "$commit_sha" = "$expected_sha" ]; then
      log_ok "  ✓ SHA 검증 통과 (${commit_sha:0:12})"
    else
      log_warn "  ✗ SHA 불일치! expected=${expected_sha:0:12} got=${commit_sha:0:12} — 다운로드 중단(변조 의심)"
      return 1
    fi
  else
    log_warn "  ! $plugin_key SHA 미검증 — 공급망: install_github_plugin 6번째 인자로 기대 SHA 고정 권장"
  fi

  # ── 다운로드·전개 (검증 통과 後, 캐시 없을 때만) ──
  if [ "$OPT_FORCE" = "1" ]; then
    rm -rf "$install_dir"
  fi

  if [ ! -d "$install_dir" ] || [ -z "$(ls -A "$install_dir" 2>/dev/null)" ]; then
    mkdir -p "$install_dir"
    # 검증된 commit_sha 로 다운로드해 무결성 검증을 실제 바이트에 바인딩(TOCTOU 차단).
    # commit_sha 미해석(API 실패) 시에만 mutable tag 폴백.
    local dl_ref="${commit_sha:-$tag}"
    log_info "  · $github_repo@${dl_ref} 다운로드 중..."

    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/claude-plugin-XXXXXX")
    curl -fsSL "https://api.github.com/repos/$github_repo/tarball/${dl_ref}" -o "$tmp" || {
      rm -f "$tmp"; rmdir "$install_dir" 2>/dev/null || true
      log_warn "  ! 다운로드 실패"
      return 1
    }
    tar -xzf "$tmp" -C "$install_dir" --strip-components=1
    rm -f "$tmp"
  fi

  # ── 레지스트리 업데이트 ────────────────────
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  local entry
  entry=$(jq -n \
    --arg scope       "user" \
    --arg installPath "$install_dir" \
    --arg version     "$version" \
    --arg installedAt "$now" \
    --arg lastUpdated "$now" \
    --arg sha         "$commit_sha" \
    'if $sha != "" then
       {scope:$scope, installPath:$installPath, version:$version,
        installedAt:$installedAt, lastUpdated:$lastUpdated, gitCommitSha:$sha}
     else
       {scope:$scope, installPath:$installPath, version:$version,
        installedAt:$installedAt, lastUpdated:$lastUpdated}
     end')

  jq --arg k "$plugin_key" --argjson e "$entry" \
    '.plugins[$k] = [$e]' "$REGISTRY" > "${REGISTRY}.tmp" \
    && mv "${REGISTRY}.tmp" "$REGISTRY"

  log_ok "  + $plugin_key v${version} 설치 완료"
}

# ─────────────────────────────────────────────
# 설치할 플러그인 목록
# ─────────────────────────────────────────────
log_step "Phase 7.5 · Claude Code 플러그인 설치"

install_github_plugin \
  "claude-hud@claude-hud" \
  "claude-hud" \
  "claude-hud" \
  "jarrodwatts/claude-hud" \
  "v0.3.0" \
  "b83b44593af24de1db6183788a51d08715501c02"
