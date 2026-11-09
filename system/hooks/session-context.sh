#!/usr/bin/env bash
# session-context.sh - SessionStart 훅
#
# 세션 시작 시 현재 작업 디렉토리의 git 상태·브랜치·최근 커밋을 Claude 에게 주입합니다.
# stdout 출력이 그대로 additionalContext 로 세션에 합류합니다.
#
# 목표: "이 세션이 어떤 레포·브랜치·상태에서 시작됐는지" 한 화면으로.

set -euo pipefail
cwd="$(pwd)"
COCKPIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 이 장비의 환경 (configure.sh 가 설치 시 감지한 값) — 특정 PC 를 전제하지 않도록 Claude 에게 알림
# 파일을 source 하지 않고 값만 읽는다 (훅에서 임의 코드 실행 방지, docker 호출 없이 저비용)
env_line=""
ENV_FILE="$COCKPIT_ROOT/.cockpit-local/.cockpit-env"
if [ -f "$ENV_FILE" ]; then
	_env_get() { sed -n "s/^export $1=\"\\(.*\\)\"$/\\1/p" "$ENV_FILE" | tail -n 1; }
	env_line="- **장비 환경**: OS \`$(_env_get OS_TYPE)\` $(_env_get ARCH_TYPE) · 패키지 매니저 \`$(_env_get PKG_MANAGER)\` · Docker 런타임 \`$(_env_get DOCKER_RUNTIME)\` · 셸 \`$(_env_get USER_SHELL)\`"
fi

# git 레포가 아니면 장비 환경만 알리고 통과
if ! git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	[ -n "$env_line" ] && printf '## 🛰  세션 컨텍스트 (cockpit)\n\n%s\n' "$env_line"
	exit 0
fi

branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
upstream="$(git -C "$cwd" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
ahead_behind="$(git -C "$cwd" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo '0 0')"
behind="$(echo "$ahead_behind" | awk '{print $1}')"
ahead="$(echo "$ahead_behind" | awk '{print $2}')"

dirty_count="$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
staged_count="$(git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"

cat <<EOF
## 🛰  세션 컨텍스트 (cockpit)

- **CWD**: \`$cwd\`
- **브랜치**: \`$branch\`${upstream:+ → \`$upstream\`}${ahead:+ (ahead $ahead, behind $behind)}
- **변경 파일**: ${dirty_count}개 (staged ${staged_count})
${env_line}

### 최근 커밋 5건
\`\`\`
$(git -C "$cwd" log --oneline -5 2>/dev/null || echo '(없음)')
\`\`\`
EOF

# 변경 파일이 있으면 간단히 나열 (최대 15줄)
if [ "$dirty_count" -gt 0 ]; then
	echo
	echo "### 변경된 파일"
	echo '```'
	git -C "$cwd" status --short 2>/dev/null | head -15
	echo '```'
fi

# 레포별 CLAUDE.md 가 있으면 존재만 알림 (로딩은 Claude Code 본체가 담당)
if [ -f "$cwd/.claude/CLAUDE.md" ] || [ -f "$cwd/CLAUDE.md" ]; then
	echo
	echo "_프로젝트 CLAUDE.md 가 로드되어 있습니다._"
fi

# cockpit 템플릿이 렌더본보다 최신이면 업데이트 넛지 (훅 위치 기준으로 레포 탐색, mtime 비교만 — 저비용)
if [ -f "$COCKPIT_ROOT/system/settings.json.template" ] &&
	[ "$COCKPIT_ROOT/system/settings.json.template" -nt "$COCKPIT_ROOT/.cockpit-local/settings.json" ]; then
	echo
	echo "⚠️ _cockpit 설정 템플릿이 렌더본보다 최신입니다 — \`$COCKPIT_ROOT/scripts/update.sh\` 실행을 권장합니다._"
fi

exit 0
