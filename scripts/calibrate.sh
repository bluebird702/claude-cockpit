#!/usr/bin/env bash
# scripts/calibrate.sh
# 
# 프로젝트 환경을 자동 인식하여 scale.tier를 동적 주입하고(Feature 1.2),
# MCP 도구를 자동 발견하며(Feature 1.3),
# 핵심 컨텍스트를 증류하여 압축합니다(Feature 1.4).
#
# 사용법:
#   scripts/calibrate.sh <project_root>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COCKPIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$COCKPIT_ROOT/scripts/lib/common.sh"
source "$COCKPIT_ROOT/scripts/lib/tui.sh"

PROJECT_ROOT="${1:-$PWD}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

tui_banner "Claude Cockpit · Zero-Config Calibration" "Project: $PROJECT_ROOT"
mkdir -p "$CLAUDE_DIR/rules"

# ==========================================
# Feature 1.2: Zero-Shot Auto-Calibration
# ==========================================
log_step "Auto-Calibration (scale.tier 감지)"

# 간단한 휴리스틱으로 프로젝트 규모 판단
LOC=$(find "$PROJECT_ROOT" -type f -not -path '*/\.*' -not -path '*/node_modules/*' -not -path '*/venv/*' 2>/dev/null | xargs wc -l 2>/dev/null | tail -n 1 | awk '{print $1}')
LOC=${LOC:-0}

HAS_K8S=0
if find "$PROJECT_ROOT" -type f \( -name "deployment.yaml" -o -name "kustomization.yaml" -o -name "Chart.yaml" \) | grep -q .; then
  HAS_K8S=1
fi

TIER="prototype"
if [ "$HAS_K8S" -eq 1 ] || [ "$LOC" -gt 50000 ]; then
  TIER="hyperscale"
elif [ "$LOC" -gt 5000 ]; then
  TIER="production"
fi

log_info "  LOC 감지: ~$LOC lines"
log_info "  K8s 매니페스트 감지: $HAS_K8S"
log_ok "  결정된 scale.tier: $TIER"

# .claude/rules/scale.md 에 주입
cat <<EOF > "$CLAUDE_DIR/rules/scale.md"
---
paths: ["**/*"]
---
@brain/engineering/reliability.md

## Project Auto-Calibrated Delta
- scale.tier: $TIER
EOF
log_info "  $CLAUDE_DIR/rules/scale.md 생성 완료"

# ==========================================
# Feature 1.3: MCP Auto-Discovery
# ==========================================
log_step "MCP Auto-Discovery"

SERVERS_JSON="$COCKPIT_ROOT/system/mcp-shared/servers.json"
FOUND_TOOLS=()

if [ -d "$PROJECT_ROOT/.git" ]; then
  log_ok "  Git 저장소 감지됨 → github MCP 추천"
  FOUND_TOOLS+=("github")
fi

if [ -f "$PROJECT_ROOT/package.json" ]; then
  log_ok "  package.json 감지됨 → playwright/linter MCP 추천"
  FOUND_TOOLS+=("playwright")
fi

if [ -f "$PROJECT_ROOT/JIRA.md" ] || grep -qi "jira" "$PROJECT_ROOT/README.md" 2>/dev/null || true; then
  # JIRA는 식별이 어렵지만, 힌트가 있다면
  :
fi

# 나중에 이 정보를 바탕으로 mcp/setup.sh 가 선택적으로 서버를 활성화할 수 있도록 힌트 파일 생성
echo "${FOUND_TOOLS[@]:-}" > "$CLAUDE_DIR/mcp_hints.txt"

# ==========================================
# Feature 1.4: Context Distillation
# ==========================================
log_step "Context Distillation (핵심 룰 압축)"

PAYLOAD="$CLAUDE_DIR/context_payload.md"

cat <<EOF > "$PAYLOAD"
# 🧠 Claude Cockpit - Distilled Context Payload

이 문서는 프로젝트의 수많은 기준(Brain) 중 핵심을 압축한 것입니다. 항상 이 규칙을 우선시하세요.

## 1. Security (Fail-Closed)
- 어떠한 상황에서도 Secrets, API Keys, Passwords를 출력하거나 커밋하지 마십시오.
- 쉘 스크립트 작성 시 항상 \`set -euo pipefail\`을 사용하여 멱등성을 보장하십시오.

## 2. Code Quality & Testing
- 함수(Function)는 단일 책임(SRP)을 가지며, 순수 함수(Pure function)를 지향합니다.
- 복잡도(CC)가 높은 코드를 피하고, Early Return을 적극 사용하십시오.
- 모든 기능 추가/수정 시, 이를 증명할 수 있는 단위 테스트를 포함해야 합니다.

## 3. Scale Tier: $TIER
- 현재 프로젝트는 $TIER 수준의 엄격도를 요구합니다.
EOF

if [ "$TIER" = "hyperscale" ]; then
  cat <<EOF >> "$PAYLOAD"
- [Hyperscale] 모든 외부 호출에는 Timeouts, Retries (with Backoff), Circuit Breakers가 필수입니다.
- [Hyperscale] 단일 장애점(SPOF)을 제거하고, 상태(State)는 무상태(Stateless)로 관리하십시오.
EOF
fi

log_ok "  $PAYLOAD 생성 완료"
printf '\n'
log_ok "Calibration 완료! (Zero-Config Intelligence 탑재 성공)"
